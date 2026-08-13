import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';

import '../game/turn_coordinator.dart';
import 'online_backend.dart';
import 'protocol.dart';

/// Партия в комнате: согласование костей, публикация ходов и проверка чужих
/// через `narda_core` (§6).
///
/// Источник истины — журнал `games/{gameIndex}/moves`: позиция всегда
/// восстановима его реплеем, на этом держатся и реконнект, и разбор
/// расхождений. Всё, что не про правила (таймер хода, presence, фразы),
/// живёт здесь же и слушается экраном как [ChangeNotifier].
class OnlineMatch extends ChangeNotifier implements TurnCoordinator {
  OnlineMatch({
    required this.room,
    required this.localColor,
    Duration serverOffset = Duration.zero,
    DiceSource? dice,
    this.turnLimit = const Duration(seconds: 60),
    this.absenceLimit = const Duration(seconds: 60),
    this.phraseLifetime = const Duration(seconds: 6),
    this.tickInterval = const Duration(seconds: 1),
    DateTime Function() clock = DateTime.now,
  }) : _serverOffset = serverOffset,
       _dice = dice ?? RandomDiceSource(),
       _clock = clock;

  static const MoveGenerator _generator = MoveGenerator();

  /// Сколько раз перебрасываем при равных кубиках розыгрыша, прежде чем
  /// признать комнату сломанной.
  static const int _maxOpeningAttempts = 24;

  final RoomHandle room;

  /// Цвет локального игрока — его назначает комната.
  final Player localColor;

  /// Таймер хода (§6).
  final Duration turnLimit;

  /// Сколько соперник должен отсутствовать, чтобы можно было забрать победу.
  final Duration absenceLimit;

  /// Сколько держится на экране фраза соперника.
  final Duration phraseLifetime;

  /// Как часто пересчитываются таймеры — он же шаг обратного отсчёта.
  final Duration tickInterval;

  /// Кости активного игрока — точка замены на серверные (§6).
  final DiceSource _dice;

  final Duration _serverOffset;
  final DateTime Function() _clock;

  final StreamController<MatchSignal> _signals =
      StreamController<MatchSignal>.broadcast();
  final List<_SnapshotWaiter> _waiters = <_SnapshotWaiter>[];

  StreamSubscription<RoomSnapshot>? _room;
  Timer? _ticker;

  RoomSnapshot? _snapshot;
  Player? _first;
  int _gameIndex = 0;
  int _moveIndex = 0;
  bool _started = false;
  bool _closed = false;

  /// Позиция на начало текущего локального хода — из неё делается автопас.
  GameState? _turnState;

  /// Позиция после последнего разобранного хода: по ней считается марс,
  /// когда партия заканчивается сдачей или тайм-аутом.
  GameState? _position;

  int _deadline = 0;
  int? _absentSince;
  int _localExpired = 0;
  int _opponentExpired = 0;
  int _finishedGame = -1;
  String? _phrase;
  int _phraseAt = 0;

  @override
  Stream<MatchSignal> get signals => _signals.stream;

  String get localUid => room.uid;

  String? get opponentUid => _snapshot?.opponentOf(localUid)?.uid;

  String get opponentName => _snapshot?.opponentOf(localUid)?.name ?? '';

  /// Код приватной комнаты — его диктуют сопернику.
  String get roomCode => _snapshot?.meta?.code ?? '';

  /// Соперник на связи. Пока комната не заполнилась — считаем, что да.
  bool get opponentOnline {
    final String? uid = opponentUid;
    if (uid == null) return true;
    return _snapshot?.presence[uid] ?? false;
  }

  /// Сколько осталось на ход; `null` — дедлайн не выставлен.
  Duration? get turnRemaining {
    if (_deadline == 0) return null;
    final int left = _deadline - _serverNow();
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  /// Соперника нет дольше [absenceLimit] — можно забрать победу (§6).
  bool get canClaimWin {
    final int? since = _absentSince;
    if (since == null || _closed || opponentUid == null) return false;
    return _serverNow() - since >= absenceLimit.inMilliseconds;
  }

  /// Последняя фраза соперника, пока она не «протухла».
  String? get opponentPhrase => _phrase;

  /// Подписывается на комнату и запускает секундный тик таймеров.
  void start() {
    if (_started) return;
    _started = true;
    _apply(room.snapshot);
    _room = room.snapshots.listen(
      _apply,
      onError: (Object _) => _emit(const AbortSignal(MatchAbortReason.connection)),
    );
    unawaited(room.keepPresence());
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  // --- TurnCoordinator -------------------------------------------------

  @override
  Future<GameState> opening() async {
    await _awaitSnapshot<bool>((RoomSnapshot snapshot) =>
        snapshot.isFull ? true : null);

    _gameIndex = _nextGameIndex();
    _finishedGame = -1;
    _localExpired = 0;
    _opponentExpired = 0;
    _first = await _resolveFirstMover(_gameIndex);

    final ReplayResult replay = _replay(_snapshot!, _first!, _gameIndex);
    if (!replay.isLegal) {
      _emit(const AbortSignal(MatchAbortReason.desync));
      return Completer<GameState>().future;
    }
    _moveIndex = _snapshot!.game(_gameIndex).orderedMoves().length;
    _position = replay.state;
    return replay.state;
  }

  @override
  Future<DiceRoll> roll(GameState state) async {
    final int index = _moveIndex;
    final int game = _gameIndex;

    if (state.turn != localColor) {
      _turnState = null;
      return _awaitSnapshot<DiceRoll>((RoomSnapshot snapshot) {
        final RoomState? node = snapshot.state;
        if (node == null || node.gameIndex != game) return null;
        return node.moveIndex == index ? node.dice : null;
      });
    }

    // Реконнект в середине своего хода: бросок уже опубликован — он и в силе.
    final RoomState? published = _snapshot?.state;
    final DiceRoll roll =
        published != null &&
            published.gameIndex == game &&
            published.moveIndex == index &&
            published.dice != null
        ? published.dice!
        : _dice.roll();

    final GameState turnState = state.copyWith(
      roll: roll,
      remainingDice: roll.toRemaining(),
      headMovesUsed: 0,
    );
    _turnState = turnState;
    _deadline = _serverNow() + turnLimit.inMilliseconds;
    await room.update(<String, Object?>{
      'state': RoomState(
        points: turnState.encode(),
        turnUid: localUid,
        dice: roll,
        moveIndex: index,
        gameIndex: game,
        deadline: _deadline,
      ).toJson(),
    });
    return roll;
  }

  @override
  Future<void> publish(GameState before, MoveSequence sequence) async {
    final int index = _moveIndex;
    final int game = _gameIndex;
    final GameState after = before.applySequence(sequence);
    final GameState next = after.isFinished ? after : after.nextTurn(before.roll);

    _moveIndex = index + 1;
    _turnState = null;
    _deadline = 0;
    _position = next;
    _localExpired = sequence.isEmpty && _generator.hasAnyMove(before)
        ? _localExpired + 1
        : 0;

    await room.update(<String, Object?>{
      'games/$game/moves/$index': RoomMove(
        uid: localUid,
        dice: before.roll,
        seq: encodeMoves(sequence),
      ).toJson(),
      'state': RoomState(
        points: next.encode(),
        turnUid: after.isFinished ? localUid : (opponentUid ?? localUid),
        moveIndex: index + 1,
        gameIndex: game,
        deadline: 0,
      ).toJson(),
    });

    if (_localExpired >= 2) {
      // Два просроченных хода подряд — поражение (§6).
      await _writeOutcome(
        winnerUid: opponentUid ?? localUid,
        reason: OutcomeReason.timeout,
      );
    }
  }

  @override
  Future<void> publishResign() => _writeOutcome(
    winnerUid: opponentUid ?? localUid,
    reason: OutcomeReason.resign,
  );

  /// Ход соперника из журнала. `null` — он пропустил ход.
  ///
  /// Каждый ход проходит через генератор ядра, а позиция после него — через
  /// сверку слепков (§6). Не сошлось — пересборка реплеем или аннулирование.
  Future<MoveSequence?> awaitOpponentMove(GameState state) async {
    final int index = _moveIndex;
    final int game = _gameIndex;
    final RoomMove move = await _awaitSnapshot<RoomMove>(
      (RoomSnapshot snapshot) => snapshot.game(game).moves[index],
    );

    final MoveSequence sequence;
    try {
      sequence = decodeMoves(state.turn, move.seq);
    } on FormatException {
      return _recover<MoveSequence?>();
    }

    if (sequence.isNotEmpty && !_generator.generate(state).contains(sequence)) {
      return _recover<MoveSequence?>();
    }

    final GameState after = state.applySequence(sequence);
    final GameState next = after.isFinished ? after : after.nextTurn(state.roll);
    if (!_digestMatches(game, index + 1, next)) {
      return _recover<MoveSequence?>();
    }

    _opponentExpired = sequence.isEmpty && _generator.hasAnyMove(state)
        ? _opponentExpired + 1
        : 0;
    _moveIndex = index + 1;
    _position = next;
    _deadline = 0;

    if (_opponentExpired >= 2) {
      unawaited(
        _writeOutcome(winnerUid: localUid, reason: OutcomeReason.timeout),
      );
    }
    return sequence.isEmpty ? null : sequence;
  }

  /// Забрать победу, когда соперника нет дольше [absenceLimit] (§6).
  Future<void> claimWin() =>
      _writeOutcome(winnerUid: localUid, reason: OutcomeReason.disconnect);

  /// Отправить одну из готовых фраз или эмодзи (§6: свободного чата нет).
  Future<void> sendPhrase(String phrase) => room.update(<String, Object?>{
    'chat/$localUid': <String, Object?>{
      'phrase': phrase,
      'ts': serverTimestamp,
    },
  });

  @override
  void dispose() {
    _closed = true;
    _ticker?.cancel();
    unawaited(_room?.cancel());
    unawaited(room.leave());
    unawaited(_signals.close());
    _waiters.clear();
    super.dispose();
  }

  // --- Внутреннее ------------------------------------------------------

  void _apply(RoomSnapshot snapshot) {
    if (_closed) return;
    _snapshot = snapshot;

    final String? uid = opponentUid;
    if (uid != null) {
      final bool online = snapshot.presence[uid] ?? false;
      _absentSince = online ? null : (_absentSince ?? _serverNow());
      final String? phrase = snapshot.chat[uid];
      if (phrase != null && phrase != _phrase) {
        _phrase = phrase;
        _phraseAt = _serverNow();
      }
    }

    final RoomState? node = snapshot.state;
    if (node != null && node.gameIndex == _gameIndex) {
      _deadline = node.deadline;
    }

    for (final _SnapshotWaiter waiter in _waiters.toList()) {
      final Object? value = waiter.probe(snapshot);
      if (value == null) continue;
      _waiters.remove(waiter);
      waiter.completer.complete(value);
    }

    _checkOutcome(snapshot);
    notifyListeners();
  }

  /// Внешний итог партии: сдача, тайм-аут, забранная победа.
  void _checkOutcome(RoomSnapshot snapshot) {
    final RoomOutcome? outcome = snapshot.outcome;
    if (outcome == null || outcome.gameIndex != _gameIndex) return;
    if (_finishedGame == _gameIndex) return;
    _finishedGame = _gameIndex;

    final Player winner = outcome.winnerUid == localUid
        ? localColor
        : localColor.opponent;
    final GameState position = _position ?? _turnState ?? _initialPosition();
    _emit(
      FinishSignal(
        GameResult.resignation(resigning: winner.opponent, state: position),
      ),
    );
  }

  void _tick() {
    if (_closed || _snapshot == null) return;
    if (_phrase != null &&
        _serverNow() - _phraseAt > phraseLifetime.inMilliseconds) {
      _phrase = null;
    }
    final GameState? turnState = _turnState;
    if (turnState != null && _deadline != 0 && _serverNow() > _deadline) {
      unawaited(_passOnTimeout(turnState));
    }
    notifyListeners();
  }

  /// Просроченный ход — автопас (§6). Доска перезапускается с новой позиции.
  Future<void> _passOnTimeout(GameState before) async {
    _turnState = null;
    _deadline = 0;
    await publish(before, MoveSequence.empty);
    if (_closed) return;
    _emit(ResyncSignal(before.nextTurn(before.roll)));
  }

  /// Пересборка позиции реплеем журнала с нуля (§6).
  ///
  /// Возвращённый `Future` намеренно никогда не завершается: партию уже
  /// перезапускает сигнал, и старый ход доски досчитывать незачем.
  Future<T> _recover<T>() {
    final RoomSnapshot? snapshot = _snapshot;
    final Player? first = _first;
    if (snapshot == null || first == null) {
      _emit(const AbortSignal(MatchAbortReason.desync));
      return Completer<T>().future;
    }
    final ReplayResult replay = _replay(snapshot, first, _gameIndex);
    if (!replay.isLegal) {
      _emit(const AbortSignal(MatchAbortReason.desync));
      return Completer<T>().future;
    }
    _moveIndex = snapshot.game(_gameIndex).orderedMoves().length;
    _position = replay.state;
    _deadline = 0;
    _turnState = null;
    _emit(ResyncSignal(replay.state));
    return Completer<T>().future;
  }

  bool _digestMatches(int game, int moveIndex, GameState expected) {
    final RoomState? node = _snapshot?.state;
    if (node == null || node.gameIndex != game || node.moveIndex != moveIndex) {
      // Слепок ещё не доехал — сверять нечего, ход уже проверен правилами.
      return true;
    }
    final GameState? published = tryDecodeState(node.points);
    if (published == null) return false;
    return positionDigest(published) == positionDigest(expected);
  }

  ReplayResult _replay(RoomSnapshot snapshot, Player first, int game) =>
      replayGame(
        GameLog(
          first: first,
          turns: <LoggedTurn>[
            for (final RoomMove move in snapshot.game(game).orderedMoves())
              move.toLoggedTurn(),
          ],
        ),
      );

  /// Номер очередной партии серии. На реконнекте пропускает те, что уже
  /// доиграны: их журнал заканчивается победой или записан итог.
  int _nextGameIndex() {
    int index = _first == null
        ? (_snapshot?.state?.gameIndex ?? 0)
        : _gameIndex + 1;
    for (int guard = 0; guard < 32 && _isGameOver(index); guard++) {
      index++;
    }
    return index;
  }

  bool _isGameOver(int index) {
    final RoomSnapshot? snapshot = _snapshot;
    if (snapshot == null) return false;
    if (snapshot.outcome?.gameIndex == index) return true;
    final String? firstUid = snapshot.game(index).firstMoverUid();
    if (firstUid == null) return false;
    final Player first = firstUid == localUid ? localColor : localColor.opponent;
    return _replay(snapshot, first, index).isFinished;
  }

  /// Розыгрыш первого хода: каждый пишет свой кубик сам, при равенстве —
  /// новая попытка (§3.2.1).
  Future<Player> _resolveFirstMover(int game) async {
    for (int attempt = 0; attempt < _maxOpeningAttempts; attempt++) {
      final Map<String, int> known =
          _snapshot?.game(game).opening[attempt] ?? const <String, int>{};
      if (!known.containsKey(localUid)) {
        await room.update(<String, Object?>{
          'games/$game/opening/$attempt/$localUid': _dice.rollOne(),
        });
      }
      final String uid = await _awaitSnapshot<String>((RoomSnapshot snapshot) {
        final String? other = snapshot.opponentOf(localUid)?.uid;
        final Map<String, int>? dice = snapshot.game(game).opening[attempt];
        if (other == null || dice == null) return null;
        final int? mine = dice[localUid];
        final int? theirs = dice[other];
        if (mine == null || theirs == null) return null;
        if (mine == theirs) return '';
        return mine > theirs ? localUid : other;
      });
      if (uid.isEmpty) continue;
      return uid == localUid ? localColor : localColor.opponent;
    }
    throw const OnlineUnavailable(OnlineFailure.network);
  }

  Future<void> _writeOutcome({
    required String winnerUid,
    required OutcomeReason reason,
  }) => room.update(<String, Object?>{
    'outcome': RoomOutcome(
      winnerUid: winnerUid,
      reason: reason,
      gameIndex: _gameIndex,
    ).toJson(),
    'meta/status': RoomStatus.playing.name,
  });

  GameState _initialPosition() =>
      GameState.initial(first: _first ?? localColor, roll: const DiceRoll(1, 1));

  void _emit(MatchSignal signal) {
    if (_closed || _signals.isClosed) return;
    _signals.add(signal);
  }

  int _serverNow() => _clock().millisecondsSinceEpoch + _serverOffset.inMilliseconds;

  /// Ждёт снимок, на котором [probe] вернёт значение.
  Future<T> _awaitSnapshot<T extends Object>(
    T? Function(RoomSnapshot snapshot) probe,
  ) {
    final RoomSnapshot? snapshot = _snapshot;
    if (snapshot != null) {
      final T? value = probe(snapshot);
      if (value != null) return Future<T>.value(value);
    }
    final Completer<Object> completer = Completer<Object>();
    _waiters.add(_SnapshotWaiter(probe, completer));
    return completer.future.then((Object value) => value as T);
  }
}

class _SnapshotWaiter {
  _SnapshotWaiter(this.probe, this.completer);

  final Object? Function(RoomSnapshot snapshot) probe;
  final Completer<Object> completer;
}

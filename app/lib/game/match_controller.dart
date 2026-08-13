import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';

import 'feedback.dart';
import 'game_setup.dart';
import 'opponent.dart';
import 'settings.dart';
import 'turn_coordinator.dart';
import 'turn_planner.dart';

/// Что происходит в партии прямо сейчас.
enum TurnPhase {
  /// Катятся кости нового хода.
  rolling,

  /// Ход собирает локальный игрок.
  choosing,

  /// Ход делает соперник, которого нет за этим устройством.
  thinking,

  /// Легальных перемещений нет — «yurish yo'q».
  noMoves,

  /// Партия закончена.
  finished,

  /// Партия аннулирована: общее состояние восстановить не удалось (§6).
  aborted,
}

/// Перемещение, которое доска должна проиграть анимацией.
/// [serial] растёт при каждом новом перемещении, в том числе повторном.
class AnimatedMove {
  const AnimatedMove({required this.move, required this.serial});

  final Move move;
  final int serial;
}

/// Длительности партии. В тестах берётся [MatchTiming.instant].
class MatchTiming {
  const MatchTiming({
    this.dice = const Duration(milliseconds: 650),
    this.move = const Duration(milliseconds: 260),
    this.betweenMoves = const Duration(milliseconds: 70),
    this.beforeCommit = const Duration(milliseconds: 320),
    this.noMoves = const Duration(milliseconds: 1400),
  });

  const MatchTiming.instant()
    : dice = Duration.zero,
      move = Duration.zero,
      betweenMoves = Duration.zero,
      beforeCommit = Duration.zero,
      noMoves = Duration.zero;

  final Duration dice;
  final Duration move;
  final Duration betweenMoves;
  final Duration beforeCommit;
  final Duration noMoves;
}

/// Ведение партии для экрана: очередь хода, сбор перемещений, анимации,
/// отмена и подтверждение. Правила целиком остаются в ядре.
///
/// Здесь же живёт счёт серии до 3 / 5 / 7 очков (§3.4): партии сменяют друг
/// друга через [nextGame], пока [isMatchOver] не станет истиной.
class MatchController extends ChangeNotifier {
  MatchController({
    required this.setup,
    required this.settings,
    DiceSource? dice,
    Opponent? opponent,
    MatchFeedback? feedback,
    TurnCoordinator? coordinator,
    this.onGameFinished,
    this.timing = const MatchTiming(),
  }) : _game = Game(dice: dice ?? RandomDiceSource()),
       _opponent = opponent ?? createOpponent(setup),
       _feedback = feedback ?? const SilentFeedback(),
       _coordinator = coordinator,
       _score = MatchScore(target: setup.target) {
    _signals = coordinator?.signals.listen(_handleSignal);
  }

  static const MoveGenerator _generator = MoveGenerator();

  final GameSetup setup;
  final SettingsController settings;
  final MatchTiming timing;

  /// Сообщает экрану о завершившейся партии: статистика и счётчик рекламы.
  final void Function(GameResult result)? onGameFinished;

  final Game _game;
  final Opponent _opponent;
  final MatchFeedback _feedback;

  /// Ведущий сетевой партии; `null` — оффлайн, кости берутся локально.
  final TurnCoordinator? _coordinator;

  StreamSubscription<MatchSignal>? _signals;

  MatchScore _score;

  TurnPhase _phase = TurnPhase.rolling;
  TurnPlanner? _planner;
  GameResult? _result;
  MatchAbortReason? _abortReason;
  AnimatedMove? _animated;
  List<Move> _lastTurnMoves = const <Move>[];
  int? _selected;
  int _animationSerial = 0;
  int _generation = 0;
  bool _disposed = false;

  /// Состояние доски: с учётом уже собранных, но ещё не подтверждённых
  /// перемещений.
  GameState get state => _planner?.current ?? _game.state;

  TurnPhase get phase => _phase;

  GameResult? get result => _result;

  /// Почему партия аннулирована; `null` — она шла или закончилась нормально.
  MatchAbortReason? get abortReason => _abortReason;

  /// Партия доиграна или аннулирована — доска больше не принимает ходы.
  bool get isOver =>
      _phase == TurnPhase.finished || _phase == TurnPhase.aborted;

  /// Счёт серии. Для одиночной партии цель — одно очко.
  MatchScore get score => _score;

  /// Серия доиграна: победитель набрал нужные очки.
  bool get isMatchOver => _score.isOver;

  AnimatedMove? get animated => _animated;

  /// Перемещения последнего завершённого хода — их доска подсвечивает.
  List<Move> get lastTurnMoves => _lastTurnMoves;

  /// Выбранный игроком пункт отправления.
  int? get selected => _selected;

  /// Чья половина показана снизу: в hotseat доска переворачивается.
  Player get perspective =>
      _opponent.movesOnThisDevice ? state.turn : setup.localPlayer;

  /// Ходит ли сейчас тот, кто вводит ход с этого экрана.
  bool get isLocalTurn =>
      _opponent.movesOnThisDevice || state.turn == setup.localPlayer;

  bool get canInteract => _phase == TurnPhase.choosing && _planner != null;

  bool get canConfirm => canInteract && _planner!.isComplete;

  bool get canUndo => canInteract && _planner!.canUndo;

  /// Пункты, с которых сейчас можно ходить.
  Iterable<int> get movableSources =>
      canInteract ? _planner!.sources : const <int>[];

  /// Куда может пойти выбранная шашка; `null` в списке — выброс.
  List<int?> get destinations {
    final int? from = _selected;
    if (from == null || !canInteract) return const <int?>[];
    return <int?>[for (final Move move in _planner!.movesFrom(from)) move.toAbs];
  }

  /// Сколько перемещений уже собрано и сколько нужно всего.
  int get movesPlayed => _planner?.played.length ?? 0;

  int get movesRequired => _planner?.maxMoves ?? 0;

  /// Начинает партию: розыгрыш первого хода и первый бросок (§3.2.1).
  /// В онлайне и то и другое согласуется с соперником.
  void start() {
    final TurnCoordinator? coordinator = _coordinator;
    if (coordinator == null) {
      _game.start();
      unawaited(_runTurn());
      return;
    }
    unawaited(_startShared(coordinator, _generation));
  }

  /// Следующая партия серии — счёт сохраняется.
  void nextGame() {
    _generation++;
    _phase = TurnPhase.rolling;
    _result = null;
    _abortReason = null;
    _planner = null;
    _selected = null;
    _animated = null;
    _lastTurnMoves = const <Move>[];
    start();
  }

  /// Новая серия с нуля: счёт обнуляется.
  void newMatch() {
    _score = MatchScore(target: setup.target);
    nextGame();
  }

  /// Тап по пункту: выбор шашки или перемещение выбранной шашки.
  void tapPoint(int abs) {
    if (!canInteract) return;
    final TurnPlanner planner = _planner!;
    final int? from = _selected;
    if (from != null && from != abs) {
      final Move? move = planner.moveTo(from, abs);
      if (move != null) {
        _selected = null;
        _play(move);
        return;
      }
    }
    final List<Move> moves = planner.movesFrom(abs);
    if (moves.isEmpty || from == abs) {
      _selected = null;
      _notify();
      return;
    }
    if (settings.autoMove && moves.length == 1) {
      _selected = null;
      _play(moves.single);
      return;
    }
    _selected = abs;
    _notify();
  }

  /// Тап по лотку выброса выбранной шашкой (chiqarish).
  void tapBearOff() {
    if (!canInteract) return;
    final int? from = _selected;
    if (from == null) return;
    final Move? move = _planner!.moveTo(from, null);
    if (move == null) return;
    _selected = null;
    _play(move);
  }

  /// Начало перетаскивания: подсвечивает назначения, но ничего не двигает.
  void beginDrag(int fromAbs) {
    if (!canInteract) return;
    if (_planner!.movesFrom(fromAbs).isEmpty) return;
    _selected = fromAbs;
    _notify();
  }

  /// Конец перетаскивания шашки: [toAbs] `null` — лоток выброса.
  /// Промах оставляет шашку выбранной, чтобы можно было доходить тапом.
  void drop({required int fromAbs, required int? toAbs}) {
    if (!canInteract) return;
    final Move? move = _planner!.moveTo(fromAbs, toAbs);
    if (move == null) {
      _notify();
      return;
    }
    _selected = null;
    _play(move);
  }

  /// Отмена последнего перемещения — до подтверждения хода.
  void undo() {
    if (!canUndo) return;
    _planner!.undo();
    _selected = null;
    _animated = null;
    _notify();
  }

  /// Подтверждение собранного хода.
  void confirm() {
    if (!canConfirm) return;
    unawaited(_commit(_generation));
  }

  /// Сдача партии (§3.4): сдаётся тот, чей сейчас ход.
  void resign() {
    if (isOver) return;
    _generation++;
    final Player resigning = _opponent.movesOnThisDevice
        ? _game.state.turn
        : setup.localPlayer;
    _planner = null;
    _selected = null;
    _animated = null;
    _game.resign(resigning);
    unawaited(_coordinator?.publishResign());
    _finish(_game.result!);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_signals?.cancel());
    _opponent.dispose();
    _feedback.dispose();
    super.dispose();
  }

  /// Старт сетевой партии: позиция приходит от ведущего — свежая раздача
  /// или восстановленная реплеем журнала после реконнекта (§6).
  Future<void> _startShared(TurnCoordinator coordinator, int generation) async {
    _phase = TurnPhase.rolling;
    // Пока ведущий согласовывает первый ход, доске нужна хоть какая-то
    // позиция: показываем стартовую расстановку. Ходить в ней нельзя —
    // фаза `rolling` не пускает, а через мгновение придёт настоящая.
    _game.restore(
      GameState.initial(first: setup.localPlayer, roll: const DiceRoll(1, 1)),
    );
    _notify();
    final GameState state;
    try {
      state = await coordinator.opening();
    } on Object {
      _abort(MatchAbortReason.connection);
      return;
    }
    if (_isStale(generation)) return;
    _game.restore(state);
    if (_game.isFinished) {
      _finish(_game.result!);
      return;
    }
    unawaited(_runTurn());
  }

  Future<void> _runTurn() async {
    // Партия могла закончиться внешним сигналом, пока предыдущий ход
    // досчитывал свои await'ы — новый ход тогда начинать нельзя.
    if (isOver) return;
    final int generation = _generation;
    _planner = null;
    _selected = null;
    _animated = null;
    _phase = TurnPhase.rolling;
    _feedback.dice();
    _notify();

    final TurnCoordinator? coordinator = _coordinator;
    if (coordinator != null && !await _syncRoll(coordinator, generation)) {
      return;
    }

    if (!await _wait(timing.dice, generation)) return;

    final List<MoveSequence> options = _generator.generate(_game.state);
    final bool local = isLocalTurn;

    // «Yurish yo'q». В онлайне пас соперника всё равно приходит по сети:
    // иначе разъедутся номера ходов в журнале комнаты.
    if (options.isEmpty && (local || coordinator == null)) {
      _phase = TurnPhase.noMoves;
      _notify();
      if (!await _wait(timing.noMoves, generation)) return;
      await _passTurn(generation, forced: false);
      return;
    }

    if (options.isNotEmpty) {
      _planner = TurnPlanner(base: _game.state, options: options);
    }

    if (local) {
      _phase = TurnPhase.choosing;
      _notify();
      if (settings.autoMove && options.length == 1) {
        if (!await _playSequence(options.first, generation)) return;
        await _commit(generation);
      }
      return;
    }

    _phase = options.isEmpty ? TurnPhase.noMoves : TurnPhase.thinking;
    _notify();
    final MoveSequence? sequence = await _opponent.chooseSequence(_game.state);
    if (_isStale(generation)) return;
    if (sequence == null || sequence.isEmpty) {
      if (!await _wait(timing.noMoves, generation)) return;
      // Пустой ход при живых вариантах — просроченный таймер соперника (§6).
      await _passTurn(generation, forced: options.isNotEmpty);
      return;
    }
    if (!await _playSequence(sequence, generation)) return;
    if (!await _wait(timing.beforeCommit, generation)) return;
    await _commit(generation);
  }

  /// Заменяет бросок текущего хода согласованным с соперником.
  Future<bool> _syncRoll(TurnCoordinator coordinator, int generation) async {
    final DiceRoll roll;
    try {
      roll = await coordinator.roll(_game.state);
    } on Object {
      _abort(MatchAbortReason.connection);
      return false;
    }
    if (_isStale(generation)) return false;
    _game.restore(
      _game.state.copyWith(
        roll: roll,
        remainingDice: roll.toRemaining(),
        headMovesUsed: 0,
      ),
    );
    _notify();
    return true;
  }

  /// Передаёт очередь без перемещений. [forced] — ход просрочен по таймеру.
  Future<void> _passTurn(int generation, {required bool forced}) async {
    final GameState before = _game.state;
    _lastTurnMoves = const <Move>[];
    _planner = null;
    _game.pass(forced: forced);
    if (!await _publishLocal(before, MoveSequence.empty, generation)) return;
    unawaited(_runTurn());
  }

  Future<bool> _playSequence(MoveSequence sequence, int generation) async {
    for (final Move move in sequence.moves) {
      _play(move);
      if (!await _wait(timing.move + timing.betweenMoves, generation)) {
        return false;
      }
    }
    return true;
  }

  void _play(Move move) {
    _planner!.apply(move);
    _feedback.checker();
    _animated = AnimatedMove(move: move, serial: ++_animationSerial);
    _notify();
  }

  Future<void> _commit(int generation) async {
    final TurnPlanner? planner = _planner;
    if (planner == null || !planner.isComplete) return;
    final MoveSequence sequence = planner.canonicalSequence!;
    final GameState before = _game.state;
    _planner = null;
    _selected = null;
    _lastTurnMoves = sequence.moves;
    _game.play(sequence);
    if (!await _publishLocal(before, sequence, generation)) return;
    if (_game.isFinished) {
      _finish(_game.result!);
      return;
    }
    unawaited(_runTurn());
  }

  /// Отправляет свой ход сопернику. Возвращает `false`, если партия за это
  /// время успела смениться. Оффлайн не ждёт ничего.
  Future<bool> _publishLocal(
    GameState before,
    MoveSequence sequence,
    int generation,
  ) async {
    final TurnCoordinator? coordinator = _coordinator;
    if (coordinator == null || before.turn != setup.localPlayer) {
      return !_isStale(generation);
    }
    try {
      await coordinator.publish(before, sequence);
    } on Object {
      _abort(MatchAbortReason.connection);
      return false;
    }
    return !_isStale(generation);
  }

  /// Сигналы ведущего: пересборка позиции, внешний итог, аннулирование (§6).
  void _handleSignal(MatchSignal signal) {
    if (_disposed) return;
    switch (signal) {
      case ResyncSignal(state: final GameState state):
        _resync(state);
      case FinishSignal(result: final GameResult result):
        if (isOver) return;
        _generation++;
        _planner = null;
        _selected = null;
        _animated = null;
        _finish(result);
      case AbortSignal(reason: final MatchAbortReason reason):
        _abort(reason);
    }
  }

  /// Позиция пересобрана реплеем журнала — ход начинается заново с неё.
  void _resync(GameState state) {
    if (isOver) return;
    _generation++;
    _planner = null;
    _selected = null;
    _animated = null;
    _lastTurnMoves = const <Move>[];
    _game.restore(state);
    if (_game.isFinished) {
      _finish(_game.result!);
      return;
    }
    unawaited(_runTurn());
  }

  void _abort(MatchAbortReason reason) {
    if (isOver) return;
    _generation++;
    _planner = null;
    _selected = null;
    _animated = null;
    _abortReason = reason;
    _phase = TurnPhase.aborted;
    _notify();
  }

  void _finish(GameResult result) {
    _result = result;
    _score = _score.add(result);
    _phase = TurnPhase.finished;
    _feedback.gameOver(won: result.winner == setup.localPlayer);
    onGameFinished?.call(result);
    _notify();
  }

  /// Ждёт [duration]; `false` — за время ожидания партия успела смениться.
  Future<bool> _wait(Duration duration, int generation) async {
    if (duration > Duration.zero) {
      await Future<void>.delayed(duration);
    }
    return !_isStale(generation);
  }

  bool _isStale(int generation) => _disposed || generation != _generation;

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}

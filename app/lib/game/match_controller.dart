import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';

import 'feedback.dart';
import 'game_log.dart';
import 'saved_game.dart';
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
    SavedBotGame? resume,
    MatchScore? initialScore,
  }) : _resume = resume,
       _game = Game(dice: dice ?? RandomDiceSource()),
       _opponent = opponent ?? createOpponent(setup),
       _feedback = feedback ?? const SilentFeedback(),
       _coordinator = coordinator,
       _score = resume?.score ?? initialScore ?? MatchScore(target: setup.target) {
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

  /// Сохранённая позиция, с которой продолжить первую партию.
  SavedBotGame? _resume;

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
  bool _rollSkipped = false;

  /// Идёт анимация составного хода одной шашкой — доска ждёт.
  bool _chaining = false;

  /// Цепочки для выбранной шашки: считаются один раз на позицию и пункт.
  (int, GameState)? _pathsKey;
  Map<int?, List<Move>> _pathsCache = const <int?, List<Move>>{};

  /// Состояние доски: с учётом уже собранных, но ещё не подтверждённых
  /// перемещений.
  GameState get state => _planner?.current ?? _game.state;

  TurnPhase get phase => _phase;

  /// Ход пропущен без броска: игрок заперт при любых костях.
  bool get rollSkipped => _rollSkipped;

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

  bool get canInteract =>
      _phase == TurnPhase.choosing && _planner != null && !_chaining;

  bool get canConfirm => canInteract && _planner!.isComplete;

  bool get canUndo => canInteract && _planner!.canUndo;

  /// Пункты, с которых сейчас можно ходить.
  Iterable<int> get movableSources =>
      canInteract ? _planner!.sources : const <int>[];

  /// Куда может пойти выбранная шашка; `null` в списке — выброс.
  List<int?> get destinations => _paths.keys.toList();

  /// Цели из [destinations], куда шашка дойдёт только за несколько перемещений.
  Set<int?> get chainedDestinations => <int?>{
    for (final MapEntry<int?, List<Move>> entry in _paths.entries)
      if (entry.value.length > 1) entry.key,
  };

  Map<int?, List<Move>> get _paths {
    final int? from = _selected;
    if (from == null || !canInteract) return const <int?, List<Move>>{};
    final (int, GameState) key = (from, _planner!.current);
    if (key != _pathsKey) {
      _pathsKey = key;
      _pathsCache = _planner!.pathsFrom(from);
    }
    return _pathsCache;
  }

  /// Сколько перемещений уже собрано и сколько нужно всего.
  int get movesPlayed => _planner?.played.length ?? 0;

  int get movesRequired => _planner?.maxMoves ?? 0;

  /// Начинает партию: розыгрыш первого хода и первый бросок (§3.2.1).
  /// В онлайне и то и другое согласуется с соперником.
  void start() {
    final TurnCoordinator? coordinator = _coordinator;
    if (coordinator == null) {
      final SavedBotGame? resume = _resume;
      _resume = null;
      if (resume == null) {
        _game.start();
      } else {
        _game.restore(resume.state);
      }
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
    _clearDraft();
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
      final List<Move>? path = _paths[abs];
      if (path != null) {
        _playPath(path);
        return;
      }
    }
    if (planner.movesFrom(abs).isEmpty || from == abs) {
      _selected = null;
      _notify();
      return;
    }
    // Куда идти — однозначно (часто это выброс): ходим сразу, без второго тапа.
    final Map<int?, List<Move>> paths = planner.pathsFrom(abs);
    if (paths.length == 1) {
      _playPath(paths.values.single);
      return;
    }
    _selected = abs;
    _notify();
  }

  /// Тап по лотку выброса выбранной шашкой (chiqarish).
  void tapBearOff() {
    if (!canInteract) return;
    final List<Move>? path = _paths[null];
    if (path != null) _playPath(path);
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
    final List<Move>? path = _planner!.pathsFrom(fromAbs)[toAbs];
    if (path == null) {
      _notify();
      return;
    }
    _playPath(path);
  }

  /// Одно перемещение — сразу; цепочка одной шашкой — по шагам с анимацией.
  void _playPath(List<Move> path) {
    _selected = null;
    if (path.length == 1) {
      _play(path.single);
      return;
    }
    unawaited(_playChain(path));
  }

  Future<void> _playChain(List<Move> path) async {
    _chaining = true;
    try {
      await _playSequence(MoveSequence(path), _generation);
    } finally {
      _chaining = false;
      _notify();
    }
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
  void resign({bool mars = true}) {
    if (isOver) return;
    _generation++;
    _clearDraft();
    _game.resign(resigningPlayer, mars: mars);
    unawaited(_coordinator?.publishResign());
    _finish(_game.result!);
  }

  /// Кто сдаётся с этого экрана: в hotseat — тот, чей ход.
  Player get resigningPlayer =>
      _opponent.movesOnThisDevice ? _game.state.turn : setup.localPlayer;

  /// Сдача на марс ничего не меняет: у сдающегося уже есть выброшенная шашка.
  bool get resignationIsSingle => _game.state.borneOff(resigningPlayer) > 0;

  /// Обычная сдача на 1 очко — только с согласия соперника. `true` — принята.
  /// В онлайне итог приезжает сигналом от комнаты.
  Future<bool> offerResignation() async {
    if (isOver) return false;
    final bool accepted = await _opponent.acceptsSingleResignation(_game.state);
    if (!accepted || isOver || _disposed) return accepted;
    if (_coordinator == null) {
      _generation++;
      _clearDraft();
      _game.resign(resigningPlayer, mars: false);
      _finish(_game.result!);
    }
    return true;
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
    if (_finishIfOver()) return;
    unawaited(_runTurn());
  }

  Future<void> _runTurn() async {
    // Партия могла закончиться внешним сигналом, пока предыдущий ход
    // досчитывал свои await'ы — новый ход тогда начинать нельзя.
    if (isOver) return;
    final int generation = _generation;
    _clearDraft();
    // shortcut: между партиями серии сохранения нет — выход на итоговом экране теряет счёт.
    if (setup.mode == GameMode.bot) {
      settings.savedBotGame = SavedBotGame(setup.botLevel!, _score, _game.state).encode();
    }
    // Заперт при любом броске — кости не бросаем. Только оффлайн:
    // в онлайне бросок нужен журналу комнаты.
    _rollSkipped =
        _coordinator == null && !_generator.canMoveWithAnyRoll(_game.state);
    if (_rollSkipped) {
      _phase = TurnPhase.noMoves;
      _notify();
      if (!await _wait(timing.noMoves, generation)) return;
      await _passTurn(generation, forced: false);
      return;
    }
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
    logTurn(before, MoveSequence.empty, local: before.turn == setup.localPlayer);
    _game.pass(forced: forced);
    if (!await _publishLocal(before, MoveSequence.empty, generation)) return;
    unawaited(_runTurn());
  }

  Future<bool> _playSequence(MoveSequence sequence, int generation) async {
    for (final Move move in sequence.moves) {
      // Нулевая пауза не ждёт: пересборка могла случиться уже после проверки в _wait.
      if (_isStale(generation)) return false;
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
    logTurn(before, sequence, local: before.turn == setup.localPlayer);
    _game.play(sequence);
    if (!await _publishLocal(before, sequence, generation)) return;
    if (_finishIfOver()) return;
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
        _clearDraft();
        _finish(result);
      case AbortSignal(reason: final MatchAbortReason reason):
        _abort(reason);
    }
  }

  /// Позиция пересобрана реплеем журнала — ход начинается заново с неё.
  void _resync(GameState state) {
    if (isOver) return;
    _generation++;
    _clearDraft();
    _lastTurnMoves = const <Move>[];
    _game.restore(state);
    if (_finishIfOver()) return;
    unawaited(_runTurn());
  }

  void _abort(MatchAbortReason reason) {
    if (isOver) return;
    _generation++;
    _clearDraft();
    _abortReason = reason;
    _phase = TurnPhase.aborted;
    _notify();
  }

  /// Забывает недособранный ход: план, выбранную шашку и анимацию.
  /// Счёт серии, история последнего хода и фаза остаются на совести вызова.
  void _clearDraft() {
    _planner = null;
    _selected = null;
    _animated = null;
  }

  /// Партия закончилась выбросом — итог посчитан ядром. `true` — доигранa,
  /// новый ход начинать не нужно.
  bool _finishIfOver() {
    if (!_game.isFinished) return false;
    _finish(_game.result!);
    return true;
  }

  void _finish(GameResult result) {
    logResult(result);
    if (setup.mode == GameMode.bot) settings.savedBotGame = null;
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

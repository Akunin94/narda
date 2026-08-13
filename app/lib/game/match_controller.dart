import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';

import 'game_setup.dart';
import 'opponent.dart';
import 'settings.dart';
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
class MatchController extends ChangeNotifier {
  MatchController({
    required this.setup,
    required this.settings,
    DiceSource? dice,
    Opponent? opponent,
    this.timing = const MatchTiming(),
  }) : _game = Game(dice: dice ?? RandomDiceSource()),
       _opponent = opponent ?? createOpponent(setup);

  static const MoveGenerator _generator = MoveGenerator();

  final GameSetup setup;
  final SettingsController settings;
  final MatchTiming timing;

  final Game _game;
  final Opponent _opponent;

  TurnPhase _phase = TurnPhase.rolling;
  TurnPlanner? _planner;
  GameResult? _result;
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
  void start() {
    _game.start();
    unawaited(_runTurn());
  }

  /// Новая партия теми же настройками.
  void rematch() {
    _generation++;
    _result = null;
    _planner = null;
    _selected = null;
    _animated = null;
    _lastTurnMoves = const <Move>[];
    start();
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
    if (_phase == TurnPhase.finished) return;
    _generation++;
    final Player resigning = _opponent.movesOnThisDevice
        ? _game.state.turn
        : setup.localPlayer;
    _planner = null;
    _selected = null;
    _animated = null;
    _game.resign(resigning);
    _finish(_game.result!);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _opponent.dispose();
    super.dispose();
  }

  Future<void> _runTurn() async {
    final int generation = _generation;
    _planner = null;
    _selected = null;
    _animated = null;
    _phase = TurnPhase.rolling;
    _notify();

    if (!await _wait(timing.dice, generation)) return;

    final List<MoveSequence> options = _generator.generate(_game.state);
    if (options.isEmpty) {
      _phase = TurnPhase.noMoves;
      _notify();
      if (!await _wait(timing.noMoves, generation)) return;
      _lastTurnMoves = const <Move>[];
      _game.pass();
      unawaited(_runTurn());
      return;
    }

    final TurnPlanner planner = TurnPlanner(base: _game.state, options: options);
    _planner = planner;

    if (isLocalTurn) {
      _phase = TurnPhase.choosing;
      _notify();
      if (settings.autoMove && options.length == 1) {
        if (!await _playSequence(options.first, generation)) return;
        await _commit(generation);
      }
      return;
    }

    _phase = TurnPhase.thinking;
    _notify();
    final MoveSequence? sequence = await _opponent.chooseSequence(_game.state);
    if (_isStale(generation)) return;
    if (sequence != null && !await _playSequence(sequence, generation)) return;
    if (!await _wait(timing.beforeCommit, generation)) return;
    await _commit(generation);
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
    _animated = AnimatedMove(move: move, serial: ++_animationSerial);
    _notify();
  }

  Future<void> _commit(int generation) async {
    final TurnPlanner? planner = _planner;
    if (planner == null || !planner.isComplete) return;
    final MoveSequence sequence = planner.canonicalSequence!;
    _planner = null;
    _selected = null;
    _lastTurnMoves = sequence.moves;
    _game.play(sequence);
    if (_game.isFinished) {
      _finish(_game.result!);
      return;
    }
    if (_isStale(generation)) return;
    unawaited(_runTurn());
  }

  void _finish(GameResult result) {
    _result = result;
    _phase = TurnPhase.finished;
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

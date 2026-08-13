import 'package:narda_core/narda_core.dart';

/// Сбор хода по одному перемещению поверх ядра.
///
/// Ядро отдаёт только максимальные последовательности целиком (§3.2.6), а
/// доске нужно знать, что разрешено прямо сейчас. Перемещение допускается,
/// если после него всё ещё достижима максимальная длина хода — тогда игрок
/// физически не может «сыграть меньше, когда можно больше», в каком бы
/// порядке он ни двигал шашки.
///
/// Порядок перемещений игрока может не совпадать ни с одной из последовательностей
/// ядра (оно схлопывает перестановки с одинаковым результатом), поэтому перед
/// применением ход приводится к каноничному варианту — [canonicalSequence].
class TurnPlanner {
  TurnPlanner({required this.base, List<MoveSequence>? options})
    : options = List<MoveSequence>.unmodifiable(
        options ?? _generator.generate(base),
      ) {
    _states.add(base);
    _refresh();
  }

  static const MoveGenerator _generator = MoveGenerator();

  /// Состояние на начало хода — к нему возвращает [reset].
  final GameState base;

  /// Максимальные ходы из [base]. Пустой список — ходов нет, пас.
  final List<MoveSequence> options;

  final List<Move> _played = <Move>[];
  final List<GameState> _states = <GameState>[];

  Map<int, List<Move>> _allowed = const <int, List<Move>>{};

  /// Сколько перемещений игрок обязан сделать за этот ход.
  int get maxMoves => options.isEmpty ? 0 : options.first.length;

  /// Состояние с учётом уже сделанных перемещений.
  GameState get current => _states.last;

  List<Move> get played => List<Move>.unmodifiable(_played);

  bool get isComplete => maxMoves > 0 && _played.length == maxMoves;

  bool get canUndo => _played.isNotEmpty;

  /// Пункты, с которых сейчас можно ходить.
  Iterable<int> get sources => _allowed.keys;

  /// Перемещения с пункта [fromAbs], разрешённые прямо сейчас.
  List<Move> movesFrom(int fromAbs) => _allowed[fromAbs] ?? const <Move>[];

  /// Перемещение с [fromAbs] на [toAbs] (`null` — выброс), если оно разрешено.
  Move? moveTo(int fromAbs, int? toAbs) {
    for (final Move move in movesFrom(fromAbs)) {
      if (move.toAbs == toAbs) return move;
    }
    return null;
  }

  void apply(Move move) {
    _played.add(move);
    _states.add(current.applyMove(move));
    _refresh();
  }

  void undo() {
    if (_played.isEmpty) return;
    _played.removeLast();
    _states.removeLast();
    _refresh();
  }

  void reset() {
    if (_played.isEmpty) return;
    _played.clear();
    _states
      ..clear()
      ..add(base);
    _refresh();
  }

  /// Собранный ход в том виде, в каком его принимает ядро: та из [options],
  /// что приводит к тому же состоянию. `null` — ход ещё не собран.
  MoveSequence? get canonicalSequence {
    if (!isComplete) return null;
    for (final MoveSequence option in options) {
      if (base.applySequence(option) == current) return option;
    }
    // Недостижимо: сыгранная последовательность максимальна и легальна,
    // значит её результат обязан встретиться среди вариантов ядра.
    return MoveSequence(_played);
  }

  void _refresh() {
    final int remaining = maxMoves - _played.length;
    if (remaining <= 0) {
      _allowed = const <int, List<Move>>{};
      return;
    }
    final Map<int, List<Move>> allowed = <int, List<Move>>{};
    void add(Move move) => (allowed[move.fromAbs] ??= <Move>[]).add(move);

    if (_played.isEmpty && maxMoves == 1) {
      // Играется ровно одно число — ядро уже отобрало большее из играбельных.
      for (final MoveSequence option in options) {
        add(option.moves.first);
      }
    } else {
      final GameState state = current;
      final Set<int> tried = <int>{};
      for (final int die in state.remainingDice) {
        if (!tried.add(die)) continue;
        for (final Move move in _generator.legalSingles(state, die)) {
          if (_maxDepth(state.applyMove(move)) + 1 == remaining) add(move);
        }
      }
    }
    _allowed = allowed;
  }

  /// Сколько перемещений ещё можно сделать из состояния [state].
  static int _maxDepth(GameState state) {
    final List<MoveSequence> continuations = _generator.generate(state);
    return continuations.isEmpty ? 0 : continuations.first.length;
  }
}

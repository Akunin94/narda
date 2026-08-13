import 'coords.dart';
import 'game_state.dart';
import 'move.dart';
import 'player.dart';
import 'rules.dart';

/// Генератор легальных ходов.
///
/// [generate] возвращает ТОЛЬКО максимальные последовательности: игрок обязан
/// использовать как можно больше чисел броска, а если играбельно ровно одно
/// из двух — обязан сыграть большее (§3.2.6).
class MoveGenerator {
  const MoveGenerator();

  /// Все максимальные ходы в позиции. Пустой список — ходов нет, пас.
  List<MoveSequence> generate(GameState state) {
    if (state.isFinished || state.remainingDice.isEmpty) {
      return const <MoveSequence>[];
    }
    final search = _Search(state)..run();
    return search.maximalSequences();
  }

  /// Одиночные перемещения числом [die], легальные сами по себе.
  /// Не гарантируют максимальности хода — для выбора хода используй
  /// [generate], этот метод нужен для подсветки и отладки.
  List<Move> legalSingles(GameState state, int die) {
    if (state.isFinished || !state.remainingDice.contains(die)) {
      return const <Move>[];
    }
    return _Search(state).singles(die);
  }

  /// Есть ли у игрока хоть одно легальное перемещение.
  bool hasAnyMove(GameState state) {
    if (state.isFinished || state.remainingDice.isEmpty) return false;
    return _Search(state).hasAnyMove();
  }
}

/// Перебор ходов на изменяемой «черновой» доске: во время поиска состояние
/// соперника неизменно, поэтому достаточно хранить шашки ходящего игрока.
class _Search {
  _Search(this.state)
    : mover = state.turn,
      headAbs = Coords.headAbs(state.turn),
      headLimit = Rules.headLimit(state),
      skipBlockCheck = state.borneOff(state.turn.opponent) > 0,
      counts = List<int>.filled(Coords.pointCount, 0),
      dice = List<int>.of(state.remainingDice) {
    dice.sort((int a, int b) => b - a);
    used = List<bool>.filled(dice.length, false);
    for (var abs = 1; abs <= Coords.pointCount; abs++) {
      final count = state.checkersAt(mover, abs);
      if (count > 0) {
        counts[Coords.absIndex(abs)] = count;
        moverMask |= 1 << Coords.absIndex(abs);
      }
    }
    opponentMask = state.occupancyMask(mover.opponent);
    opponentMaskInOwn = Rules.maskInOwnNumbering(
      absoluteMask: opponentMask,
      viewer: mover.opponent,
    );
    moverBorneOff = state.borneOff(mover);
    headMovesUsed = state.headMovesUsed;
  }

  final GameState state;
  final Player mover;
  final int headAbs;
  final int headLimit;
  final bool skipBlockCheck;

  /// Шашки ходящего игрока по абсолютным пунктам.
  final List<int> counts;
  final List<int> dice;
  late final List<bool> used;

  int moverMask = 0;
  late final int opponentMask;
  late final int opponentMaskInOwn;
  late int moverBorneOff;
  late int headMovesUsed;

  final List<Move> path = <Move>[];
  final List<MoveSequence> _results = <MoveSequence>[];
  final Set<String> _keys = <String>{};
  int _bestDepth = 0;

  void run() => _dfs(0);

  List<MoveSequence> maximalSequences() {
    if (_bestDepth == 1 && !state.roll.isDouble && dice.length > 1) {
      final highest = dice.first;
      final withHighest = _results
          .where((MoveSequence s) => s.moves.first.die == highest)
          .toList();
      if (withHighest.isNotEmpty) return withHighest;
    }
    return _results;
  }

  List<Move> singles(int die) {
    final sink = <Move>[];
    _expand(die, 0, sink);
    return sink;
  }

  bool hasAnyMove() {
    final sink = <Move>[];
    var lastValue = 0;
    for (var i = 0; i < dice.length; i++) {
      if (dice[i] == lastValue) continue;
      lastValue = dice[i];
      if (_expand(dice[i], 0, sink)) return true;
    }
    return false;
  }

  void _dfs(int depth) {
    var extended = false;
    var lastValue = 0;
    for (var i = 0; i < dice.length; i++) {
      if (used[i]) continue;
      final die = dice[i];
      // Одинаковые числа в остатке взаимозаменяемы — пробуем значение один раз.
      if (die == lastValue) continue;
      lastValue = die;
      used[i] = true;
      if (_expand(die, depth, null)) extended = true;
      used[i] = false;
    }
    if (!extended) _record(depth);
  }

  /// Перебирает перемещения числом [die]. Если [sink] задан — только собирает
  /// их, иначе рекурсивно продолжает ход. Возвращает `true`, если было хотя бы
  /// одно легальное перемещение.
  bool _expand(int die, int depth, List<Move>? sink) {
    final ownMask = mover == Player.white
        ? moverMask
        : Rules.rotateHalf(moverMask);
    final allInHome = ownMask & ~Rules.homeMask & Rules.fullMask == 0;
    final farthestOwn = ownMask.bitLength;

    var found = false;
    var rest = ownMask;
    while (rest != 0) {
      final bit = rest & -rest;
      rest ^= bit;
      final own = bit.bitLength;
      final fromAbs = Coords.toAbsolute(mover, own);
      if (fromAbs == headAbs && headMovesUsed >= headLimit) continue;

      final targetOwn = own - die;
      int? toAbs;
      if (targetOwn >= 1) {
        final candidate = Coords.toAbsolute(mover, targetOwn);
        if (opponentMask >> Coords.absIndex(candidate) & 1 == 1) continue;
        toAbs = candidate;
      } else {
        if (!allInHome) continue;
        // Превышающий выброс разрешён только с самого дальнего пункта.
        if (targetOwn < 0 && own != farthestOwn) continue;
      }

      _apply(fromAbs, toAbs);
      if (_createsIllegalBlock()) {
        _undo(fromAbs, toAbs);
        continue;
      }
      found = true;
      final move = Move(
        player: mover,
        fromAbs: fromAbs,
        die: die,
        toAbs: toAbs,
      );
      if (sink != null) {
        sink.add(move);
      } else {
        path.add(move);
        _dfs(depth + 1);
        path.removeLast();
      }
      _undo(fromAbs, toAbs);
    }
    return found;
  }

  void _apply(int fromAbs, int? toAbs) {
    final from = Coords.absIndex(fromAbs);
    counts[from]--;
    if (counts[from] == 0) moverMask &= ~(1 << from);
    if (toAbs == null) {
      moverBorneOff++;
    } else {
      final to = Coords.absIndex(toAbs);
      counts[to]++;
      moverMask |= 1 << to;
    }
    if (fromAbs == headAbs) headMovesUsed++;
  }

  void _undo(int fromAbs, int? toAbs) {
    final from = Coords.absIndex(fromAbs);
    counts[from]++;
    moverMask |= 1 << from;
    if (toAbs == null) {
      moverBorneOff--;
    } else {
      final to = Coords.absIndex(toAbs);
      counts[to]--;
      if (counts[to] == 0) moverMask &= ~(1 << to);
    }
    if (fromAbs == headAbs) headMovesUsed--;
  }

  bool _createsIllegalBlock() {
    if (skipBlockCheck) return false;
    final moverInOpponentOwn = mover == Player.white
        ? Rules.rotateHalf(moverMask)
        : moverMask;
    return Rules.hasIllegalBlock(
      moverMask: moverInOpponentOwn,
      opponentMask: opponentMaskInOwn,
    );
  }

  void _record(int depth) {
    if (depth == 0 || depth < _bestDepth) return;
    if (depth > _bestDepth) {
      _bestDepth = depth;
      _results.clear();
      _keys.clear();
    }
    if (_keys.add(_leafKey())) {
      _results.add(MoveSequence(List<Move>.of(path)));
    }
  }

  /// Ключ дедупликации: итоговая расстановка ходящего игрока плюс
  /// использованный набор чисел. Разные порядки одного и того же результата
  /// схлопываются в один вариант.
  String _leafKey() {
    final codes = List<int>.filled(Coords.pointCount + 2 + path.length, 0);
    for (var i = 0; i < Coords.pointCount; i++) {
      codes[i] = 48 + counts[i];
    }
    codes[Coords.pointCount] = 48 + moverBorneOff;
    codes[Coords.pointCount + 1] = 48 + headMovesUsed;
    final usedDice = path.map((Move m) => m.die).toList()..sort();
    for (var i = 0; i < usedDice.length; i++) {
      codes[Coords.pointCount + 2 + i] = 48 + usedDice[i];
    }
    return String.fromCharCodes(codes);
  }
}

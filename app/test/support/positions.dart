import 'package:narda_core/narda_core.dart';

/// Собирает произвольную позицию для тестов UI-слоя.
///
/// Количество шашек не обязано равняться 15 — позиции намеренно урезаны,
/// чтобы проверять поведение точечно. [turnIndex] по умолчанию 2: ход не
/// первый, исключение головы не действует.
GameState position({
  required Player turn,
  required DiceRoll roll,
  Map<int, int> white = const <int, int>{},
  Map<int, int> black = const <int, int>{},
  int whiteBorneOff = 0,
  int blackBorneOff = 0,
  int turnIndex = 2,
  int headMovesUsed = 0,
  List<int>? remainingDice,
}) {
  final List<int> points = List<int>.filled(Coords.pointCount, 0);
  white.forEach((int abs, int count) => points[Coords.absIndex(abs)] += count);
  black.forEach((int abs, int count) => points[Coords.absIndex(abs)] -= count);
  return GameState(
    points: points,
    turn: turn,
    roll: roll,
    remainingDice: remainingDice ?? roll.toRemaining(),
    whiteBorneOff: whiteBorneOff,
    blackBorneOff: blackBorneOff,
    turnIndex: turnIndex,
    headMovesUsed: headMovesUsed,
  );
}

/// Источник костей для тестов: [singles] — розыгрыш первого хода,
/// [roll] повторяется на каждом ходу.
DiceSource scriptedDice({
  List<int> singles = const <int>[6, 1],
  DiceRoll roll = const DiceRoll(3, 1),
  List<DiceRoll>? rolls,
}) => ScriptedDiceSource(
  singles,
  rolls ?? List<DiceRoll>.filled(200, roll),
);

import 'package:narda_core/narda_core.dart';

/// Собирает произвольную позицию для юнит-тестов.
///
/// [white] и [black] — карты «абсолютный пункт -> число шашек». Количество
/// шашек не обязано равняться 15: тестовые позиции намеренно урезаны, чтобы
/// проверять правило точечно. [turnIndex] по умолчанию 2 — то есть ход НЕ
/// первый и исключение головы не действует.
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
  final points = List<int>.filled(Coords.pointCount, 0);
  white.forEach((int abs, int count) {
    points[Coords.absIndex(abs)] += count;
  });
  black.forEach((int abs, int count) {
    points[Coords.absIndex(abs)] -= count;
  });
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

/// Позиция шашек игрока после хода: «абсолютный пункт -> число шашек».
Map<int, int> layout(GameState state, Player player) {
  final result = <int, int>{};
  for (var abs = 1; abs <= Coords.pointCount; abs++) {
    final count = state.checkersAt(player, abs);
    if (count > 0) result[abs] = count;
  }
  return result;
}

/// Итоговые расстановки ходящего игрока по всем вариантам хода.
Set<String> outcomes(GameState state, List<MoveSequence> sequences) => sequences
    .map((MoveSequence s) {
      final after = state.applySequence(s);
      return '${layout(after, state.turn)}+${after.borneOff(state.turn)}';
    })
    .toSet();

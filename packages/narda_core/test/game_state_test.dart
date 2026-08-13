import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

import 'support/positions.dart';

void main() {
  group('GameState', () {
    test('стартовая расстановка: 15 на абс. 24 и 15 на абс. 12', () {
      final state = GameState.initial(
        first: Player.white,
        roll: const DiceRoll(3, 1),
      );
      expect(state.checkersAt(Player.white, 24), 15);
      expect(state.checkersAt(Player.black, 12), 15);
      expect(state.onBoard(Player.white), 15);
      expect(state.onBoard(Player.black), 15);
      expect(state.pipCount(Player.white), 15 * 24);
      expect(state.pipCount(Player.black), 15 * 24);
      expect(state.validate(), isEmpty);
      expect(state.remainingDice, <int>[3, 1]);
    });

    test('дубль даёт четыре перемещения', () {
      final state = GameState.initial(
        first: Player.black,
        roll: const DiceRoll(5, 5),
      );
      expect(state.remainingDice, <int>[5, 5, 5, 5]);
    });

    test('applyMove не меняет исходное состояние', () {
      final before = GameState.initial(
        first: Player.white,
        roll: const DiceRoll(6, 5),
      );
      final after = before.applyMove(
        Move.point(player: Player.white, fromAbs: 24, die: 6),
      );
      expect(before.checkersAt(Player.white, 24), 15);
      expect(before.remainingDice, <int>[6, 5]);
      expect(after.checkersAt(Player.white, 24), 14);
      expect(after.checkersAt(Player.white, 18), 1);
      expect(after.remainingDice, <int>[5]);
      expect(after.headMovesUsed, 1);
      expect(() => before.points[0] = 1, throwsUnsupportedError);
    });

    test('nextTurn передаёт очередь и обнуляет счётчик головы', () {
      final state = GameState.initial(
        first: Player.white,
        roll: const DiceRoll(6, 5),
      ).applyMove(Move.point(player: Player.white, fromAbs: 24, die: 6));
      final next = state.nextTurn(const DiceRoll(2, 2));
      expect(next.turn, Player.black);
      expect(next.turnIndex, 1);
      expect(next.headMovesUsed, 0);
      expect(next.remainingDice, <int>[2, 2, 2, 2]);
      expect(next.isFirstTurnOfMover, isTrue);
      expect(next.nextTurn(const DiceRoll(1, 2)).isFirstTurnOfMover, isFalse);
    });

    test('encode/decode — полный round-trip', () {
      final state = position(
        turn: Player.black,
        roll: const DiceRoll(4, 2),
        white: <int, int>{24: 13, 18: 2},
        black: <int, int>{12: 14, 6: 1},
        whiteBorneOff: 0,
        blackBorneOff: 0,
        turnIndex: 7,
        headMovesUsed: 1,
        remainingDice: <int>[2],
      );
      expect(GameState.decode(state.encode()), state);
      expect(GameState.decode(state.encode()).encode(), state.encode());
    });

    test('validate ловит нарушение числа шашек и общий пункт', () {
      final broken = position(
        turn: Player.white,
        roll: const DiceRoll(1, 2),
        white: <int, int>{5: 15},
        black: <int, int>{5: 1, 12: 14},
      );
      expect(broken.validate(), isNotEmpty);
    });

    test('pip и дом считаются в собственной нумерации', () {
      final state = position(
        turn: Player.black,
        roll: const DiceRoll(1, 2),
        black: <int, int>{13: 1, 18: 1},
      );
      // абс. 13 — собственный 1, абс. 18 — собственный 6.
      expect(state.pipCount(Player.black), 7);
      expect(state.allInHome(Player.black), isTrue);
      expect(state.farthestOwn(Player.black), 6);
    });
  });
}

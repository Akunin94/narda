import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

import 'support/positions.dart';

void main() {
  const generator = MoveGenerator();

  /// Белые стоят на абс. 5..9 и на абс. 16. Перемещение 16→10 замкнуло бы
  /// шесть подряд занятых пунктов абс. 5..10 — это собственные пункты 17..22
  /// чёрных, то есть стена прямо перед их головой (абс. 12 = их пункт 24).
  GameState fence({
    Map<int, int> black = const <int, int>{12: 15},
    int blackBorneOff = 0,
  }) => position(
    turn: Player.white,
    roll: const DiceRoll(6, 1),
    white: <int, int>{5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 16: 1},
    black: black,
    blackBorneOff: blackBorneOff,
  );

  Move closing() => Move.point(player: Player.white, fromAbs: 16, die: 6);

  group('правило шести подряд', () {
    test('глухой забор из шести запрещён, если все шашки соперника позади', () {
      final state = fence();
      expect(Rules.isLegalSingle(state, closing()), isFalse);
      expect(
        Rules.createsIllegalBlock(state.applyMove(closing()), Player.white),
        isTrue,
      );
      expect(
        generator.legalSingles(state, 6).where((Move m) => m.toAbs == 10),
        isEmpty,
      );
      for (final sequence in generator.generate(state)) {
        expect(sequence.moves.first, isNot(closing()));
      }
    });

    test('пять подряд — всегда легально', () {
      final state = fence();
      expect(Rules.createsIllegalBlock(state, Player.white), isFalse);
      final move = Move.point(player: Player.white, fromAbs: 16, die: 1);
      expect(Rules.isLegalSingle(state, move), isTrue);
    });

    test('одна шашка соперника впереди забора делает его легальным', () {
      // Абс. 3 — собственный пункт 15 чёрных, он впереди стены 17..22.
      final state = fence(black: <int, int>{12: 14, 3: 1});
      expect(Rules.isLegalSingle(state, closing()), isTrue);
    });

    test('шашка соперника позади забора не спасает', () {
      // Абс. 11 — собственный пункт 23 чёрных, он позади стены 17..22.
      final state = fence(black: <int, int>{12: 14, 11: 1});
      expect(Rules.isLegalSingle(state, closing()), isFalse);
    });

    test('выброшенная шашка соперника считается прошедшей забор', () {
      final state = fence(black: <int, int>{12: 14}, blackBorneOff: 1);
      expect(Rules.isLegalSingle(state, closing()), isTrue);
    });

    test('шесть подряд, разорванные концом маршрута соперника, — не забор', () {
      // Абс. 10, 11, 13..16 для чёрных это собственные 22, 23 и 1..4:
      // единой стены на их пути нет.
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(1, 2),
        white: <int, int>{10: 1, 11: 1, 13: 1, 14: 1, 15: 1, 17: 1},
        black: <int, int>{12: 15},
      );
      final move = Move.point(player: Player.white, fromAbs: 17, die: 1);
      expect(Rules.isLegalSingle(state, move), isTrue);
      expect(
        Rules.createsIllegalBlock(state.applyMove(move), Player.white),
        isFalse,
      );
    });

    test('чёрные тоже не могут запереть белых', () {
      // Собственные пункты 17..22 белых — это абс. 17..22.
      final state = position(
        turn: Player.black,
        roll: const DiceRoll(1, 2),
        white: <int, int>{24: 15},
        black: <int, int>{17: 1, 18: 1, 19: 1, 20: 1, 21: 1, 23: 1},
      );
      final move = Move.point(player: Player.black, fromAbs: 23, die: 1);
      expect(move.toAbs, 22);
      expect(Rules.isLegalSingle(state, move), isFalse);
    });

    test('битовая проверка забора совпадает с ручным разбором', () {
      // Стена на собственных пунктах 1..6 соперника, впереди ничего нет.
      expect(
        Rules.hasIllegalBlock(moverMask: 0x3F, opponentMask: 1 << 23),
        isTrue,
      );
      // Стена на пунктах 2..7, шашка соперника уже на пункте 1 — впереди.
      expect(
        Rules.hasIllegalBlock(moverMask: 0x7E, opponentMask: 1),
        isFalse,
      );
      // Пять подряд — не стена.
      expect(
        Rules.hasIllegalBlock(moverMask: 0x1F, opponentMask: 1 << 23),
        isFalse,
      );
    });
  });
}

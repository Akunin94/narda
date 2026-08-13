import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

import 'support/positions.dart';

void main() {
  const generator = MoveGenerator();

  group('выброс (chiqarish)', () {
    test('нельзя выбрасывать, пока хоть одна шашка вне дома', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(3, 1),
        white: <int, int>{7: 1, 3: 1},
      );
      expect(Rules.canBearOff(state, Player.white), isFalse);
      expect(
        Rules.isLegalSingle(
          state,
          const Move.bearOff(player: Player.white, fromAbs: 3, die: 3),
        ),
        isFalse,
      );
      expect(
        generator.legalSingles(state, 3).every((Move m) => !m.isBearOff),
        isTrue,
      );
    });

    test('точный выброс: пункт 3 числом 3', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(3, 3),
        white: <int, int>{3: 2},
      );
      expect(
        Rules.isLegalSingle(
          state,
          const Move.bearOff(player: Player.white, fromAbs: 3, die: 3),
        ),
        isTrue,
      );

      final sequences = generator.generate(state);
      expect(sequences, hasLength(1));
      expect(sequences.single.length, 2);
      expect(sequences.single.moves.every((Move m) => m.isBearOff), isTrue);
      expect(state.applySequence(sequences.single).whiteBorneOff, 2);
    });

    test('превышающее число выбрасывает с самого дальнего пункта', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 2),
        white: <int, int>{4: 1, 2: 1},
      );
      expect(
        Rules.isLegalSingle(
          state,
          const Move.bearOff(player: Player.white, fromAbs: 4, die: 6),
        ),
        isTrue,
      );
      expect(outcomes(state, generator.generate(state)), contains('{}+2'));
    });

    test('превышающим числом нельзя снять не с самого дальнего пункта', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 1),
        white: <int, int>{5: 1, 4: 1},
      );
      expect(
        Rules.isLegalSingle(
          state,
          const Move.bearOff(player: Player.white, fromAbs: 4, die: 6),
        ),
        isFalse,
      );
      expect(
        Rules.isLegalSingle(
          state,
          const Move.bearOff(player: Player.white, fromAbs: 5, die: 6),
        ),
        isTrue,
      );
    });

    test('вместо выброса можно двигать внутри дома, но ход максимален', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(2, 1),
        white: <int, int>{6: 1, 5: 1},
      );
      final sequences = generator.generate(state);

      expect(sequences, isNotEmpty);
      for (final sequence in sequences) {
        expect(sequence.length, 2);
        expect(sequence.moves.every((Move m) => !m.isBearOff), isTrue);
      }
      expect(
        outcomes(state, sequences),
        <String>{'{4: 2}+0', '{3: 1, 5: 1}+0', '{2: 1, 6: 1}+0'},
      );
    });

    test('выброс чёрных считается в их собственной нумерации', () {
      // Абс. 18 — собственный 6, абс. 17 — собственный 5.
      final state = position(
        turn: Player.black,
        roll: const DiceRoll(6, 5),
        black: <int, int>{18: 1, 17: 1},
      );
      expect(Rules.canBearOff(state, Player.black), isTrue);
      expect(outcomes(state, generator.generate(state)), contains('{}+2'));
    });

    test('выброс обеих шашек завершает партию', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(3, 2),
        white: <int, int>{1: 2},
        black: <int, int>{13: 15},
        whiteBorneOff: 13,
      );
      final sequences = generator.generate(state);

      expect(sequences, hasLength(1));
      expect(sequences.single.moves.every((Move m) => m.isBearOff), isTrue);
      final after = state.applySequence(sequences.single);
      expect(after.whiteBorneOff, 15);
      expect(after.isFinished, isTrue);
      expect(after.winner, Player.white);
    });

    test('максимальность заставляет доиграть число внутри дома', () {
      // Точный выброс двойкой закрыл бы ход одним перемещением, но
      // 2→1 с последующим выбросом использует оба числа.
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(2, 1),
        white: <int, int>{2: 1},
        whiteBorneOff: 14,
      );
      final sequences = generator.generate(state);

      expect(sequences, hasLength(1));
      expect(sequences.single.length, 2);
      expect(sequences.single.moves.first.toAbs, 1);
      expect(sequences.single.moves.last.isBearOff, isTrue);
    });
  });
}

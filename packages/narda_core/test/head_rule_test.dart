import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

import 'support/positions.dart';

void main() {
  const generator = MoveGenerator();

  GameState opening(DiceRoll roll) =>
      GameState.initial(first: Player.white, roll: roll);

  group('правило головы', () {
    test('стартовое 6-6 белых: ровно две шашки с головы 24→18, 24→18', () {
      final state = opening(const DiceRoll(6, 6));
      final sequences = generator.generate(state);

      expect(sequences, hasLength(1));
      final only = sequences.single;
      expect(only.length, 2);
      expect(only.headMoves, 2);
      for (final move in only.moves) {
        expect(move.fromAbs, 24);
        expect(move.toAbs, 18);
        expect(move.die, 6);
      }

      final after = state.applySequence(only);
      expect(layout(after, Player.white), <int, int>{18: 2, 24: 13});
      // Из четырёх шестёрок дубля играются только две: дальше путь упирается
      // в голову чёрных на абс. 12, а третью шашку с головы снимать нельзя.
      expect(after.remainingDice, <int>[6, 6]);
      expect(generator.generate(after), isEmpty);
    });

    test('стартовое 4-4: две с головы и обе доходят до абс. 16', () {
      final state = opening(const DiceRoll(4, 4));
      final sequences = generator.generate(state);

      expect(sequences, hasLength(1));
      expect(sequences.single.length, 4);
      expect(sequences.single.headMoves, 2);
      expect(
        layout(state.applySequence(sequences.single), Player.white),
        <int, int>{16: 2, 24: 13},
      );
    });

    test('стартовое 3-3: все максимальные ходы снимают две шашки с головы', () {
      final state = opening(const DiceRoll(3, 3));
      final sequences = generator.generate(state);

      expect(sequences, isNotEmpty);
      for (final sequence in sequences) {
        expect(sequence.length, 4);
        expect(sequence.headMoves, 2);
      }
      expect(
        outcomes(state, sequences),
        contains('{18: 2, 24: 13}+0'),
      );
    });

    test('стартовое 5-5: исключения нет, идёт одна шашка 24→19→14→9→4', () {
      final state = opening(const DiceRoll(5, 5));
      final sequences = generator.generate(state);

      expect(sequences, hasLength(1));
      expect(sequences.single.length, 4);
      expect(sequences.single.headMoves, 1);
      expect(
        layout(state.applySequence(sequences.single), Player.white),
        <int, int>{4: 1, 24: 14},
      );
    });

    test('6-6 не на первом ходу: только одна шашка с головы, одно перемещение', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 6),
        white: <int, int>{24: 15},
        black: <int, int>{12: 15},
      );
      final sequences = generator.generate(state);

      expect(sequences, hasLength(1));
      expect(sequences.single.length, 1);
      expect(sequences.single.headMoves, 1);
      expect(Rules.headLimit(state), 1);
    });

    test('обычный бросок не позволяет снять вторую шашку с головы', () {
      final state = opening(const DiceRoll(6, 5));
      expect(Rules.headLimit(state), 1);
      for (final sequence in generator.generate(state)) {
        expect(sequence.headMoves, lessThanOrEqualTo(1));
      }
    });

    test('исключение действует и для чёрных на их первом ходу', () {
      final state = GameState.initial(
        first: Player.black,
        roll: const DiceRoll(6, 6),
      );
      expect(Rules.headLimit(state), 2);
      final sequences = generator.generate(state);
      expect(sequences.single.headMoves, 2);
      // Голова чёрных — абс. 12, шестёрка ведёт на абс. 6.
      expect(
        layout(state.applySequence(sequences.single), Player.black),
        <int, int>{6: 2, 12: 13},
      );
    });

    test('исключение действует только на первом ходу игрока', () {
      final second = GameState.initial(
        first: Player.white,
        roll: const DiceRoll(1, 1),
      ).nextTurn(const DiceRoll(6, 6));
      expect(second.turnIndex, 1);
      expect(Rules.headLimit(second), 2);

      final third = second.nextTurn(const DiceRoll(6, 6));
      expect(third.turnIndex, 2);
      expect(Rules.headLimit(third), 1);
    });
  });
}

import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

import 'support/positions.dart';

void main() {
  const generator = MoveGenerator();

  group('занятость пунктов', () {
    test('нельзя встать на пункт, занятый хотя бы одной шашкой соперника', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 1),
        white: <int, int>{10: 1},
        black: <int, int>{4: 1},
      );
      expect(
        Rules.isLegalSingle(
          state,
          Move.point(player: Player.white, fromAbs: 10, die: 6),
        ),
        isFalse,
      );
      expect(
        generator.legalSingles(state, 6).where((Move m) => m.toAbs == 4),
        isEmpty,
      );
    });

    test('на своём пункте помещается сколько угодно своих шашек', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(3, 1),
        white: <int, int>{10: 1, 7: 9},
      );
      final moves = generator.legalSingles(state, 3);
      expect(moves.any((Move m) => m.fromAbs == 10 && m.toAbs == 7), isTrue);
    });

    test('голова соперника блокирует так же, как любой занятый пункт', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 6),
        white: <int, int>{18: 1},
        black: <int, int>{12: 15},
      );
      expect(generator.generate(state), isEmpty);
    });
  });

  group('обязательность полного хода', () {
    test('играбельно только одно число — играем большее', () {
      // Белая шашка на абс. 10: шестёрка ведёт на 4, тройка — на 7,
      // но продолжения нет: собственный пункт 1 занят чёрными.
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 3),
        white: <int, int>{10: 1},
        black: <int, int>{1: 1},
      );
      final sequences = generator.generate(state);

      expect(sequences, hasLength(1));
      expect(sequences.single.length, 1);
      expect(sequences.single.moves.single.die, 6);
      expect(sequences.single.moves.single.toAbs, 4);
    });

    test('если большее сыграть нельзя — играем меньшее', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 3),
        white: <int, int>{10: 1},
        black: <int, int>{4: 1, 1: 1},
      );
      final sequences = generator.generate(state);

      expect(sequences, hasLength(1));
      expect(sequences.single.moves.single.die, 3);
      expect(sequences.single.moves.single.toAbs, 7);
    });

    test('когда играются оба числа, укороченных ходов в выдаче нет', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 3),
        white: <int, int>{20: 1, 15: 1},
      );
      final sequences = generator.generate(state);

      expect(sequences, isNotEmpty);
      for (final sequence in sequences) {
        expect(sequence.length, 2);
      }
    });

    test('дубль: если возможны четыре перемещения, все ходы длины 4', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(2, 2),
        white: <int, int>{20: 2},
      );
      final sequences = generator.generate(state);

      expect(sequences, isNotEmpty);
      for (final sequence in sequences) {
        expect(sequence.length, 4);
      }
    });

    test('нет ни одного перемещения — ход пропускается', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 3),
        white: <int, int>{7: 1},
        black: <int, int>{4: 1, 1: 1},
      );
      expect(generator.generate(state), isEmpty);
      expect(generator.hasAnyMove(state), isFalse);
    });

    test('одинаковые итоги при разном порядке костей схлопываются', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 3),
        white: <int, int>{20: 1},
      );
      final sequences = generator.generate(state);

      // 20→14→11 и 20→17→11 дают одну и ту же позицию.
      expect(sequences, hasLength(1));
      expect(
        layout(state.applySequence(sequences.single), Player.white),
        <int, int>{11: 1},
      );
    });
  });

  group('Game', () {
    test('нельзя пасовать, когда ход есть, и играть нелегальную последовательность', () {
      final game = Game(dice: RandomDiceSource.seeded(1))..start();
      expect(game.pass, throwsStateError);
      expect(
        () => game.play(
          MoveSequence(<Move>[
            Move.point(player: game.state.turn, fromAbs: 5, die: 1),
          ]),
        ),
        throwsArgumentError,
      );
    });

    test('первый ход разыгрывается одним кубиком, при равенстве — переброс', () {
      final dice = ScriptedDiceSource(
        <int>[4, 4, 2, 5],
        <DiceRoll>[const DiceRoll(3, 1)],
      );
      final game = Game(dice: dice);
      final opening = game.start();

      expect(opening.rerolls, 1);
      expect(opening.first, Player.black);
      expect(game.state.turn, Player.black);
      expect(game.state.roll, const DiceRoll(3, 1));
    });
  });
}

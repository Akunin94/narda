import 'dart:math';

import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

import 'support/naive_generator.dart';
import 'support/positions.dart';

/// Оптимизированный [MoveGenerator] сверяется с прямолинейным эталоном
/// [NaiveGenerator] на позициях из случайных партий: совпадать должны и
/// максимальная длина хода, и множество достижимых расстановок.
void main() {
  const fast = MoveGenerator();
  const naive = NaiveGenerator();

  void compare(GameState state) {
    final fastResult = fast.generate(state);
    final naiveResult = naive.generate(state);

    expect(
      fastResult.isEmpty,
      naiveResult.isEmpty,
      reason: 'ходы разошлись в наличии: ${state.encode()}',
    );
    if (fastResult.isEmpty) return;

    expect(
      fastResult.first.length,
      naiveResult.first.length,
      reason: 'разная длина максимального хода: ${state.encode()}',
    );
    for (final sequence in fastResult) {
      expect(sequence.length, fastResult.first.length);
    }
    expect(
      outcomes(state, fastResult),
      outcomes(state, naiveResult),
      reason: 'разные достижимые позиции: ${state.encode()}',
    );
  }

  test('генератор совпадает с эталоном на позициях случайных партий', () {
    final random = Random(20240501);
    var positionsChecked = 0;

    for (var game = 0; game < 40; game++) {
      final dice = RandomDiceSource.seeded(game);
      final match = Game(dice: dice)..start();
      final bot = RandomBot(seed: game + 5000);

      var turns = 0;
      while (!match.isFinished && turns < 400) {
        // Сверяем каждую пятую позицию — эталон намеренно медленный.
        if (random.nextInt(5) == 0) {
          compare(match.state);
          positionsChecked++;
        }
        final choice = bot.choose(match.state);
        if (choice == null) {
          match.pass();
        } else {
          match.play(choice);
        }
        turns++;
      }
    }

    expect(positionsChecked, greaterThan(200));
  });

  test('генератор совпадает с эталоном на стартовых бросках', () {
    for (var a = 1; a <= 6; a++) {
      for (var b = a; b <= 6; b++) {
        for (final first in Player.values) {
          compare(GameState.initial(first: first, roll: DiceRoll(a, b)));
        }
      }
    }
  });

  test('генератор совпадает с эталоном в позициях выброса', () {
    final random = Random(7);
    for (var i = 0; i < 200; i++) {
      final white = <int, int>{};
      var left = 15;
      final borneOff = random.nextInt(10);
      left -= borneOff;
      while (left > 0) {
        final abs = 1 + random.nextInt(6);
        final take = 1 + random.nextInt(left);
        white[abs] = (white[abs] ?? 0) + take;
        left -= take;
      }
      final state = position(
        turn: Player.white,
        roll: DiceRoll(1 + random.nextInt(6), 1 + random.nextInt(6)),
        white: white,
        black: <int, int>{13: 15},
        whiteBorneOff: borneOff,
      );
      compare(state);
    }
  });
}

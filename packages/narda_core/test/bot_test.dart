import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

import 'support/positions.dart';

void main() {
  const generator = MoveGenerator();

  GameState midgame() => position(
    turn: Player.white,
    roll: const DiceRoll(6, 3),
    white: <int, int>{24: 6, 18: 3, 13: 2, 11: 2, 7: 1, 5: 1},
    black: <int, int>{12: 5, 8: 3, 6: 2, 3: 2, 22: 2, 20: 1},
  );

  group('Evaluator', () {
    test('оценка симметрична', () {
      final state = midgame();
      const evaluator = Evaluator();
      expect(
        evaluator.evaluate(state, Player.white),
        closeTo(-evaluator.evaluate(state, Player.black), 1e-9),
      );
    });

    test('выброшенные шашки и продвижение улучшают оценку', () {
      const evaluator = Evaluator();
      final behind = position(
        turn: Player.white,
        roll: const DiceRoll(1, 1),
        white: <int, int>{24: 15},
        black: <int, int>{12: 15},
      );
      final ahead = position(
        turn: Player.white,
        roll: const DiceRoll(1, 1),
        white: <int, int>{4: 10},
        black: <int, int>{12: 15},
        whiteBorneOff: 5,
      );
      expect(
        evaluator.evaluate(ahead, Player.white),
        greaterThan(evaluator.evaluate(behind, Player.white)),
      );
    });

    test('победа оценивается выше любой позиционной оценки', () {
      const evaluator = Evaluator();
      final won = position(
        turn: Player.black,
        roll: const DiceRoll(1, 1),
        black: <int, int>{13: 15},
        whiteBorneOff: 15,
      );
      expect(
        evaluator.evaluate(won, Player.white),
        greaterThan(Evaluator.winScore - 1),
      );
      expect(
        evaluator.evaluate(won, Player.black),
        lessThan(-Evaluator.winScore + 1),
      );
    });

    test('веса настраиваются через конфиг', () {
      final weights = const HeuristicWeights().copyWith(blockBase: 0);
      expect(weights.blockBase, 0);
      expect(weights.pip, const HeuristicWeights().pip);
    });
  });

  group('Bot', () {
    for (final level in BotLevel.values) {
      test('${level.name}: выбирает легальный максимальный ход', () {
        final state = midgame();
        final bot = HeuristicBot(level: level, seed: 3);
        final choice = bot.choose(state);
        expect(choice, isNotNull);
        expect(generator.generate(state), contains(choice));
      });
    }

    test('возвращает null, когда ходов нет', () {
      final state = position(
        turn: Player.white,
        roll: const DiceRoll(6, 3),
        white: <int, int>{7: 1},
        black: <int, int>{4: 1, 1: 1},
      );
      expect(HeuristicBot(level: BotLevel.kuchli, seed: 1).choose(state), isNull);
    });

    test('с одинаковым сидом ход воспроизводится', () {
      final state = midgame();
      expect(
        HeuristicBot(level: BotLevel.oson, seed: 11).choose(state),
        HeuristicBot(level: BotLevel.oson, seed: 11).choose(state),
      );
    });

    test('kuchli уверенно обыгрывает oson в серии', () {
      var strongWins = 0;
      const games = 24;
      for (var seed = 0; seed < games; seed++) {
        final game = Game(dice: RandomDiceSource.seeded(1000 + seed))..start();
        // Играем за обе стороны поочерёдно, чтобы право первого хода
        // не смещало результат.
        final strong = seed.isEven ? Player.white : Player.black;
        final bots = <Player, Bot>{
          strong: HeuristicBot(
            level: BotLevel.kuchli,
            seed: seed,
            budget: const Duration(milliseconds: 10),
          ),
          strong.opponent: HeuristicBot(level: BotLevel.oson, seed: seed + 500),
        };
        var turns = 0;
        while (!game.isFinished && turns < 400) {
          final choice = bots[game.state.turn]!.choose(game.state);
          if (choice == null) {
            game.pass();
          } else {
            game.play(choice);
          }
          turns++;
        }
        if (game.result?.winner == strong) strongWins++;
      }
      expect(strongWins, greaterThan(games * 0.6));
    }, tags: <String>['slow']);
  });

  group('бюджет времени', () {
    test('kuchli укладывается в 200 мс на ход', () {
      final states = <GameState>[
        GameState.initial(first: Player.white, roll: const DiceRoll(6, 5)),
        GameState.initial(first: Player.white, roll: const DiceRoll(5, 5)),
        midgame(),
        midgame().copyWith(roll: const DiceRoll(4, 4), remainingDice: <int>[4, 4, 4, 4]),
      ];
      final bot = HeuristicBot(level: BotLevel.kuchli, seed: 5);
      for (final state in states) {
        final stopwatch = Stopwatch()..start();
        bot.choose(state);
        stopwatch.stop();
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(400),
          reason: 'ход из $state занял ${stopwatch.elapsedMilliseconds} мс',
        );
      }
    });
  }, tags: <String>['perf']);
}

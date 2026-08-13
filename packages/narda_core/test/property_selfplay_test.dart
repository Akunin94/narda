import 'dart:io';

import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

/// Property-тесты: массовые партии бот-против-бота с проверкой инвариантов
/// после каждого полухода (§5, P1).
///
/// По умолчанию прогоняются 10 000 партий. Уменьшить объём можно переменной
/// окружения `NARDA_PROPERTY_GAMES` (например, `NARDA_PROPERTY_GAMES=200`).
void main() {
  const generator = MoveGenerator();
  const maxTurnsPerGame = 400;

  final requested = Platform.environment['NARDA_PROPERTY_GAMES'];
  final games = requested == null ? 10000 : int.parse(requested);

  /// Прогоняет партию и валидирует каждый шаг. Возвращает число ходов.
  int playAndCheck(int seed, Bot Function(int seed) makeBot) {
    final game = Game(dice: RandomDiceSource.seeded(seed))..start();
    final bots = <Player, Bot>{
      Player.white: makeBot(seed * 2 + 1),
      Player.black: makeBot(seed * 2 + 2),
    };

    var turns = 0;
    var previousPips = <Player, int>{
      Player.white: game.state.pipCount(Player.white),
      Player.black: game.state.pipCount(Player.black),
    };

    while (!game.isFinished && turns < maxTurnsPerGame) {
      final before = game.state;
      expect(
        before.validate(),
        isEmpty,
        reason: 'seed $seed, yurish $turns: ${before.encode()}',
      );
      expect(
        Rules.createsIllegalBlock(before, before.turn),
        isFalse,
        reason: 'нелегальный блок: seed $seed, ${before.encode()}',
      );

      final options = generator.generate(before);
      final choice = bots[before.turn]!.choose(before);

      if (choice == null) {
        expect(options, isEmpty, reason: 'бот спасовал при наличии ходов');
        game.pass();
        turns++;
        continue;
      }

      // Ход обязан быть максимальным и целиком легальным по шагам.
      expect(options, contains(choice));
      expect(
        choice.length,
        options.map((MoveSequence s) => s.length).reduce(
          (int a, int b) => a > b ? a : b,
        ),
        reason: 'ход короче максимального: seed $seed',
      );
      expect(
        choice.headMoves,
        lessThanOrEqualTo(Rules.headLimit(before)),
        reason: 'снято лишнее с головы: seed $seed, ${before.encode()}',
      );

      var step = before;
      for (final move in choice.moves) {
        expect(
          Rules.isLegalSingle(step, move),
          isTrue,
          reason: 'нелегальное перемещение $move: ${step.encode()}',
        );
        step = step.applyMove(move);
        expect(
          Rules.createsIllegalBlock(step, before.turn),
          isFalse,
          reason: 'ход построил глухой забор: seed $seed',
        );
      }

      game.play(choice);
      turns++;

      final after = game.state;
      for (final player in Player.values) {
        expect(
          after.pipCount(player),
          lessThanOrEqualTo(previousPips[player]!),
          reason: 'pip вырос у ${player.name}: seed $seed',
        );
      }
      previousPips = <Player, int>{
        Player.white: after.pipCount(Player.white),
        Player.black: after.pipCount(Player.black),
      };
    }

    expect(
      game.isFinished,
      isTrue,
      reason: 'партия seed $seed не завершилась за $maxTurnsPerGame ходов',
    );
    final result = game.result!;
    expect(game.state.borneOff(result.winner), 15);
    expect(result.points, result.isMars ? 2 : 1);
    return turns;
  }

  test('$games случайных партий бот-против-бота проходят все инварианты', () {
    var totalTurns = 0;
    for (var seed = 0; seed < games; seed++) {
      totalTurns += playAndCheck(seed, (int s) => RandomBot(seed: s));
    }
    expect(totalTurns / games, greaterThan(20));
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('партии эвристического бота проходят те же инварианты', () {
    for (var seed = 0; seed < 40; seed++) {
      playAndCheck(
        seed + 90000,
        (int s) => HeuristicBot(
          level: BotLevel.values[s % BotLevel.values.length],
          seed: s,
          budget: const Duration(milliseconds: 10),
        ),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

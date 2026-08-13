import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

import 'support/positions.dart';

void main() {
  GameState finished({required int loserBorneOff}) => position(
    turn: Player.black,
    roll: const DiceRoll(1, 1),
    black: <int, int>{13: 15 - loserBorneOff},
    whiteBorneOff: 15,
    blackBorneOff: loserBorneOff,
  );

  group('итог партии', () {
    test('обычная победа — одно очко', () {
      final result = GameResult.fromState(finished(loserBorneOff: 3));
      expect(result.winner, Player.white);
      expect(result.isMars, isFalse);
      expect(result.points, 1);
    });

    test('марс — два очка, если соперник не выбросил ни одной', () {
      final result = GameResult.fromState(finished(loserBorneOff: 0));
      expect(result.isMars, isTrue);
      expect(result.points, 2);
    });

    test('незавершённая партия не даёт результата', () {
      expect(
        () => GameResult.fromState(
          GameState.initial(first: Player.white, roll: const DiceRoll(2, 1)),
        ),
        throwsStateError,
      );
    });

    test('сдача даёт сопернику очко, при нуле выброшенных — два', () {
      final middle = position(
        turn: Player.white,
        roll: const DiceRoll(2, 1),
        white: <int, int>{4: 13},
        black: <int, int>{13: 15},
        whiteBorneOff: 2,
      );
      final resignedWithCheckers = GameResult.resignation(
        resigning: Player.white,
        state: middle,
      );
      expect(resignedWithCheckers.winner, Player.black);
      expect(resignedWithCheckers.points, 1);
      expect(resignedWithCheckers.byResignation, isTrue);

      final resignedClean = GameResult.resignation(
        resigning: Player.black,
        state: middle,
      );
      expect(resignedClean.winner, Player.white);
      expect(resignedClean.isMars, isTrue);
      expect(resignedClean.points, 2);
    });

    test('Game.resign завершает партию', () {
      final game = Game(dice: RandomDiceSource.seeded(7))..start();
      game.resign(Player.white);
      expect(game.isFinished, isTrue);
      expect(game.result!.winner, Player.black);
      expect(game.result!.points, 2);
      expect(() => game.resign(Player.black), throwsStateError);
    });
  });

  group('счёт матча', () {
    test('серия до 3 очков закрывается марсом плюс победой', () {
      var score = const MatchScore(target: MatchTarget.to3);
      expect(score.isOver, isFalse);

      score = score.add(
        const GameResult(winner: Player.white, isMars: true),
      );
      expect(score.white, 2);
      expect(score.isOver, isFalse);

      score = score.add(
        const GameResult(winner: Player.white, isMars: false),
      );
      expect(score.white, 3);
      expect(score.isOver, isTrue);
      expect(score.winner, Player.white);
      expect(score.gamesPlayed, 2);
    });

    test('одиночная партия завершает матч сразу', () {
      final score = const MatchScore(
        target: MatchTarget.single,
      ).add(const GameResult(winner: Player.black, isMars: false));
      expect(score.isOver, isTrue);
      expect(score.winner, Player.black);
    });

    test('цели матча — 1 / 3 / 5 / 7 очков', () {
      expect(
        MatchTarget.values.map((MatchTarget t) => t.points),
        <int>[1, 3, 5, 7],
      );
    });
  });
}

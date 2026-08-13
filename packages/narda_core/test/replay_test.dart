import 'dart:math';

import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

/// Играет партию бот-против-бота и попутно ведёт журнал.
({GameLog log, GameState finalState, GameResult result}) selfPlay(int seed) {
  final dice = RandomDiceSource.seeded(seed);
  final bot = HeuristicBot(level: BotLevel.oson, seed: seed);
  final game = Game(dice: dice)..start();
  final turns = <LoggedTurn>[];
  final first = game.state.turn;

  var guard = 0;
  while (!game.isFinished && guard++ < 4000) {
    final roll = game.state.roll;
    final sequence = bot.choose(game.state);
    if (sequence == null) {
      turns.add(LoggedTurn(roll: roll, moves: const <int>[]));
      game.pass();
    } else {
      turns.add(LoggedTurn.sequence(roll: roll, sequence: sequence));
      game.play(sequence);
    }
  }

  return (
    log: GameLog(first: first, turns: turns),
    finalState: game.state,
    result: game.result!,
  );
}

void main() {
  test('кодирование хода переживает обратный разбор', () {
    final sequence = MoveSequence(<Move>[
      Move.point(player: Player.white, fromAbs: 24, die: 6),
      Move.bearOff(player: Player.white, fromAbs: 3, die: 5),
    ]);
    final flat = encodeMoves(sequence);

    expect(flat, <int>[24, 6, 3, 5]);
    expect(decodeMoves(Player.white, flat), sequence);
  });

  test('разбор отвергает пункты и числа вне доски', () {
    expect(
      () => decodeMoves(Player.white, <int>[25, 3]),
      throwsFormatException,
    );
    expect(() => decodeMoves(Player.white, <int>[24, 7]), throwsFormatException);
    expect(() => decodeMoves(Player.white, <int>[24]), throwsFormatException);
  });

  test('реплей журнала повторяет позицию партии', () {
    for (var seed = 1; seed <= 20; seed++) {
      final played = selfPlay(seed);
      final replay = replayGame(played.log);

      expect(replay.isLegal, isTrue, reason: 'сид $seed');
      expect(replay.isFinished, isTrue, reason: 'сид $seed');
      expect(replay.state.points, played.finalState.points, reason: 'сид $seed');
      expect(replay.state.whiteBorneOff, played.finalState.whiteBorneOff);
      expect(replay.state.blackBorneOff, played.finalState.blackBorneOff);
      expect(replay.result!.winner, played.result.winner, reason: 'сид $seed');
      expect(replay.result!.isMars, played.result.isMars, reason: 'сид $seed');
    }
  });

  test('реплей неполного журнала отдаёт позицию и очередь хода', () {
    final played = selfPlay(7);
    final head = played.log.turns.take(9).toList();
    final replay = replayGame(GameLog(first: played.log.first, turns: head));

    expect(replay.isLegal, isTrue);
    expect(replay.isFinished, isFalse);
    expect(replay.state.validate(), isEmpty);
    // Ход возвращается тому, кто начинал: девять ходов — нечётное число.
    expect(replay.state.turn, played.log.first.opponent);
  });

  test('подменённый ход в журнале ловится и указывает свой индекс', () {
    final played = selfPlay(3);
    final turns = played.log.turns.take(6).toList();
    // Шашка «улетает» с пустого пункта — правилами такой ход не порождается.
    turns[4] = LoggedTurn(roll: turns[4].roll, moves: <int>[7, turns[4].roll.a]);
    final replay = replayGame(GameLog(first: played.log.first, turns: turns));

    expect(replay.illegalTurn, 4);
    expect(replay.isLegal, isFalse);
  });

  test('пустой ход в журнале — пропуск, даже если перемещения были', () {
    final played = selfPlay(11);
    final turns = played.log.turns.take(5).toList();
    final skipped = LoggedTurn(roll: turns[3].roll, moves: const <int>[]);
    turns[3] = skipped;
    final replay = replayGame(GameLog(first: played.log.first, turns: turns));

    expect(replay.isLegal, isTrue, reason: 'автопас по таймеру легален');
    expect(replay.state.validate(), isEmpty);
  });

  test('журнал без ходов — стартовая расстановка', () {
    final replay = replayGame(GameLog(first: Player.black));

    expect(replay.state.turn, Player.black);
    expect(replay.state.checkersAt(Player.white, Coords.headAbs(Player.white)), 15);
    expect(replay.state.checkersAt(Player.black, Coords.headAbs(Player.black)), 15);
    expect(replay.isLegal, isTrue);
    expect(replay.isFinished, isFalse);
  });

  test('мусор в журнале не роняет реплей', () {
    final random = Random(5);
    for (var attempt = 0; attempt < 50; attempt++) {
      final turns = <LoggedTurn>[
        for (var i = 0; i < 4; i++)
          LoggedTurn(
            roll: DiceRoll(random.nextInt(6) + 1, random.nextInt(6) + 1),
            moves: <int>[
              for (var m = 0; m < random.nextInt(5); m++) random.nextInt(40) - 5,
            ],
          ),
      ];
      final replay = replayGame(GameLog(first: Player.white, turns: turns));

      expect(replay.state.validate(), isEmpty, reason: 'попытка $attempt');
    }
  });
}

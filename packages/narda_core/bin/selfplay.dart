// Консольный раннер: прогоняет партию бот-против-бота и печатает доску
// в ASCII. Запуск:
//   dart run narda_core:selfplay --seed=42 --level=kuchli
//   dart run narda_core:selfplay --games=100 --quiet
import 'dart:io';

import 'package:narda_core/narda_core.dart';

void main(List<String> args) {
  final options = _Options.parse(args);
  if (options.help) {
    stdout.writeln(_Options.usage);
    return;
  }

  // С `--quiet` (и всегда на серии партий) ход партии не печатается —
  // остаётся только итоговая сводка.
  void log(String message) {
    if (!options.quiet) stdout.writeln(message);
  }

  var whiteWins = 0;
  var marses = 0;
  var totalTurns = 0;
  var longestMoveMs = 0;

  for (var game = 0; game < options.games; game++) {
    final seed = options.seed + game;
    final match = Game(dice: RandomDiceSource.seeded(seed));
    final bots = <Player, Bot>{
      Player.white: _makeBot(options.whiteLevel, seed * 2 + 1),
      Player.black: _makeBot(options.blackLevel, seed * 2 + 2),
    };

    final opening = match.start();
    log('=== o\'yin ${game + 1}, seed $seed ===');
    log('birinchi yurish: $opening');
    log(AsciiBoard.render(match.state));

    var turns = 0;
    while (!match.isFinished && turns < options.maxTurns) {
      final state = match.state;
      final stopwatch = Stopwatch()..start();
      final choice = bots[state.turn]!.choose(state);
      stopwatch.stop();
      if (stopwatch.elapsedMilliseconds > longestMoveMs) {
        longestMoveMs = stopwatch.elapsedMilliseconds;
      }

      log('${state.turn.name} ${state.roll}: ${choice ?? "yurish yo'q"}');
      if (choice == null) {
        match.pass();
      } else {
        match.play(choice);
      }
      turns++;
      log(AsciiBoard.render(match.state));
    }

    totalTurns += turns;
    final result = match.result;
    if (result == null) {
      stderr.writeln('o\'yin ${game + 1}: tugamadi ($turns yurish)');
      exitCode = 1;
      continue;
    }
    if (result.winner == Player.white) whiteWins++;
    if (result.isMars) marses++;
    if (!options.quiet || options.games == 1) {
      stdout.writeln("g'olib: $result ($turns yurish)");
    }
  }

  stdout.writeln(
    'o\'yinlar: ${options.games}, w/b: $whiteWins/${options.games - whiteWins}, '
    'mars: $marses, o\'rtacha yurish: '
    '${(totalTurns / options.games).toStringAsFixed(1)}, '
    'eng uzun yurish: $longestMoveMs ms',
  );
}

Bot _makeBot(BotLevel level, int seed) =>
    HeuristicBot(level: level, seed: seed);

class _Options {
  _Options({
    required this.seed,
    required this.games,
    required this.quiet,
    required this.maxTurns,
    required this.whiteLevel,
    required this.blackLevel,
    required this.help,
  });

  static const String usage =
      'dart run narda_core:selfplay [--seed=N] [--games=N] [--quiet] '
      '[--level=oson|orta|kuchli] [--white=LEVEL] [--black=LEVEL] '
      '[--max-turns=N]';

  final int seed;
  final int games;
  final bool quiet;
  final int maxTurns;
  final BotLevel whiteLevel;
  final BotLevel blackLevel;
  final bool help;

  static _Options parse(List<String> args) {
    var seed = 1;
    var games = 1;
    var quiet = false;
    var maxTurns = 400;
    var level = BotLevel.orta;
    BotLevel? white;
    BotLevel? black;
    var help = false;

    for (final arg in args) {
      final parts = arg.split('=');
      switch (parts.first) {
        case '--seed':
          seed = int.parse(parts[1]);
        case '--games':
          games = int.parse(parts[1]);
        case '--quiet':
          quiet = true;
        case '--max-turns':
          maxTurns = int.parse(parts[1]);
        case '--level':
          level = _level(parts[1]);
        case '--white':
          white = _level(parts[1]);
        case '--black':
          black = _level(parts[1]);
        case '--help':
        case '-h':
          help = true;
        default:
          throw ArgumentError('Unknown option: $arg\n$usage');
      }
    }

    return _Options(
      seed: seed,
      games: games,
      quiet: quiet || games > 1,
      maxTurns: maxTurns,
      whiteLevel: white ?? level,
      blackLevel: black ?? level,
      help: help,
    );
  }

  static BotLevel _level(String name) => BotLevel.values.firstWhere(
    (BotLevel value) => value.name == name,
    orElse: () => throw ArgumentError('Unknown level: $name'),
  );
}

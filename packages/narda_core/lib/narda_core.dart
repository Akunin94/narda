/// Ядро игры «Uzun narda» — длинные нарды.
///
/// Чистый Dart без единого импорта Flutter: состояние, правила, генератор
/// максимальных ходов и бот. Правила реализованы по спецификации §3:
/// битья нет, бара нет, куба удвоения нет.
library;

export 'src/bot/bot.dart';
export 'src/bot/evaluator.dart';
export 'src/bot/heuristic_bot.dart';
export 'src/bot/heuristic_weights.dart';
export 'src/coords.dart';
export 'src/dice.dart';
export 'src/game.dart';
export 'src/game_state.dart';
export 'src/move.dart';
export 'src/move_generator.dart';
export 'src/player.dart';
export 'src/result.dart';
export 'src/rules.dart';
export 'src/util/ascii_board.dart';

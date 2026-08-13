import 'dart:math';

import '../game_state.dart';
import '../move.dart';
import '../move_generator.dart';

/// Уровни сложности (§4).
enum BotLevel {
  /// Oson — случайный ход из лучшей половины.
  oson,

  /// O'rta — лучший ход с шумом.
  orta,

  /// Kuchli — лучший ход, при наличии времени с перебором на 2 полухода.
  kuchli,
}

/// Выбор хода за игрока, чья сейчас очередь.
abstract interface class Bot {
  /// Возвращает выбранный максимальный ход или `null`, если ходов нет.
  MoveSequence? choose(GameState state);
}

/// Равновероятный выбор из максимальных ходов. Нужен для property-тестов
/// и как эталон слабой игры.
class RandomBot implements Bot {
  RandomBot({int? seed, MoveGenerator generator = const MoveGenerator()})
    : _random = seed == null ? Random() : Random(seed),
      _generator = generator;

  final Random _random;
  final MoveGenerator _generator;

  @override
  MoveSequence? choose(GameState state) {
    final options = _generator.generate(state);
    if (options.isEmpty) return null;
    return options[_random.nextInt(options.length)];
  }
}

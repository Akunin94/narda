import 'dart:math';

/// Бросок двух кубиков.
class DiceRoll {
  const DiceRoll(this.a, this.b)
    : assert(a >= 1 && a <= 6),
      assert(b >= 1 && b <= 6);

  final int a;
  final int b;

  bool get isDouble => a == b;

  int get high => a >= b ? a : b;

  int get low => a >= b ? b : a;

  /// Числа, доступные к розыгрышу: два числа обычного броска
  /// или четыре одинаковых при дубле. Порядок — по убыванию.
  List<int> toRemaining() => isDouble ? <int>[a, a, a, a] : <int>[high, low];

  @override
  bool operator ==(Object other) =>
      other is DiceRoll && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);

  @override
  String toString() => '$a-$b';
}

/// Источник костей. Точка замены для серверных костей в P4
/// (см. §6: «в код заложи точку замены DiceSource»).
abstract interface class DiceSource {
  /// Бросок двух кубиков.
  DiceRoll roll();

  /// Бросок одного кубика (нужен для определения первого хода, §3.2.1).
  int rollOne();
}

/// Источник на псевдослучайном генераторе. С сидом — воспроизводимый.
class RandomDiceSource implements DiceSource {
  RandomDiceSource([Random? random]) : _random = random ?? Random();

  RandomDiceSource.seeded(int seed) : _random = Random(seed);

  final Random _random;

  @override
  int rollOne() => _random.nextInt(6) + 1;

  @override
  DiceRoll roll() => DiceRoll(rollOne(), rollOne());
}

/// Заранее заданная последовательность бросков — для тестов и реплеев.
class ScriptedDiceSource implements DiceSource {
  ScriptedDiceSource(this.singles, this.rolls);

  ScriptedDiceSource.rolls(List<DiceRoll> rolls) : this(const <int>[], rolls);

  final List<int> singles;
  final List<DiceRoll> rolls;

  int _singleIndex = 0;
  int _rollIndex = 0;

  @override
  int rollOne() {
    if (_singleIndex >= singles.length) {
      throw StateError('ScriptedDiceSource: single rolls exhausted');
    }
    return singles[_singleIndex++];
  }

  @override
  DiceRoll roll() {
    if (_rollIndex >= rolls.length) {
      throw StateError('ScriptedDiceSource: rolls exhausted');
    }
    return rolls[_rollIndex++];
  }
}

/// Исход броска с вероятностью — для перебора ожиданий ботом (2-ply).
class DiceOutcome {
  const DiceOutcome(this.roll, this.probability);

  final DiceRoll roll;
  final double probability;
}

/// Все 21 различимый исход броска двух кубиков с вероятностями
/// (дубль — 1/36, остальные — 2/36).
final List<DiceOutcome> allDiceOutcomes = List<DiceOutcome>.unmodifiable(<
  DiceOutcome
>[
  for (var a = 1; a <= 6; a++)
    for (var b = a; b <= 6; b++) DiceOutcome(DiceRoll(a, b), a == b ? 1 / 36 : 2 / 36),
]);

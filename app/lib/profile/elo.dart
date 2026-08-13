import 'dart:math' as math;

/// Рейтинг Elo (§P5).
///
/// Файл намеренно без единого импорта Flutter — это чистая арифметика, её
/// проверяют юнит-тесты. В `narda_core` рейтинг не переехал: там по §2 живут
/// только правила игры и бот.
class EloConfig {
  const EloConfig({
    this.start = 1200,
    this.newcomerGames = 15,
    this.newcomerK = 40,
    this.k = 32,
    this.masterRating = 2000,
    this.masterK = 20,
    this.floor = 100,
  });

  /// Рейтинг игрока, не сыгравшего ни одного рейтингового матча.
  final int start;

  /// Сколько матчей новичок считается новичком: его рейтинг двигается быстрее.
  final int newcomerGames;
  final int newcomerK;

  /// Обычный коэффициент.
  final int k;

  /// С этого рейтинга коэффициент падает — верхушка таблицы стоит устойчиво.
  final int masterRating;
  final int masterK;

  /// Ниже этого рейтинг не опускается.
  final int floor;
}

const EloConfig defaultElo = EloConfig();

/// Стартовый рейтинг: он же подставляется сопернику, о котором ничего не знаем.
const int eloStartRating = 1200;

/// Ожидаемый результат игрока против соперника: 0.5 при равных рейтингах.
double eloExpected({required int rating, required int opponentRating}) =>
    1 / (1 + math.pow(10, (opponentRating - rating) / 400));

/// Коэффициент K: у новичка выше, у верхушки таблицы ниже.
int eloK({
  required int rating,
  required int ratedGames,
  EloConfig config = defaultElo,
}) {
  if (ratedGames < config.newcomerGames) return config.newcomerK;
  return rating >= config.masterRating ? config.masterK : config.k;
}

/// Новый рейтинг после матча. Считается по итогу матча целиком (§3.4:
/// одиночная партия или серия до 3 / 5 / 7), а не по каждой партии серии.
int eloUpdated({
  required int rating,
  required int opponentRating,
  required bool won,
  required int ratedGames,
  EloConfig config = defaultElo,
}) {
  final double expected = eloExpected(
    rating: rating,
    opponentRating: opponentRating,
  );
  final int k = eloK(rating: rating, ratedGames: ratedGames, config: config);
  final int next = (rating + k * ((won ? 1 : 0) - expected)).round();
  return math.max(config.floor, next);
}

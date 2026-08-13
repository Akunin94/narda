/// Веса эвристики бота. Вынесены в конфиг, чтобы подбирать их отдельно
/// от кода оценки (§4).
class HeuristicWeights {
  const HeuristicWeights({
    this.pip = 1.0,
    this.borneOff = 10.0,
    this.blockBase = 2.0,
    this.intercept = 4.0,
    this.headCheckers = 0.5,
    this.stack = 1.5,
    this.homeCoverage = 2.0,
    this.bearOffReady = 10.0,
  });

  /// Вес суммарного pip-прогресса (расстояния до выброса).
  final double pip;

  /// Бонус за каждую выброшенную шашку.
  final double borneOff;

  /// База ценности блока: `blockBase * (длина - 1)^2`.
  final double blockBase;

  /// Бонус за каждый занятый пункт в зоне перехвата — на пути выхода
  /// соперника с головы (абс. 9–11 против чёрных, 21–23 против белых).
  final double intercept;

  /// Штраф за каждую шашку, оставшуюся на голове (раннее развитие).
  final double headCheckers;

  /// Штраф за каждую шашку сверх четырёх на одном пункте («свечка»).
  final double stack;

  /// Бонус за каждый занятый пункт дома (равномерное заполнение к выбросу).
  final double homeCoverage;

  /// Бонус за готовность к выбросу — все шашки в доме.
  final double bearOffReady;

  HeuristicWeights copyWith({
    double? pip,
    double? borneOff,
    double? blockBase,
    double? intercept,
    double? headCheckers,
    double? stack,
    double? homeCoverage,
    double? bearOffReady,
  }) => HeuristicWeights(
    pip: pip ?? this.pip,
    borneOff: borneOff ?? this.borneOff,
    blockBase: blockBase ?? this.blockBase,
    intercept: intercept ?? this.intercept,
    headCheckers: headCheckers ?? this.headCheckers,
    stack: stack ?? this.stack,
    homeCoverage: homeCoverage ?? this.homeCoverage,
    bearOffReady: bearOffReady ?? this.bearOffReady,
  );
}

import 'dart:math';

import '../dice.dart';
import '../game_state.dart';
import '../move.dart';
import '../move_generator.dart';
import '../player.dart';
import 'bot.dart';
import 'evaluator.dart';
import 'heuristic_weights.dart';

/// Бот на полном генераторе легальных последовательностей: каждый ход
/// оценивается эвристикой, выбирается лучший по уровню сложности.
/// Будущие кости не подсматриваются — Kuchli считает математическое ожидание
/// по всем 21 исходу броска соперника.
class HeuristicBot implements Bot {
  HeuristicBot({
    required this.level,
    HeuristicWeights weights = const HeuristicWeights(),
    MoveGenerator generator = const MoveGenerator(),
    int? seed,
    this.budget = const Duration(milliseconds: 200),
    this.twoPlyCandidates = 4,
  }) : _evaluator = Evaluator(weights),
       _generator = generator,
       _random = seed == null ? Random() : Random(seed);

  final BotLevel level;
  final Evaluator _evaluator;
  final MoveGenerator _generator;
  final Random _random;

  /// Бюджет времени на ход для 2-ply перебора.
  final Duration budget;

  /// Сколько лучших ходов уточнять на втором полуходе.
  final int twoPlyCandidates;

  /// Доля разброса оценок, используемая как амплитуда шума на уровне O'rta.
  static const double _noiseFraction = 0.15;

  @override
  MoveSequence? choose(GameState state) {
    final options = _generator.generate(state);
    if (options.isEmpty) return null;
    if (options.length == 1) return options.first;

    final scores = List<double>.generate(
      options.length,
      (int i) => _evaluator.evaluate(state.applySequence(options[i]), state.turn),
      growable: false,
    );

    switch (level) {
      case BotLevel.oson:
        return _randomFromTopHalf(options, scores);
      case BotLevel.orta:
        return _bestWithNoise(options, scores);
      case BotLevel.kuchli:
        return _bestTwoPly(state, options, scores);
    }
  }

  MoveSequence _randomFromTopHalf(
    List<MoveSequence> options,
    List<double> scores,
  ) {
    final order = _orderByScore(scores);
    final take = max(1, (order.length / 2).ceil());
    return options[order[_random.nextInt(take)]];
  }

  MoveSequence _bestWithNoise(
    List<MoveSequence> options,
    List<double> scores,
  ) {
    var lowest = scores.first;
    var highest = scores.first;
    for (final score in scores) {
      if (score < lowest) lowest = score;
      if (score > highest) highest = score;
    }
    final amplitude = (highest - lowest) * _noiseFraction;
    var bestIndex = 0;
    var bestScore = double.negativeInfinity;
    for (var i = 0; i < options.length; i++) {
      final noisy = scores[i] + (_random.nextDouble() - 0.5) * 2 * amplitude;
      if (noisy > bestScore) {
        bestScore = noisy;
        bestIndex = i;
      }
    }
    return options[bestIndex];
  }

  MoveSequence _bestTwoPly(
    GameState state,
    List<MoveSequence> options,
    List<double> scores,
  ) {
    final order = _orderByScore(scores);
    final candidates = order.take(max(1, twoPlyCandidates)).toList();
    final stopwatch = Stopwatch()..start();

    var bestIndex = candidates.first;
    var bestScore = double.negativeInfinity;
    for (final index in candidates) {
      final expected = _expectedAfter(
        state.applySequence(options[index]),
        state.turn,
        stopwatch,
      );
      final score = expected ?? scores[index];
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
      if (stopwatch.elapsed >= budget) break;
    }
    return options[bestIndex];
  }

  /// Ожидаемая оценка позиции после ответа соперника. Возвращает `null`,
  /// если бюджет времени исчерпан ещё до первого исхода.
  double? _expectedAfter(
    GameState afterOurMove,
    Player forWhom,
    Stopwatch stopwatch,
  ) {
    if (afterOurMove.isFinished) {
      return _evaluator.evaluate(afterOurMove, forWhom);
    }
    var weight = 0.0;
    var total = 0.0;
    for (final outcome in allDiceOutcomes) {
      if (stopwatch.elapsed >= budget) break;
      final next = afterOurMove.nextTurn(outcome.roll);
      final replies = _generator.generate(next);
      var worst = double.infinity;
      if (replies.isEmpty) {
        worst = _evaluator.evaluate(next, forWhom);
      } else {
        for (final reply in replies) {
          final value = _evaluator.evaluate(
            next.applySequence(reply),
            forWhom,
          );
          if (value < worst) worst = value;
        }
      }
      total += outcome.probability * worst;
      weight += outcome.probability;
    }
    if (weight == 0) return null;
    return total / weight;
  }

  /// Индексы ходов, отсортированные по убыванию оценки.
  List<int> _orderByScore(List<double> scores) {
    final order = List<int>.generate(scores.length, (int i) => i);
    order.sort((int a, int b) => scores[b].compareTo(scores[a]));
    return order;
  }
}

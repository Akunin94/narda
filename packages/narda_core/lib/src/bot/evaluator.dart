import '../coords.dart';
import '../game_state.dart';
import '../player.dart';
import 'heuristic_weights.dart';

/// Оценка позиции. Симметрична: `evaluate(s, p) == -evaluate(s, p.opponent)`.
/// Больше — лучше для игрока, от лица которого считаем.
class Evaluator {
  const Evaluator([this.weights = const HeuristicWeights()]);

  final HeuristicWeights weights;

  /// Оценка выигранной партии — заведомо больше любой позиционной.
  static const double winScore = 100000;

  /// Зона перехвата: пункты, которые соперник проходит сразу после головы.
  /// Против чёрных — абс. 9–11, против белых — абс. 21–23.
  static List<int> interceptZone(Player against) =>
      against == Player.black ? const <int>[9, 10, 11] : const <int>[21, 22, 23];

  double evaluate(GameState state, Player forWhom) {
    final winner = state.winner;
    if (winner != null) {
      final mars = state.borneOff(winner.opponent) == 0 ? 1.5 : 1.0;
      return winner == forWhom ? winScore * mars : -winScore * mars;
    }
    return _side(state, forWhom) - _side(state, forWhom.opponent);
  }

  double _side(GameState state, Player player) {
    var score = 0.0;
    score -= weights.pip * state.pipCount(player);
    score += weights.borneOff * state.borneOff(player);
    score -= weights.headCheckers * state.checkersOnHead(player);
    score += _blocks(state, player);
    score += _stacksAndHome(state, player);
    if (state.allInHome(player)) score += weights.bearOffReady;
    return score;
  }

  /// Ценность рядов подряд идущих занятых пунктов. Ряды считаем в собственной
  /// нумерации соперника — именно этот порядок он обязан пройти.
  double _blocks(GameState state, Player player) {
    final opponent = player.opponent;
    var score = 0.0;
    var run = 0;
    for (var own = 1; own <= Coords.pointCount + 1; own++) {
      final occupied =
          own <= Coords.pointCount &&
          state.checkersAt(player, Coords.toAbsolute(opponent, own)) > 0;
      if (occupied) {
        run++;
      } else {
        if (run >= 2) score += weights.blockBase * (run - 1) * (run - 1);
        run = 0;
      }
    }
    for (final abs in interceptZone(opponent)) {
      if (state.checkersAt(player, abs) > 0) score += weights.intercept;
    }
    return score;
  }

  double _stacksAndHome(GameState state, Player player) {
    final head = Coords.headAbs(player);
    var score = 0.0;
    for (var abs = 1; abs <= Coords.pointCount; abs++) {
      final count = state.checkersAt(player, abs);
      if (count == 0) continue;
      if (abs != head && count > 4) score -= weights.stack * (count - 4);
      if (Coords.isHomeAbs(player, abs)) score += weights.homeCoverage;
    }
    return score;
  }
}

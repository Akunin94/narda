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
    score -= _trapped(state, player);
    score += _stacksAndHome(state, player);
    if (state.allInHome(player)) score += weights.bearOffReady;
    return score;
  }

  /// Ценность рядов подряд идущих занятых пунктов. Ряды считаем в собственной
  /// нумерации соперника — именно этот порядок он обязан пройти.
  double _blocks(GameState state, Player player) {
    final opponent = player.opponent;
    // Пункты не дальше самой задней шашки соперника его уже не держат.
    var farthest = 0;
    for (var own = 1; own <= Coords.pointCount; own++) {
      if (state.checkersAt(opponent, Coords.toAbsolute(opponent, own)) > 0) farthest = own;
    }
    var score = 0.0;
    var run = 0;
    for (var own = 1; own <= Coords.pointCount + 1; own++) {
      final occupied =
          own < farthest &&
          state.checkersAt(player, Coords.toAbsolute(opponent, own)) > 0;
      if (occupied) {
        run++;
      } else {
        if (run >= 2) score += weights.blockBase * (run - 1) * (run - 1);
        run = 0;
      }
    }
    for (final abs in interceptZone(opponent)) {
      if (Coords.toOwn(opponent, abs) < farthest && state.checkersAt(player, abs) > 0) {
        score += weights.intercept;
      }
    }
    return score;
  }

  /// Шашки [player], которым ещё предстоит пройти стену соперника из 4+ пунктов.
  /// Своя шашка впереди стены разрешает сопернику достроить её до 6 — штраф выше.
  double _trapped(GameState state, Player player) {
    final opponent = player.opponent;
    var onBoard = 0;
    for (var abs = 1; abs <= Coords.pointCount; abs++) {
      onBoard += state.checkersAt(player, abs);
    }
    final anyPrimeLegal = state.borneOff(player) > 0;
    var score = 0.0;
    var run = 0;
    var behind = 0;
    var trapped = 0;
    var gap = false;
    bool theirs(int own) =>
        own >= 1 && state.checkersAt(opponent, Coords.toAbsolute(player, own)) > 0;
    for (var own = Coords.pointCount; own >= 0; own--) {
      final abs = own == 0 ? null : Coords.toAbsolute(player, own);
      if (abs != null && state.checkersAt(opponent, abs) > 0) {
        if (run == 0) trapped = behind;
        run++;
      } else if (run > 0 && !gap && abs != null && state.checkersAt(player, abs) == 0 && theirs(own - 1)) {
        // Одна пустая дыра в стене — соперник закроет её следующим ходом.
        gap = true;
      } else {
        if (run >= 4) {
          final primeLegal = anyPrimeLegal || onBoard - behind > 0;
          score +=
              (weights.trapped + (primeLegal ? weights.primeThreat : 0)) *
              (run - 3) *
              trapped;
        }
        run = 0;
        gap = false;
      }
      if (abs != null) behind += state.checkersAt(player, abs);
    }
    return score;
  }

  double _stacksAndHome(GameState state, Player player) {
    final head = Coords.headAbs(player);
    var score = 0.0;
    var homePoints = 0;
    var rearmost = 0;
    var inHome = 0;
    var inStart = 0;
    for (var abs = 1; abs <= Coords.pointCount; abs++) {
      final count = state.checkersAt(player, abs);
      if (count == 0) continue;
      if (abs != head && count > 4) score -= weights.stack * (count - 4);
      if (Coords.isHomeAbs(player, abs)) {
        homePoints++;
        inHome += count;
      }
      final own = Coords.toOwn(player, abs);
      if (own > 18) inStart += count;
      if (own > rearmost) rearmost = own;
    }
    score -= weights.earlyHome * inHome * inStart / GameState.checkersPerPlayer;
    // Дом заполняем к выбросу, а не с первых ходов: иначе бот гонит одиночку в конец дома.
    if (rearmost <= Coords.pointCount ~/ 2) score += weights.homeCoverage * homePoints;
    return score;
  }
}

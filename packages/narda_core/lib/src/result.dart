import 'game_state.dart';
import 'player.dart';

/// Формат матча: одиночная партия или серия до 3 / 5 / 7 очков.
enum MatchTarget {
  single(1),
  to3(3),
  to5(5),
  to7(7);

  const MatchTarget(this.points);

  final int points;
}

/// Итог одной партии.
class GameResult {
  const GameResult({
    required this.winner,
    required this.isMars,
    this.byResignation = false,
  });

  /// Итог по завершённому состоянию: марс, если проигравший не выбросил
  /// ни одной шашки.
  factory GameResult.fromState(GameState state) {
    final winner = state.winner;
    if (winner == null) {
      throw StateError('Game is not finished yet');
    }
    return GameResult(
      winner: winner,
      isMars: state.borneOff(winner.opponent) == 0,
    );
  }

  /// Сдача партии: соперник получает 1 очко, а при нуле выброшенных
  /// у сдавшегося — 2 (явный марс).
  factory GameResult.resignation({
    required Player resigning,
    required GameState state,
  }) => GameResult(
    winner: resigning.opponent,
    isMars: state.borneOff(resigning) == 0,
    byResignation: true,
  );

  final Player winner;
  final bool isMars;
  final bool byResignation;

  /// Oyin — 1 очко, mars — 2 очка.
  int get points => isMars ? 2 : 1;

  @override
  String toString() =>
      '${winner.name} +$points${isMars ? ' (mars)' : ''}'
      '${byResignation ? ' (taslim)' : ''}';
}

/// Счёт матча.
class MatchScore {
  const MatchScore({
    required this.target,
    this.white = 0,
    this.black = 0,
    this.gamesPlayed = 0,
  });

  final MatchTarget target;
  final int white;
  final int black;
  final int gamesPlayed;

  int pointsOf(Player player) => player == Player.white ? white : black;

  bool get isOver => white >= target.points || black >= target.points;

  Player? get winner {
    if (white >= target.points) return Player.white;
    if (black >= target.points) return Player.black;
    return null;
  }

  MatchScore add(GameResult result) => MatchScore(
    target: target,
    white: white + (result.winner == Player.white ? result.points : 0),
    black: black + (result.winner == Player.black ? result.points : 0),
    gamesPlayed: gamesPlayed + 1,
  );

  @override
  String toString() => '$white:$black (to ${target.points})';
}

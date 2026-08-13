import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальная статистика игрока: партии, винрейт, марсы (§P3).
///
/// Считаются только партии против бота — в hotseat «своего» игрока нет.
@immutable
class Stats {
  const Stats({
    this.games = 0,
    this.wins = 0,
    this.marsWins = 0,
    this.marsLosses = 0,
    this.matches = 0,
    this.matchWins = 0,
  });

  /// Сыграно партий против бота.
  final int games;

  /// Из них выиграно.
  final int wins;

  /// Побед всухую и поражений всухую.
  final int marsWins;
  final int marsLosses;

  /// Сыгранных и выигранных серий до 3/5/7.
  final int matches;
  final int matchWins;

  int get losses => games - wins;

  /// Доля побед в процентах; 0 при нуле партий.
  int get winRate => games == 0 ? 0 : (wins * 100 / games).round();

  Stats copyWith({
    int? games,
    int? wins,
    int? marsWins,
    int? marsLosses,
    int? matches,
    int? matchWins,
  }) => Stats(
    games: games ?? this.games,
    wins: wins ?? this.wins,
    marsWins: marsWins ?? this.marsWins,
    marsLosses: marsLosses ?? this.marsLosses,
    matches: matches ?? this.matches,
    matchWins: matchWins ?? this.matchWins,
  );
}

/// Хранилище статистики поверх shared_preferences.
class StatsStore extends ChangeNotifier {
  StatsStore._(this._prefs, this._stats);

  /// Без диска — для тестов и превью.
  StatsStore.inMemory([Stats stats = const Stats()]) : this._(null, stats);

  static Future<StatsStore> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return StatsStore._(
      prefs,
      Stats(
        games: prefs.getInt(_keyGames) ?? 0,
        wins: prefs.getInt(_keyWins) ?? 0,
        marsWins: prefs.getInt(_keyMarsWins) ?? 0,
        marsLosses: prefs.getInt(_keyMarsLosses) ?? 0,
        matches: prefs.getInt(_keyMatches) ?? 0,
        matchWins: prefs.getInt(_keyMatchWins) ?? 0,
      ),
    );
  }

  static const String _keyGames = 'stats_games';
  static const String _keyWins = 'stats_wins';
  static const String _keyMarsWins = 'stats_mars_wins';
  static const String _keyMarsLosses = 'stats_mars_losses';
  static const String _keyMatches = 'stats_matches';
  static const String _keyMatchWins = 'stats_match_wins';

  final SharedPreferences? _prefs;
  Stats _stats;

  Stats get stats => _stats;

  /// Записывает итог партии глазами игрока [local].
  void recordGame(GameResult result, {required Player local}) {
    final bool won = result.winner == local;
    _update(
      _stats.copyWith(
        games: _stats.games + 1,
        wins: _stats.wins + (won ? 1 : 0),
        marsWins: _stats.marsWins + (won && result.isMars ? 1 : 0),
        marsLosses: _stats.marsLosses + (!won && result.isMars ? 1 : 0),
      ),
    );
  }

  /// Записывает итог серии до 3/5/7.
  void recordMatch({required bool won}) => _update(
    _stats.copyWith(
      matches: _stats.matches + 1,
      matchWins: _stats.matchWins + (won ? 1 : 0),
    ),
  );

  /// Сброс статистики по кнопке в настройках.
  void reset() => _update(const Stats());

  void _update(Stats next) {
    _stats = next;
    _prefs
      ?..setInt(_keyGames, next.games)
      ..setInt(_keyWins, next.wins)
      ..setInt(_keyMarsWins, next.marsWins)
      ..setInt(_keyMarsLosses, next.marsLosses)
      ..setInt(_keyMatches, next.matches)
      ..setInt(_keyMatchWins, next.matchWins);
    notifyListeners();
  }
}

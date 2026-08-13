import 'package:narda_core/narda_core.dart';

/// Режим партии.
enum GameMode { bot, hotseat, online }

/// С чем стартует партия. Оффлайн локальный игрок всегда играет белыми: его
/// дом — нижняя правая четверть доски. В онлайне цвет назначает комната, и
/// белыми может оказаться соперник — доска разворачивается сама.
class GameSetup {
  const GameSetup.vsBot(BotLevel level, {this.target = MatchTarget.single})
    : mode = GameMode.bot,
      botLevel = level,
      localPlayer = Player.white,
      opponentName = null;

  const GameSetup.hotseat({this.target = MatchTarget.single})
    : mode = GameMode.hotseat,
      botLevel = null,
      localPlayer = Player.white,
      opponentName = null;

  const GameSetup.online({
    required this.localPlayer,
    required this.target,
    this.opponentName,
  }) : mode = GameMode.online,
       botLevel = null;

  final GameMode mode;

  /// Уровень бота; `null` в hotseat и онлайне.
  final BotLevel? botLevel;

  /// Одиночная партия или серия до 3 / 5 / 7 очков (§3.4).
  final MatchTarget target;

  /// Игрок, чьи ходы вводятся с экрана и чья половина показана снизу.
  final Player localPlayer;

  /// Имя соперника в онлайне; `null` — соперник не человек за сетью.
  final String? opponentName;

  Player get opponentPlayer => localPlayer.opponent;
}

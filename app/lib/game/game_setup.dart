import 'package:narda_core/narda_core.dart';

/// Режим партии. Онлайн появится в P4 отдельной реализацией [Opponent].
enum GameMode { bot, hotseat }

/// С чем стартует партия. Локальный игрок всегда играет белыми: его дом —
/// нижняя правая четверть доски.
class GameSetup {
  const GameSetup.vsBot(BotLevel level, {this.target = MatchTarget.single})
    : mode = GameMode.bot,
      botLevel = level;

  const GameSetup.hotseat({this.target = MatchTarget.single})
    : mode = GameMode.hotseat,
      botLevel = null;

  final GameMode mode;

  /// Уровень бота; `null` в hotseat.
  final BotLevel? botLevel;

  /// Одиночная партия или серия до 3 / 5 / 7 очков (§3.4).
  final MatchTarget target;

  /// Игрок, чьи ходы вводятся с экрана и чья половина показана снизу.
  Player get localPlayer => Player.white;

  Player get opponentPlayer => localPlayer.opponent;
}

import 'package:narda_core/narda_core.dart';

/// Режим партии. Онлайн появится в P4 отдельной реализацией [Opponent].
enum GameMode { bot, hotseat }

/// С чем стартует партия. Локальный игрок всегда играет белыми: его дом —
/// нижняя правая четверть доски.
class GameSetup {
  const GameSetup.vsBot(BotLevel level) : mode = GameMode.bot, botLevel = level;

  const GameSetup.hotseat() : mode = GameMode.hotseat, botLevel = null;

  final GameMode mode;

  /// Уровень бота; `null` в hotseat.
  final BotLevel? botLevel;

  /// Игрок, чьи ходы вводятся с экрана и чья половина показана снизу.
  Player get localPlayer => Player.white;

  Player get opponentPlayer => localPlayer.opponent;
}

import 'package:narda/game/match_controller.dart';
import 'package:narda/game/opponent.dart';
import 'package:narda_core/narda_core.dart';

/// Бот без изолята — в тестах ход считается синхронно.
class StubBot implements Opponent {
  StubBot(this.player, {BotLevel level = BotLevel.orta, int seed = 3})
    : _bot = HeuristicBot(level: level, seed: seed);

  @override
  final Player player;

  final Bot _bot;

  @override
  bool get movesOnThisDevice => false;

  @override
  Future<MoveSequence?> chooseSequence(GameState state) async =>
      _bot.choose(state);

  @override
  void dispose() {}
}

/// Даёт отработать асинхронным шагам контроллера.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// Играет ход локального игрока тапами и подтверждает его.
void playLocalTurn(MatchController controller) {
  var guard = 0;
  while (controller.canInteract && !controller.canConfirm && guard++ < 12) {
    final List<int> sources = controller.movableSources.toList();
    if (sources.isEmpty) break;
    controller.tapPoint(sources.first);
    if (controller.selected == null) continue;
    final int? destination = controller.destinations.first;
    if (destination == null) {
      controller.tapBearOff();
    } else {
      controller.tapPoint(destination);
    }
  }
  if (controller.canConfirm) controller.confirm();
}

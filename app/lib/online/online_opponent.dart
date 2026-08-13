import 'package:narda_core/narda_core.dart';

import '../game/opponent.dart';
import 'online_match.dart';

/// Соперник за сетью (§6).
///
/// Для доски он ничем не отличается от бота: она спрашивает ход и ждёт
/// `Future`. Разница только в том, что ход не считается, а приезжает из
/// журнала комнаты — и уже проверен правилами в [OnlineMatch].
class OnlineOpponent implements Opponent {
  OnlineOpponent(this.match);

  final OnlineMatch match;

  @override
  Player get player => match.localColor.opponent;

  @override
  bool get movesOnThisDevice => false;

  @override
  Future<MoveSequence?> chooseSequence(GameState state) =>
      match.awaitOpponentMove(state);

  @override
  void dispose() => match.dispose();
}

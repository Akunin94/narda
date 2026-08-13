import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';

import 'game_setup.dart';

/// Соперник локального игрока.
///
/// UI не знает, кто за ним стоит: человек за этим же устройством, бот или
/// (в P4) сетевой игрок. Экран лишь спрашивает, приходит ли ход с доски.
abstract interface class Opponent {
  /// За какую сторону играет соперник.
  Player get player;

  /// `true` — ход соперника вводится с этого же экрана (hotseat), поэтому
  /// [chooseSequence] не вызывается, а доска переворачивается.
  bool get movesOnThisDevice;

  /// Ход соперника целиком. `null` — легальных ходов нет (пас).
  Future<MoveSequence?> chooseSequence(GameState state);

  void dispose();
}

/// Оба игрока ходят на одном устройстве.
class HotseatOpponent implements Opponent {
  const HotseatOpponent(this.player);

  @override
  final Player player;

  @override
  bool get movesOnThisDevice => true;

  @override
  Future<MoveSequence?> chooseSequence(GameState state) =>
      throw StateError('Hotseat opponent moves through the board');

  @override
  void dispose() {}
}

/// Бот из ядра. Считает ход в отдельном изоляте, чтобы не ронять кадры:
/// уровень Kuchli может думать до 200 мс (§4).
class BotOpponent implements Opponent {
  BotOpponent({
    required this.player,
    required this.level,
    this.thinkTime = const Duration(milliseconds: 450),
    int seed = 0,
  }) : _seed = seed;

  @override
  final Player player;

  final BotLevel level;

  /// Минимальная пауза «раздумья», чтобы ход бота не появлялся мгновенно.
  final Duration thinkTime;

  int _seed;

  @override
  bool get movesOnThisDevice => false;

  @override
  Future<MoveSequence?> chooseSequence(GameState state) async {
    final Future<List<int>> computation = compute(
      chooseBotMove,
      BotTask(encodedState: state.encode(), level: level.index, seed: _nextSeed()),
    );
    if (thinkTime > Duration.zero) {
      await Future<void>.delayed(thinkTime);
    }
    final List<int> flat = await computation;
    if (flat.isEmpty) return null;
    return decodeFlatSequence(state, flat);
  }

  int _nextSeed() {
    _seed = _seed == 0
        ? DateTime.now().microsecondsSinceEpoch & 0x3FFFFFFF
        : (_seed * 1103515245 + 12345) & 0x3FFFFFFF;
    return _seed;
  }

  @override
  void dispose() {}
}

Opponent createOpponent(GameSetup setup) => switch (setup.mode) {
  GameMode.bot => BotOpponent(
    player: setup.opponentPlayer,
    level: setup.botLevel ?? BotLevel.orta,
  ),
  GameMode.hotseat => HotseatOpponent(setup.opponentPlayer),
};

/// Задание боту: состояние передаётся в изолят строкой, ход возвращается
/// плоским списком пар `fromAbs, die` — оба формата сериализуемы без потерь.
class BotTask {
  const BotTask({
    required this.encodedState,
    required this.level,
    required this.seed,
  });

  final String encodedState;
  final int level;
  final int seed;
}

/// Точка входа изолята: считает ход бота по заданию [task].
@visibleForTesting
List<int> chooseBotMove(BotTask task) {
  final GameState state = GameState.decode(task.encodedState);
  final HeuristicBot bot = HeuristicBot(
    level: BotLevel.values[task.level],
    seed: task.seed,
  );
  final MoveSequence? sequence = bot.choose(state);
  if (sequence == null) return const <int>[];
  return <int>[
    for (final Move move in sequence.moves) ...<int>[move.fromAbs, move.die],
  ];
}

/// Восстанавливает ход из плоского списка пар `fromAbs, die`.
@visibleForTesting
MoveSequence decodeFlatSequence(GameState base, List<int> flat) => MoveSequence(<Move>[
  for (int i = 0; i < flat.length; i += 2)
    buildMove(player: base.turn, fromAbs: flat[i], die: flat[i + 1]),
]);

/// Собирает перемещение: за пределы дома — выброс, иначе обычный ход.
Move buildMove({
  required Player player,
  required int fromAbs,
  required int die,
}) => Coords.toOwn(player, fromAbs) - die >= 1
    ? Move.point(player: player, fromAbs: fromAbs, die: die)
    : Move.bearOff(player: player, fromAbs: fromAbs, die: die);

import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';

// shortcut: временный журнал партии в logcat для разбора бота; убрать после отладки.
const bool kGameLog = bool.fromEnvironment('NARDA_GAME_LOG');

/// Одна строка на ход: `T<ход> <w|b><s|r> <кости> > <сыгранный> | <топ-3 с оценкой> | n=<вариантов> | <позиция до хода>`.
/// s — ходил игрок на устройстве, r — соперник; позиция — `GameState.encode()`.
void logTurn(GameState before, MoveSequence played, {required bool local}) {
  if (!kGameLog) return;
  final List<MoveSequence> options = const MoveGenerator().generate(before);
  const Evaluator evaluator = Evaluator();
  final List<(MoveSequence, double)> ranked = <(MoveSequence, double)>[
    for (final MoveSequence option in options)
      (option, evaluator.evaluate(before.applySequence(option), before.turn)),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  final String top = ranked
      .take(3)
      .map(((MoveSequence, double) r) =>
          '${r.$1 == played ? '*' : ''}${r.$1} ${r.$2.round()}')
      .join('; ');
  debugPrint(
    'NARDA T${before.turnIndex} ${before.turn.code}${local ? 's' : 'r'} '
    '${before.roll} > $played | $top | n=${options.length} | ${before.encode()}',
  );
}

void logResult(GameResult result) {
  if (kGameLog) {
    debugPrint('NARDA END ${result.winner.code} mars=${result.isMars}');
  }
}

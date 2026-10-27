import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';

// shortcut: временный журнал партии в logcat для разбора бота; убрать после отладки.
const bool kGameLog = bool.fromEnvironment('NARDA_GAME_LOG');

/// Пишет ход в logcat: доска до хода, кости, ход и топ-5 вариантов по оценке бота.
void logTurn(GameState before, MoveSequence played, {required String who}) {
  if (!kGameLog) return;
  final List<MoveSequence> options = const MoveGenerator().generate(before);
  const Evaluator evaluator = Evaluator();
  final List<(MoveSequence, double)> ranked = <(MoveSequence, double)>[
    for (final MoveSequence option in options)
      (option, evaluator.evaluate(before.applySequence(option), before.turn)),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  final StringBuffer out = StringBuffer()
    ..writeln('=== ${before.turn.name} ($who) zarlar ${before.roll}: $played')
    ..writeln('state ${before.encode()}')
    ..write(AsciiBoard.render(before));
  for (final (MoveSequence option, double score) in ranked.take(5)) {
    final String mark = option == played ? '*' : ' ';
    out.writeln('$mark ${score.toStringAsFixed(1)}  $option');
  }
  out.writeln('variantlar: ${options.length}');
  _emit(out.toString());
}

void logResult(GameResult result) {
  if (kGameLog) _emit('=== natija: ${result.winner.name} g\'alaba, mars=${result.isMars}');
}

// Префикс на каждой строке — чтобы вытащить журнал через grep.
void _emit(String text) {
  for (final String line in text.split('\n')) {
    if (line.isNotEmpty) debugPrint('NARDA $line');
  }
}

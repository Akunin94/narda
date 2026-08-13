import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/gen/app_text.dart';
import '../../online/online_match.dart';
import '../../theme/narda_theme.dart';
import 'phrase_bar.dart';

/// Полоска онлайна над доской: реплика соперника, связь, таймер хода и
/// клейм победы по отсутствию (§6).
class OnlineStatusBar extends StatelessWidget {
  const OnlineStatusBar({
    super.key,
    required this.match,
    required this.isOver,
  });

  final OnlineMatch match;

  /// Партия доиграна: таймер и клейм больше не нужны.
  final bool isOver;

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    final Duration? left = match.turnRemaining;
    final String? phrase = match.opponentPhrase;
    return Column(
      children: <Widget>[
        if (phrase != null) PhraseBubble(phrase: phrase),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              Icon(
                match.opponentOnline ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: match.opponentOnline
                    ? NardaColors.textMuted
                    : NardaColors.gold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  match.opponentOnline
                      ? match.opponentName
                      : text.onlineOpponentOffline,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NardaColors.textMuted,
                  ),
                ),
              ),
              if (match.canClaimWin && !isOver)
                TextButton(
                  onPressed: () => unawaited(match.claimWin()),
                  child: Text(
                    text.onlineClaimWin,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (left != null && !isOver)
                Text(
                  text.onlineSecondsLeft(left.inSeconds),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: left.inSeconds <= 10
                        ? NardaColors.gold
                        : NardaColors.textMuted,
                  ),
                ),
              IconButton(
                onPressed: () => showPhraseSheet(
                  context,
                  onSend: (String phrase) => unawaited(match.sendPhrase(phrase)),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                color: NardaColors.textMuted,
                tooltip: text.onlinePhrasesTitle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

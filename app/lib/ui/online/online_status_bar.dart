import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/gen/app_text.dart';
import '../../online/online_match.dart';
import '../../online/voice_chat.dart';
import '../../theme/narda_theme.dart';
import 'phrase_bar.dart';

/// Полоска онлайна над доской: реплика соперника, связь, таймер хода и
/// клейм победы по отсутствию (§6).
class OnlineStatusBar extends StatelessWidget {
  const OnlineStatusBar({
    super.key,
    required this.match,
    required this.isOver,
    this.voice,
  });

  final OnlineMatch match;

  /// Голосовая связь; `null` — кнопки микрофона нет.
  final VoiceChat? voice;

  /// Партия доиграна: таймер и клейм больше не нужны.
  final bool isOver;

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    final Duration? left = match.turnRemaining;
    return Column(
      children: <Widget>[
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
              if (voice case final VoiceChat voice)
                ListenableBuilder(
                  listenable: voice,
                  builder: (BuildContext context, Widget? child) => IconButton(
                    onPressed: () => _toggleVoice(context, voice, text),
                    // Точка: соперник уже включил голос и ждёт.
                    icon: Badge(
                      isLabelVisible: !voice.enabled && voice.peerEnabled,
                      smallSize: 7,
                      backgroundColor: NardaColors.gold,
                      child: Icon(
                        voice.enabled ? Icons.mic : Icons.mic_off,
                        size: 18,
                      ),
                    ),
                    color: voice.connected
                        ? NardaColors.gold
                        : voice.enabled
                        ? NardaColors.textPrimary
                        : NardaColors.textMuted,
                    tooltip: !voice.enabled
                        ? (voice.peerEnabled ? text.voicePeerOn : text.voiceTurnOn)
                        : (voice.connected ? text.voiceOn : text.voiceWaiting),
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

  Future<void> _toggleVoice(
    BuildContext context,
    VoiceChat voice,
    AppText text,
  ) async {
    final bool wasEnabled = voice.enabled;
    await voice.toggle();
    if (!context.mounted || wasEnabled) return;
    final String? message = voice.denied
        ? text.voiceDenied
        : voice.enabled && !voice.peerEnabled
        ? text.voiceWaiting
        : null;
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

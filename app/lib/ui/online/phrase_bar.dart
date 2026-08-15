import 'package:flutter/material.dart';

import '../../l10n/gen/app_text.dart';
import '../../online/protocol.dart';
import '../../theme/narda_theme.dart';
import '../sheet.dart';

/// Общение в онлайне: только готовые фразы и эмодзи, свободного чата нет —
/// его не пришлось бы модерировать (§6).
Future<void> showPhraseSheet(
  BuildContext context, {
  required ValueChanged<String> onSend,
}) async {
  final AppText text = AppText.of(context);
  final String? phrase = await showNardaSheet<String>(
    context,
    builder: (BuildContext context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          NardaSheetTitle(text.onlinePhrasesTitle),
          for (final String id in quickPhraseIds)
            ListTile(
              title: Text(
                phraseText(text, id),
                style: const TextStyle(color: NardaColors.textPrimary),
              ),
              onTap: () => Navigator.of(context).pop(id),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (final String emoji in quickEmoji)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(emoji),
                    icon: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (phrase != null) onSend(phrase);
}

/// Текст фразы на языке интерфейса: по сети ходит только идентификатор,
/// поэтому узбек и русский видят каждый своё.
String phraseText(AppText text, String id) => switch (id) {
  'salom' => text.phraseSalom,
  'yaxshiYurish' => text.phraseYaxshiYurish,
  'omad' => text.phraseOmad,
  'rahmat' => text.phraseRahmat,
  // Эмодзи приходят как есть.
  _ => id,
};

/// Всплывающая реплика соперника над доской.
class PhraseBubble extends StatelessWidget {
  const PhraseBubble({super.key, required this.phrase});

  final String phrase;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: NardaColors.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: NardaColors.goldDeep),
    ),
    child: Text(
      phraseText(AppText.of(context), phrase),
      textAlign: TextAlign.center,
      style: const TextStyle(color: NardaColors.textPrimary),
    ),
  );
}

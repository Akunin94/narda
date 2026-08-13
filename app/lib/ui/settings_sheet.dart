import 'package:flutter/material.dart';

import '../game/settings.dart';
import '../l10n/gen/app_text.dart';
import '../theme/narda_theme.dart';

/// Настройки P2: автоход и pip-счёт. Язык, звук и вибрация появятся в P3.
Future<void> showSettingsSheet(
  BuildContext context,
  SettingsController settings,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: NardaColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (BuildContext context) {
    final AppText text = AppText.of(context);
    return SafeArea(
      child: AnimatedBuilder(
        animation: settings,
        builder: (BuildContext context, Widget? child) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                text.menuSettings,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: NardaColors.textPrimary,
                ),
              ),
            ),
            SwitchListTile(
              value: settings.autoMove,
              onChanged: (bool value) => settings.autoMove = value,
              title: Text(
                text.settingAutoMove,
                style: const TextStyle(color: NardaColors.textPrimary),
              ),
              subtitle: Text(
                text.settingAutoMoveHint,
                style: const TextStyle(color: NardaColors.textMuted),
              ),
            ),
            SwitchListTile(
              value: settings.showPips,
              onChanged: (bool value) => settings.showPips = value,
              title: Text(
                text.settingShowPips,
                style: const TextStyle(color: NardaColors.textPrimary),
              ),
              subtitle: Text(
                text.settingShowPipsHint,
                style: const TextStyle(color: NardaColors.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(text.actionClose),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  },
);

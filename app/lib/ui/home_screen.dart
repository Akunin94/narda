import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

import '../app.dart';
import '../game/game_setup.dart';
import '../game/settings.dart';
import '../l10n/gen/app_text.dart';
import '../theme/narda_theme.dart';
import 'game_screen.dart';
import 'settings_sheet.dart';

/// Главный экран: два режима и настройки. Партия с ботом начинается в два
/// тапа — «Bot bilan o'ynash» и уровень.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    final SettingsController settings = SettingsScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(flex: 2),
              Text(
                text.appTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: NardaColors.gold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text.menuSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: NardaColors.textMuted,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _chooseLevel(context, text, settings),
                child: Text(text.menuPlayBot),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    _startGame(context, settings, const GameSetup.hotseat()),
                child: Text(text.menuPlayHotseat),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => showSettingsSheet(context, settings),
                icon: const Icon(Icons.settings, color: NardaColors.textMuted),
                label: Text(
                  text.menuSettings,
                  style: const TextStyle(color: NardaColors.textMuted),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseLevel(
    BuildContext context,
    AppText text,
    SettingsController settings,
  ) async {
    final BotLevel? level = await showModalBottomSheet<BotLevel>(
      context: context,
      backgroundColor: NardaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                text.levelTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: NardaColors.textPrimary,
                ),
              ),
            ),
            for (final ({BotLevel level, String label}) entry
                in <({BotLevel level, String label})>[
                  (level: BotLevel.oson, label: text.levelOson),
                  (level: BotLevel.orta, label: text.levelOrta),
                  (level: BotLevel.kuchli, label: text.levelKuchli),
                ])
              ListTile(
                title: Text(
                  entry.label,
                  style: const TextStyle(color: NardaColors.textPrimary),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: NardaColors.textMuted,
                ),
                onTap: () => Navigator.of(context).pop(entry.level),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (level == null || !context.mounted) return;
    await _startGame(context, settings, GameSetup.vsBot(level));
  }

  Future<void> _startGame(
    BuildContext context,
    SettingsController settings,
    GameSetup setup,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          GameScreen(setup: setup, settings: settings),
    ),
  );
}

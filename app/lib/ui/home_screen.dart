import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

import '../app.dart';
import '../game/game_setup.dart';
import '../game/settings.dart';
import '../l10n/gen/app_text.dart';
import '../theme/narda_theme.dart';
import 'game_screen.dart';
import 'online/online_screen.dart';
import 'rules_screen.dart';
import 'settings_sheet.dart';
import 'stats_screen.dart';
import 'themes_screen.dart';

/// Главный экран. Партия с ботом начинается в два тапа: «Bot bilan o'ynash»
/// и уровень — формат матча в том же листе уже подставлен прошлым выбором
/// (§P3, Definition of Done).
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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const OnlineScreen(),
                  ),
                ),
                child: Text(text.menuPlayOnline),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _startGame(
                  context,
                  settings,
                  GameSetup.hotseat(target: settings.matchTarget),
                ),
                child: Text(text.menuPlayHotseat),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _MenuLink(
                    icon: Icons.menu_book_outlined,
                    label: text.menuRules,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const RulesScreen(),
                      ),
                    ),
                  ),
                  _MenuLink(
                    icon: Icons.bar_chart,
                    label: text.menuStats,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const StatsScreen(),
                      ),
                    ),
                  ),
                  _MenuLink(
                    icon: Icons.palette_outlined,
                    label: text.menuThemes,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const ThemesScreen(),
                      ),
                    ),
                  ),
                  _MenuLink(
                    icon: Icons.settings,
                    label: text.menuSettings,
                    onPressed: () => showSettingsSheet(context),
                  ),
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  /// Лист старта: формат матча (запоминается) и три уровня бота.
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
        child: AnimatedBuilder(
          animation: settings,
          builder: (BuildContext context, Widget? child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SheetTitle(text.matchTitle),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MatchTargetPicker(
                  value: settings.matchTarget,
                  onChanged: (MatchTarget target) =>
                      settings.matchTarget = target,
                ),
              ),
              _SheetTitle(text.levelTitle),
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
                  leading: Icon(
                    entry.level == settings.botLevel
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: entry.level == settings.botLevel
                        ? NardaColors.gold
                        : NardaColors.textMuted,
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
      ),
    );
    if (level == null || !context.mounted) return;
    settings.botLevel = level;
    await _startGame(
      context,
      settings,
      GameSetup.vsBot(level, target: settings.matchTarget),
    );
  }

  Future<void> _startGame(
    BuildContext context,
    SettingsController settings,
    GameSetup setup,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => GameScreen(setup: setup),
    ),
  );
}

/// Переключатель формата матча: одиночная партия или серия до 3 / 5 / 7 (§3.4).
class MatchTargetPicker extends StatelessWidget {
  const MatchTargetPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MatchTarget value;
  final ValueChanged<MatchTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    return SegmentedButton<MatchTarget>(
      segments: <ButtonSegment<MatchTarget>>[
        for (final MatchTarget target in MatchTarget.values)
          ButtonSegment<MatchTarget>(
            value: target,
            label: Text(
              target == MatchTarget.single
                  ? text.matchSingle
                  : '${target.points}',
            ),
          ),
      ],
      selected: <MatchTarget>{value},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: NardaColors.surfaceHigh,
        foregroundColor: NardaColors.textMuted,
        selectedBackgroundColor: NardaColors.gold,
        selectedForegroundColor: NardaColors.surface,
        side: const BorderSide(color: NardaColors.goldDeep),
      ),
      onSelectionChanged: (Set<MatchTarget> selection) =>
          onChanged(selection.single),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: NardaColors.textPrimary,
      ),
    ),
  );
}

class _MenuLink extends StatelessWidget {
  const _MenuLink({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Expanded(
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: NardaColors.textMuted, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(color: NardaColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

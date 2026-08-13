import 'package:flutter/material.dart';

import '../ads/ads_controller.dart';
import '../app.dart';
import '../game/settings.dart';
import '../game/stats.dart';
import '../l10n/gen/app_text.dart';
import '../theme/narda_theme.dart';

/// Настройки: язык, звук, вибрация, автоход, pip-счёт, сброс статистики и
/// повторный вызов окна согласия на рекламу (§P3).
Future<void> showSettingsSheet(BuildContext context) {
  final SettingsController settings = SettingsScope.of(context);
  final StatsStore stats = StatsScope.of(context);
  final AdsController ads = AdsScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NardaColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) => _SettingsSheet(
      settings: settings,
      stats: stats,
      ads: ads,
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.settings,
    required this.stats,
    required this.ads,
  });

  final SettingsController settings;
  final StatsStore stats;
  final AdsController ads;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  /// Окно приватности показывается только там, где его требует UMP.
  bool _privacyAvailable = false;

  @override
  void initState() {
    super.initState();
    widget.ads.privacyOptionsRequired().then((bool required) {
      if (mounted) setState(() => _privacyAvailable = required);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    final SettingsController settings = widget.settings;
    return SafeArea(
      child: AnimatedBuilder(
        animation: settings,
        builder: (BuildContext context, Widget? child) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: ListView(
            shrinkWrap: true,
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
              ListTile(
                title: Text(
                  text.settingLanguage,
                  style: const TextStyle(color: NardaColors.textPrimary),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<String>(
                      segments: <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'auto',
                          label: Text(text.languageAuto),
                        ),
                        ButtonSegment<String>(
                          value: 'uz',
                          label: Text(text.languageUz),
                        ),
                        ButtonSegment<String>(
                          value: 'ru',
                          label: Text(text.languageRu),
                        ),
                      ],
                      selected: <String>{settings.localeCode ?? 'auto'},
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        backgroundColor: NardaColors.surfaceHigh,
                        foregroundColor: NardaColors.textMuted,
                        selectedBackgroundColor: NardaColors.gold,
                        selectedForegroundColor: NardaColors.surface,
                        side: const BorderSide(color: NardaColors.goldDeep),
                      ),
                      onSelectionChanged: (Set<String> selection) =>
                          settings.localeCode = selection.single == 'auto'
                          ? null
                          : selection.single,
                    ),
                  ),
                ),
              ),
              _switch(
                title: text.settingSound,
                hint: text.settingSoundHint,
                value: settings.sound,
                onChanged: (bool value) => settings.sound = value,
              ),
              _switch(
                title: text.settingVibration,
                hint: text.settingVibrationHint,
                value: settings.vibration,
                onChanged: (bool value) => settings.vibration = value,
              ),
              _switch(
                title: text.settingAutoMove,
                hint: text.settingAutoMoveHint,
                value: settings.autoMove,
                onChanged: (bool value) => settings.autoMove = value,
              ),
              _switch(
                title: text.settingShowPips,
                hint: text.settingShowPipsHint,
                value: settings.showPips,
                onChanged: (bool value) => settings.showPips = value,
              ),
              if (_privacyAvailable)
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: NardaColors.textMuted,
                  ),
                  title: Text(
                    text.settingPrivacy,
                    style: const TextStyle(color: NardaColors.textPrimary),
                  ),
                  onTap: widget.ads.showPrivacyOptions,
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: NardaColors.textMuted,
                ),
                title: Text(
                  text.actionResetStats,
                  style: const TextStyle(color: NardaColors.textPrimary),
                ),
                onTap: () => _confirmReset(text),
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
      ),
    );
  }

  Widget _switch({
    required String title,
    required String hint,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    value: value,
    onChanged: onChanged,
    title: Text(title, style: const TextStyle(color: NardaColors.textPrimary)),
    subtitle: Text(hint, style: const TextStyle(color: NardaColors.textMuted)),
  );

  Future<void> _confirmReset(AppText text) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: NardaColors.surface,
        content: Text(text.resetStatsQuestion),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(text.actionNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(text.actionYes),
          ),
        ],
      ),
    );
    if (confirmed ?? false) widget.stats.reset();
  }
}

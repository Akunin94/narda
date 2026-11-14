import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/gen/app_text.dart';
import '../online/min_build.dart';
import '../theme/narda_theme.dart';

/// Страница игры в Google Play.
const String playStoreLink =
    'https://play.google.com/store/apps/details?id=uz.uzunnarda.narda';

/// Закрывает игру экраном «обновите», если сборка ниже [MinBuild].
/// Проверка — при запуске и при каждом возврате в приложение.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  bool _outdated = false;
  Object? _note;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    final MinBuildConfig? config = await MinBuild.fetch();
    if (config == null) return;
    final PackageInfo info = await PackageInfo.fromPlatform();
    final int? build = int.tryParse(info.buildNumber);
    if (build == null || !mounted) return;
    setState(() {
      _outdated = build < config.minBuild;
      _note = config.note;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_outdated) return widget.child;
    final AppText text = AppText.of(context);
    final String? note = updateNote(
      _note,
      Localizations.localeOf(context).languageCode,
    );
    return Material(
      color: NardaColors.background,
      child: SafeArea(
        child: Center(
          // Пояснение может быть длинным, а в альбоме экран низкий.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.system_update,
                  size: 56,
                  color: NardaColors.gold,
                ),
                const SizedBox(height: 20),
                Text(
                  text.updateRequiredTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NardaColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  text.updateRequiredBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NardaColors.textMuted),
                ),
                if (note != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NardaColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NardaColors.goldDeep),
                    ),
                    child: Text(
                      note,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: NardaColors.textPrimary),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => launchUrl(
                    Uri.parse(playStoreLink),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(text.updateRequiredAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

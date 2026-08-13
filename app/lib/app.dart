import 'package:flutter/material.dart';

import 'game/settings.dart';
import 'l10n/gen/app_text.dart';
import 'theme/narda_theme.dart';
import 'ui/home_screen.dart';

/// Доступ к настройкам из любого места дерева.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SettingsScope>()!
      .notifier!;
}

/// Язык по умолчанию — узбекский (§7): русский включается только если он
/// стоит в языках устройства.
const Locale nardaDefaultLocale = Locale('uz');

Locale resolveNardaLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final Locale locale in preferred ?? const <Locale>[]) {
    for (final Locale candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return nardaDefaultLocale;
}

class NardaApp extends StatelessWidget {
  const NardaApp({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) => SettingsScope(
    controller: settings,
    child: MaterialApp(
      onGenerateTitle: (BuildContext context) => AppText.of(context).appTitle,
      theme: buildNardaTheme(),
      localizationsDelegates: AppText.localizationsDelegates,
      supportedLocales: AppText.supportedLocales,
      localeListResolutionCallback: resolveNardaLocale,
      home: const HomeScreen(),
    ),
  );
}

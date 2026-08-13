import 'package:flutter/material.dart';

import 'ads/ads_controller.dart';
import 'game/settings.dart';
import 'game/stats.dart';
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

/// Доступ к локальной статистике.
class StatsScope extends InheritedNotifier<StatsStore> {
  const StatsScope({
    super.key,
    required StatsStore store,
    required super.child,
  }) : super(notifier: store);

  static StatsStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StatsScope>()!.notifier!;
}

/// Доступ к рекламе. В тестах здесь лежит [AdsController.disabled].
class AdsScope extends InheritedNotifier<AdsController> {
  const AdsScope({
    super.key,
    required AdsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AdsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdsScope>()!.notifier!;
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
  NardaApp({
    super.key,
    required this.settings,
    StatsStore? stats,
    AdsController? ads,
    this.home,
  }) : stats = stats ?? StatsStore.inMemory(),
       ads = ads ?? AdsController.disabled();

  final SettingsController settings;
  final StatsStore stats;
  final AdsController ads;

  /// Стартовый экран; `null` — главное меню. Подменяется в тестах, чтобы
  /// открыть экран сразу, со своими зависимостями.
  final Widget? home;

  @override
  Widget build(BuildContext context) => SettingsScope(
    controller: settings,
    child: StatsScope(
      store: stats,
      child: AdsScope(
        controller: ads,
        child: AnimatedBuilder(
          animation: settings,
          builder: (BuildContext context, Widget? child) => MaterialApp(
            onGenerateTitle: (BuildContext context) => AppText.of(context).appTitle,
            theme: buildNardaTheme(),
            localizationsDelegates: AppText.localizationsDelegates,
            supportedLocales: AppText.supportedLocales,
            // Выбранный в настройках язык побеждает язык устройства (§P3).
            locale: settings.localeCode == null
                ? null
                : Locale(settings.localeCode!),
            localeListResolutionCallback: resolveNardaLocale,
            home: home ?? const HomeScreen(),
          ),
        ),
      ),
    ),
  );
}

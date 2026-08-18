import 'package:flutter/material.dart';
import 'package:narda/ads/ads_controller.dart';
import 'package:narda/app.dart';
import 'package:narda/game/settings.dart';
import 'package:narda/game/stats.dart';
import 'package:narda/l10n/gen/app_text.dart';

/// Дерево для виджет-тестов одного экрана.
///
/// Экраны берут настройки, статистику и рекламу из дерева, а язык — из
/// делегатов локализации, поэтому голый [MaterialApp] им не годится. Здесь
/// всё это без диска и с выключенной рекламой; целиком приложение поднимает
/// [NardaApp], он же ставит [ProfileScope].
Widget wrap(Widget child, {SettingsController? settings, StatsStore? stats}) =>
    SettingsScope(
      controller: settings ?? SettingsController.inMemory(),
      child: StatsScope(
        store: stats ?? StatsStore.inMemory(),
        child: AdsScope(
          controller: AdsController.disabled(),
          child: MaterialApp(
            localizationsDelegates: AppText.localizationsDelegates,
            supportedLocales: AppText.supportedLocales,
            localeListResolutionCallback: resolveNardaLocale,
            home: child,
          ),
        ),
      ),
    );

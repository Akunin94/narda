import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ads/ads_controller.dart';
import 'app.dart';
import 'game/settings.dart';
import 'game/stats.dart';
import 'online/firebase_config.dart';
import 'profile/profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initCrashReports();
  final SettingsController settings = await SettingsController.load();
  final StatsStore stats = await StatsStore.load();
  final ProfileController profile = await ProfileController.load();
  final AdsController ads = AdsController();
  // Согласие и загрузка объявлений идут фоном: меню не должно их ждать.
  unawaited(ads.initialize());
  runApp(
    NardaApp(settings: settings, stats: stats, ads: ads, profile: profile),
  );
}

/// Падения релиза уходят в Crashlytics; в debug и без ключей Firebase — нет.
Future<void> _initCrashReports() async {
  if (!kReleaseMode || !OnlineConfig.isConfigured) return;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: OnlineConfig.options);
    }
  } on Object {
    // Без Firebase игра всё равно запускается — отчёты не важнее старта.
    return;
  }
  final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  WidgetsBinding.instance.platformDispatcher.onError = (
    Object error,
    StackTrace stack,
  ) {
    unawaited(crashlytics.recordError(error, stack, fatal: true));
    return true;
  };
}

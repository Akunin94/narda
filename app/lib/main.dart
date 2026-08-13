import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/ads_controller.dart';
import 'app.dart';
import 'game/settings.dart';
import 'game/stats.dart';
import 'profile/profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
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

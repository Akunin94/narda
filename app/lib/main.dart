import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'game/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  final SettingsController settings = await SettingsController.load();
  runApp(NardaApp(settings: settings));
}

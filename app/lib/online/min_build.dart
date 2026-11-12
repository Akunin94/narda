import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'firebase_config.dart';

/// Минимальная сборка, с которой ещё можно играть: `config/minBuild` в базе.
/// Поднимается вручную в консоли Firebase, когда старые версии ломают онлайн.
abstract final class MinBuild {
  /// `null` — узнать не удалось (нет ключей, нет сети): играть можно.
  static Future<int?> fetch() async {
    if (!OnlineConfig.isConfigured) return null;
    try {
      final FirebaseApp app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: OnlineConfig.options)
          : Firebase.app();
      final DataSnapshot snapshot = await FirebaseDatabase.instanceFor(
        app: app,
        databaseURL: OnlineConfig.databaseUrl,
      ).ref('config/minBuild').get().timeout(const Duration(seconds: 8));
      final Object? value = snapshot.value;
      return value is int ? value : null;
    } on Object {
      return null;
    }
  }
}

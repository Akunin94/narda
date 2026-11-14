import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'firebase_config.dart';

/// Минимальная сборка, с которой ещё можно играть: `config/minBuild` в базе,
/// и пояснение к обновлению `config/updateNote` (строка или {uz, ru}).
/// Оба поднимаются вручную в консоли Firebase.
typedef MinBuildConfig = ({int minBuild, Object? note});

abstract final class MinBuild {
  /// `null` — узнать не удалось (нет ключей, нет сети): играть можно.
  static Future<MinBuildConfig?> fetch() async {
    if (!OnlineConfig.isConfigured) return null;
    try {
      final FirebaseApp app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: OnlineConfig.options)
          : Firebase.app();
      final DataSnapshot snapshot = await FirebaseDatabase.instanceFor(
        app: app,
        databaseURL: OnlineConfig.databaseUrl,
      ).ref('config').get().timeout(const Duration(seconds: 8));
      final Object? config = snapshot.value;
      if (config is! Map) return null;
      final Object? minBuild = config['minBuild'];
      return minBuild is int
          ? (minBuild: minBuild, note: config['updateNote'])
          : null;
    } on Object {
      return null;
    }
  }
}

/// Пояснение на языке [lang]: строка — одна на всех, карта — по языкам,
/// без нужного языка берётся узбекский. Пустое — `null`.
String? updateNote(Object? note, String lang) {
  final Object? text = note is Map ? (note[lang] ?? note['uz']) : note;
  return text is String && text.trim().isNotEmpty ? text.trim() : null;
}

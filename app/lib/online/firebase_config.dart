import 'package:firebase_core/firebase_core.dart';

/// Ключи проекта Firebase приходят снаружи — через `--dart-define`, как и
/// ad unit id в P3. В репозитории их нет: пока владелец не завёл проект,
/// онлайн честно пишет, что он не настроен, а оффлайн работает как прежде.
///
/// ```bash
/// flutter run \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_APP_ID=1:000:android:000 \
///   --dart-define=FIREBASE_SENDER_ID=000 \
///   --dart-define=FIREBASE_PROJECT_ID=uzun-narda \
///   --dart-define=FIREBASE_DATABASE_URL=https://uzun-narda.firebaseio.com
/// ```
class OnlineConfig {
  const OnlineConfig._();

  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String databaseUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
  );

  /// Все ключи на месте — онлайн можно предлагать.
  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      senderId.isNotEmpty &&
      projectId.isNotEmpty &&
      databaseUrl.isNotEmpty;

  /// Настройки передаются кодом, а не файлом `google-services.json`:
  /// так в репозитории не лежит чужой проект, а сборка не зависит от него.
  static FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    databaseURL: databaseUrl,
  );
}

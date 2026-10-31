import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_config.dart';
import 'online_backend.dart';
import 'protocol.dart';

/// Вход через Google поверх анонимного аккаунта: рейтинг привязывается к
/// Google-аккаунту и переживает переустановку и смену телефона.
abstract final class GoogleAccount {
  /// Web client ID проекта Firebase — приходит через `--dart-define`.
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static bool get isConfigured =>
      OnlineConfig.isConfigured && _serverClientId.isNotEmpty;

  static bool _initialized = false;

  static Future<FirebaseAuth> _auth() async {
    final FirebaseApp app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(options: OnlineConfig.options)
        : Firebase.app();
    return FirebaseAuth.instanceFor(app: app);
  }

  /// Почта привязанного Google-аккаунта; `null` — вход не выполнен.
  static Future<String?> email() async {
    if (!isConfigured) return null;
    final User? user = (await _auth()).currentUser;
    for (final UserInfo info in user?.providerData ?? const <UserInfo>[]) {
      if (info.providerId == GoogleAuthProvider.PROVIDER_ID) {
        return info.email ?? '';
      }
    }
    return null;
  }

  /// Вход через Google. Если этот аккаунт уже играл на другом телефоне —
  /// возвращает его профиль из таблицы лидеров, им заменяется местный.
  /// `null` — аккаунт привязан к текущему профилю, менять ничего не надо.
  static Future<RatingEntry?> signIn() async {
    if (!isConfigured) {
      throw const OnlineUnavailable(OnlineFailure.notConfigured);
    }
    final GoogleSignIn google = GoogleSignIn.instance;
    if (!_initialized) {
      await google.initialize(serverClientId: _serverClientId);
      _initialized = true;
    }
    final GoogleSignInAccount account = await google.authenticate();
    final String? idToken = account.authentication.idToken;
    if (idToken == null) throw const OnlineUnavailable(OnlineFailure.network);
    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    final FirebaseAuth auth = await _auth();
    final User? current = auth.currentUser;
    if (current != null) {
      try {
        // Тот же uid — рейтинг и история остаются как есть.
        await current.linkWithCredential(credential);
        // Свежий токен с почтой — по ней правила пускают в таблицу лидеров.
        await current.getIdToken(true);
        return null;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use') rethrow;
        await auth.signInWithCredential(error.credential ?? credential);
      }
    } else {
      await auth.signInWithCredential(credential);
    }
    final String uid = auth.currentUser!.uid;
    final DataSnapshot saved = await FirebaseDatabase.instanceFor(
      app: auth.app,
      databaseURL: OnlineConfig.databaseUrl,
    ).ref('users/$uid').get();
    return RatingEntry.fromJson(uid, saved.value);
  }
}

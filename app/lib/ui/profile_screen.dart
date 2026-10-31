import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app.dart';
import '../l10n/gen/app_text.dart';
import '../online/firebase_backend.dart';
import '../online/google_account.dart';
import '../online/online_backend.dart';
import '../online/protocol.dart';
import '../online/rating_service.dart';
import '../profile/profile.dart';
import '../theme/narda_theme.dart';
import 'avatar.dart';
import 'chrome.dart';
import 'online/leaderboard_screen.dart';

/// Профиль: ник, аватар из набора и рейтинг Elo (§P5).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.backend});

  /// Бэкенд таблицы лидеров; подменяется в тестах на комнаты в памяти.
  final OnlineBackend? backend;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _profile = ProfileScope.of(context);
  late final TextEditingController _name = TextEditingController(
    text: _profile.name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    return Scaffold(
      appBar: NardaAppBar(title: text.profileTitle),
      body: AnimatedBuilder(
        animation: _profile,
        builder: (BuildContext context, Widget? child) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            Center(child: NardaAvatar(index: _profile.avatar, size: 96)),
            const SizedBox(height: 20),
            Text(
              text.profileName,
              style: const TextStyle(color: NardaColors.textMuted),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              maxLength: nardaMaxNameLength,
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                fontSize: 18,
                color: NardaColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: text.profileNameHint,
                filled: true,
                fillColor: NardaColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: NardaColors.goldDeep),
                ),
              ),
              // Ник сохраняется по ходу набора: отдельной кнопки «сохранить»
              // нет — пустое поле просто оставляет прежний ник.
              onChanged: (String value) => _profile.name = value,
            ),
            const SizedBox(height: 12),
            Text(
              text.profileAvatar,
              style: const TextStyle(color: NardaColors.textMuted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (int index = 0; index < nardaAvatarCount; index++)
                  GestureDetector(
                    onTap: () => _profile.avatar = index,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: index == _profile.avatar
                              ? NardaColors.gold
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: NardaAvatar(index: index, size: 54),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _RatingCard(profile: _profile),
            if (GoogleAccount.isConfigured) ...<Widget>[
              const SizedBox(height: 12),
              _GoogleAccountTile(profile: _profile),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  openScreen(context, LeaderboardScreen(backend: widget.backend)),
              icon: const Icon(Icons.leaderboard_outlined),
              label: Text(text.leaderboardTitle),
            ),
            const SizedBox(height: 12),
            NardaHint(text.profileRatingNote),
          ],
        ),
      ),
    );
  }
}

/// Вход через Google: рейтинг переживает переустановку и смену телефона.
class _GoogleAccountTile extends StatefulWidget {
  const _GoogleAccountTile({required this.profile});

  final ProfileController profile;

  @override
  State<_GoogleAccountTile> createState() => _GoogleAccountTileState();
}

class _GoogleAccountTileState extends State<_GoogleAccountTile> {
  String? _email;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? email;
    try {
      email = await GoogleAccount.email();
    } on Object {
      email = null;
    }
    if (!mounted) return;
    setState(() {
      _email = email;
      _busy = false;
    });
  }

  Future<void> _signIn(AppText text) async {
    setState(() => _busy = true);
    String? message;
    try {
      final RatingEntry? saved = await GoogleAccount.signIn();
      if (saved != null) {
        widget.profile.restore(
          PlayerProfile(
            name: saved.name,
            avatar: saved.avatar,
            rating: saved.rating,
            ratedGames: saved.games,
            ratedWins: saved.wins,
          ),
        );
        message = text.accountRestored;
      }
      // Публикуем профиль заново — теперь с отметкой Google, он появится в таблице лидеров.
      await RatingService(
        backend: FirebaseOnlineBackend(),
        profile: widget.profile,
      ).publish();
    } on GoogleSignInException catch (error) {
      // Окно выбора аккаунта просто закрыли — это не ошибка.
      if (error.code != GoogleSignInExceptionCode.canceled) {
        message = text.accountSignInFailed;
      }
    } on Object {
      message = text.accountSignInFailed;
    }
    await _load();
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    final String? email = _email;
    if (email != null) {
      return NardaCard(
        child: ListTile(
          leading: const Icon(Icons.verified_user, color: NardaColors.gold),
          title: Text(
            text.accountGoogleLinked,
            style: const TextStyle(color: NardaColors.textPrimary),
          ),
          subtitle: email.isEmpty
              ? null
              : Text(
                  email,
                  style: const TextStyle(color: NardaColors.textMuted),
                ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: _busy ? null : () => _signIn(text),
          icon: const Icon(Icons.login),
          label: Text(text.accountGoogleSignIn),
        ),
        const SizedBox(height: 8),
        NardaHint(text.accountGoogleHint),
      ],
    );
  }
}

/// Плашка рейтинга: сам рейтинг, сыгранные рейтинговые матчи и победы в них.
class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.profile});

  final ProfileController profile;

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    return NardaCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: <Widget>[
          Text(
            '${profile.rating}',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: NardaColors.gold,
            ),
          ),
          Text(
            text.profileRating,
            style: const TextStyle(color: NardaColors.textPrimary),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _counter(text.profileRatedGames, profile.ratedGames),
              _counter(text.statsWins, profile.ratedWins),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counter(String label, int value) => Column(
    children: <Widget>[
      Text(
        '$value',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: NardaColors.textPrimary,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: NardaColors.textMuted, fontSize: 13),
      ),
    ],
  );
}

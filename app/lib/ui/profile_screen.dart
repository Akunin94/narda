import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/gen/app_text.dart';
import '../online/online_backend.dart';
import '../profile/profile.dart';
import '../theme/narda_theme.dart';
import 'avatar.dart';
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
      appBar: AppBar(
        title: Text(text.profileTitle),
        backgroundColor: NardaColors.surface,
        foregroundColor: NardaColors.textPrimary,
      ),
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      LeaderboardScreen(backend: widget.backend),
                ),
              ),
              icon: const Icon(Icons.leaderboard_outlined),
              label: Text(text.leaderboardTitle),
            ),
            const SizedBox(height: 12),
            Text(
              text.profileRatingNote,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NardaColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: NardaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NardaColors.goldDeep),
      ),
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

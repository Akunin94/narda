import 'package:flutter/material.dart';

import '../../l10n/gen/app_text.dart';
import '../../online/firebase_backend.dart';
import '../../online/online_backend.dart';
import '../../online/protocol.dart';
import '../../theme/narda_theme.dart';
import '../avatar.dart';
import '../chrome.dart';
import 'online_failure.dart';

/// Таблица лидеров: верхушка общего рейтинга Elo (§P5).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.backend});

  /// Подменяется в тестах и превью на комнаты в памяти.
  final OnlineBackend? backend;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final bool _ownsBackend = widget.backend == null;
  late final OnlineBackend _backend = widget.backend ?? FirebaseOnlineBackend();

  List<RatingEntry>? _entries;
  OnlineFailure? _failure;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_ownsBackend) _backend.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final String uid = await _backend.signIn();
      final List<RatingEntry> entries = await _backend.leaderboard(limit: 50);
      if (!mounted) return;
      setState(() {
        _uid = uid;
        _entries = entries;
      });
    } on OnlineUnavailable catch (error) {
      if (mounted) setState(() => _failure = error.reason);
    } on Object {
      if (mounted) setState(() => _failure = OnlineFailure.network);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    return Scaffold(
      appBar: NardaAppBar(title: text.leaderboardTitle),
      body: SafeArea(child: _body(text)),
    );
  }

  Widget _body(AppText text) {
    final OnlineFailure? failure = _failure;
    if (failure != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            onlineFailureText(text, failure),
            textAlign: TextAlign.center,
            style: const TextStyle(color: NardaColors.gold),
          ),
        ),
      );
    }
    final List<RatingEntry>? entries = _entries;
    if (entries == null) {
      return const Center(
        child: CircularProgressIndicator(color: NardaColors.goldDeep),
      );
    }
    if (entries.isEmpty) {
      return Center(
        child: Text(
          text.leaderboardEmpty,
          style: const TextStyle(color: NardaColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) => _Row(
        place: index + 1,
        entry: entries[index],
        isMe: entries[index].uid == _uid,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.place, required this.entry, required this.isMe});

  final int place;
  final RatingEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NardaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? NardaColors.gold : Colors.transparent,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text(
              '$place',
              style: const TextStyle(
                color: NardaColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          NardaAvatar(index: entry.avatar, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '${entry.name} · ${text.leaderboardYou}' : entry.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: NardaColors.textPrimary),
            ),
          ),
          Text(
            '${entry.rating}',
            style: const TextStyle(
              color: NardaColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

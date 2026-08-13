import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:narda_core/narda_core.dart';

import '../../app.dart';
import '../../game/game_setup.dart';
import '../../game/settings.dart';
import '../../l10n/gen/app_text.dart';
import '../../online/firebase_backend.dart';
import '../../online/lobby_controller.dart';
import '../../online/online_backend.dart';
import '../../theme/narda_theme.dart';
import '../game_screen.dart';
import '../home_screen.dart';

/// Вход в онлайн: быстрый матч и приватная комната по 6-значному коду (§6).
class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key, this.backend});

  /// Подменяется в тестах и превью на комнаты в памяти.
  final OnlineBackend? backend;

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  late final LobbyController _lobby = LobbyController(
    backend: widget.backend ?? FirebaseOnlineBackend(),
  )..addListener(_onLobbyChanged);

  bool _opened = false;

  @override
  void dispose() {
    _lobby
      ..removeListener(_onLobbyChanged)
      ..dispose();
    super.dispose();
  }

  /// Соперник нашёлся — открываем доску и убираем лобби из стека.
  void _onLobbyChanged() {
    if (!mounted) return;
    setState(() {});
    final OnlineSession? session = _lobby.session;
    if (session == null || _opened) return;
    _opened = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            GameScreen(setup: session.setup, online: session.match),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    final SettingsController settings = SettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: NardaColors.background,
        title: Text(text.onlineTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: switch (_lobby.stage) {
            LobbyStage.waitingForOpponent => _waitingForCode(text),
            LobbyStage.searching => _searching(text, settings),
            LobbyStage.connecting => _busy(text.onlineConnecting),
            LobbyStage.ready => _busy(text.onlineConnecting),
            LobbyStage.idle || LobbyStage.failed => _menu(text, settings),
          },
        ),
      ),
    );
  }

  Widget _menu(AppText text, SettingsController settings) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 24),
    children: <Widget>[
      Text(
        text.matchTitle,
        style: const TextStyle(fontSize: 16, color: NardaColors.textMuted),
      ),
      const SizedBox(height: 10),
      AnimatedBuilder(
        animation: settings,
        builder: (BuildContext context, Widget? child) => MatchTargetPicker(
          value: settings.matchTarget,
          onChanged: (MatchTarget target) => settings.matchTarget = target,
        ),
      ),
      const SizedBox(height: 28),
      FilledButton(
        onPressed: () => _lobby.quickMatch(settings.matchTarget),
        child: Text(text.onlineQuickMatch),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => _lobby.createRoom(settings.matchTarget),
        child: Text(text.onlineCreateRoom),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => _askCode(text),
        child: Text(text.onlineJoinRoom),
      ),
      if (_lobby.failure != null) ...<Widget>[
        const SizedBox(height: 24),
        Text(
          _failureText(text, _lobby.failure!),
          textAlign: TextAlign.center,
          style: const TextStyle(color: NardaColors.gold),
        ),
      ],
      const SizedBox(height: 24),
      Text(
        text.onlineFairPlay,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: NardaColors.textMuted),
      ),
    ],
  );

  Widget _waitingForCode(AppText text) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      Text(
        text.onlineShareCode,
        textAlign: TextAlign.center,
        style: const TextStyle(color: NardaColors.textMuted),
      ),
      const SizedBox(height: 16),
      SelectableText(
        _lobby.code ?? '',
        style: const TextStyle(
          fontSize: 44,
          letterSpacing: 8,
          fontWeight: FontWeight.w700,
          color: NardaColors.gold,
        ),
      ),
      const SizedBox(height: 24),
      const CircularProgressIndicator(color: NardaColors.goldDeep),
      const SizedBox(height: 16),
      Text(
        text.onlineWaitingTitle,
        style: const TextStyle(color: NardaColors.textPrimary),
      ),
      const SizedBox(height: 32),
      OutlinedButton(
        onPressed: _lobby.cancel,
        child: Text(text.onlineCancelSearch),
      ),
    ],
  );

  Widget _searching(AppText text, SettingsController settings) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      const CircularProgressIndicator(color: NardaColors.goldDeep),
      const SizedBox(height: 20),
      Text(
        text.onlineSearching,
        style: const TextStyle(fontSize: 18, color: NardaColors.textPrimary),
      ),
      if (_lobby.botOfferVisible) ...<Widget>[
        const SizedBox(height: 28),
        Text(
          text.onlineBotOffer,
          textAlign: TextAlign.center,
          style: const TextStyle(color: NardaColors.textMuted),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => _playBot(settings),
          child: Text(text.menuPlayBot),
        ),
      ],
      const SizedBox(height: 32),
      OutlinedButton(
        onPressed: _lobby.cancel,
        child: Text(text.onlineCancelSearch),
      ),
    ],
  );

  Widget _busy(String label) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      const CircularProgressIndicator(color: NardaColors.goldDeep),
      const SizedBox(height: 20),
      Text(label, style: const TextStyle(color: NardaColors.textPrimary)),
    ],
  );

  /// Пока ищем — можно сыграть с ботом. Ботов за живых не выдаём (§6).
  Future<void> _playBot(SettingsController settings) async {
    await _lobby.cancel();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => GameScreen(
          setup: GameSetup.vsBot(
            settings.botLevel,
            target: settings.matchTarget,
          ),
        ),
      ),
    );
  }

  Future<void> _askCode(AppText text) async {
    final TextEditingController field = TextEditingController();
    final String? code = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: NardaColors.surface,
        title: Text(text.onlineJoinRoom),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(hintText: text.onlineCodeHint),
          style: const TextStyle(fontSize: 24, letterSpacing: 6),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(text.actionNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(field.text),
            child: Text(text.actionYes),
          ),
        ],
      ),
    );
    field.dispose();
    if (code != null && code.length == 6) await _lobby.joinByCode(code);
  }

  String _failureText(AppText text, OnlineFailure failure) => switch (failure) {
    OnlineFailure.notConfigured => text.onlineNotConfigured,
    OnlineFailure.network => text.onlineNetworkError,
    OnlineFailure.roomNotFound => text.onlineNoRoom,
    OnlineFailure.roomFull => text.onlineRoomFull,
  };
}

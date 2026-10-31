import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

import '../ads/ads_controller.dart';
import '../app.dart';
import '../game/feedback.dart';
import '../game/game_setup.dart';
import '../game/match_controller.dart';
import '../game/saved_game.dart';
import '../game/settings.dart';
import '../game/stats.dart';
import '../game/turn_coordinator.dart';
import '../l10n/gen/app_text.dart';
import '../online/online_match.dart';
import '../online/online_opponent.dart';
import '../online/rating_service.dart';
import '../online/voice_chat.dart';
import '../profile/profile.dart';
import '../theme/board_theme.dart';
import '../theme/narda_theme.dart';
import 'avatar.dart';
import 'board/board_view.dart';
import 'chrome.dart';
import 'dice_view.dart';
import 'online/online_status_bar.dart';
import 'online/phrase_bar.dart';
import 'overlay_card.dart';
import 'sheet.dart';

/// Экран партии: доска, кости, счёт серии и кнопки хода.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.setup,
    this.controller,
    this.online,
    this.rating,
    this.resume,
    this.score,
  });

  final GameSetup setup;

  /// Счёт серии при возврате в идущую онлайн-партию.
  final MatchScore? score;

  /// Прерванная партия с ботом, которую надо продолжить.
  final SavedBotGame? resume;

  /// Готовый контроллер — нужен тестам, чтобы подставить кости и соперника.
  final MatchController? controller;

  /// Сессия комнаты в онлайне: она же ведущий партии и источник таймера,
  /// presence и фраз (§6). `null` — оффлайн.
  final OnlineMatch? online;

  /// Пересчёт рейтинга Elo по итогу сетевого матча (§P5). `null` — оффлайн.
  final RatingService? rating;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final SettingsController _settings = SettingsScope.of(context);
  late final StatsStore _stats = StatsScope.of(context);
  late final AdsController _ads = AdsScope.of(context);
  late final ProfileController _profile = ProfileScope.of(context);

  /// Голос в онлайне; микрофон включается только кнопкой.
  late final VoiceChat? _voice = widget.online == null
      ? null
      : VoiceChat(widget.online!.room);

  /// Контроллер собирается лениво: настройки и реклама берутся из дерева,
  /// а к ним нельзя обращаться раньше, чем завершится initState.
  late final MatchController _controller =
      widget.controller ??
      MatchController(
        setup: widget.setup,
        settings: _settings,
        feedback: DeviceFeedback(_settings),
        onGameFinished: _recordGame,
        opponent: widget.online == null
            ? null
            : OnlineOpponent(widget.online!),
        coordinator: widget.online,
        resume: widget.resume,
        initialScore: widget.score,
      );

  bool get _isOnline => widget.setup.mode == GameMode.online;

  /// Оба игрока за этим устройством: подписи идут по цветам, а не «ты» и
  /// «соперник».
  bool get _isHotseat => widget.setup.mode == GameMode.hotseat;

  /// Идёт показ interstitial — доска на это время закрыта оверлеем.
  bool _switchingGame = false;

  bool _started = false;

  /// Рейтинг за матч начисляется один раз — до реванша (§P5).
  bool _ratingApplied = false;
  bool _rematchStarting = false;
  RatingChange? _ratingChange;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    widget.online?.addListener(_onOnlineChanged);
    WidgetsBinding.instance.addObserver(this);
    if (_isOnline) {
      _controller
        ..addListener(_rememberOnline)
        ..addListener(_scheduleAutoNext);
    }
    _controller.start();
  }

  /// Онлайн-серия сама переходит к следующей партии: иначе тот, кто нажал
  /// раньше, ждал бы соперника, который отвлёкся, без всякого таймера.
  static const int _autoNextSeconds = 10;
  Timer? _autoNext;
  int _autoNextLeft = 0;

  void _scheduleAutoNext() {
    final bool waiting =
        _controller.phase == TurnPhase.finished &&
        widget.setup.target != MatchTarget.single &&
        !_controller.isMatchOver;
    if (!waiting) {
      _autoNext?.cancel();
      _autoNext = null;
      return;
    }
    if (_autoNext != null) return;
    _autoNextLeft = _autoNextSeconds;
    _autoNext = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return timer.cancel();
      setState(() => _autoNextLeft--);
      if (_autoNextLeft <= 0) unawaited(_continue());
    });
  }

  /// Идущая онлайн-партия запоминается, чтобы вернуться в неё после
  /// перезапуска; доигранный матч и аннулированная партия — забываются.
  void _rememberOnline() {
    final OnlineMatch match = widget.online!;
    final bool done =
        _controller.phase == TurnPhase.aborted ||
        (_controller.phase == TurnPhase.finished && _controller.isMatchOver);
    final String? value = done
        ? null
        : SavedOnlineGame(
            match.room.roomId,
            widget.setup.localPlayer,
            _controller.score,
          ).encode();
    if (_settings.savedOnlineGame != value) _settings.savedOnlineGame = value;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(widget.online?.refresh());
  }

  @override
  void dispose() {
    _autoNext?.cancel();
    _controller
      ..removeListener(_rememberOnline)
      ..removeListener(_scheduleAutoNext);
    widget.online?.removeListener(_onOnlineChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (widget.online != null) _voice?.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Итог партии: статистика (только против бота), рейтинг (только в онлайне)
  /// и счётчик рекламы.
  void _recordGame(GameResult result) {
    _ads.noteGameFinished();
    if (_isOnline) {
      unawaited(_applyRating());
      return;
    }
    if (widget.setup.mode != GameMode.bot) return;
    _stats.recordGame(result, local: widget.setup.localPlayer);
    if (_controller.isMatchOver && widget.setup.target != MatchTarget.single) {
      _stats.recordMatch(
        won: _controller.score.winner == widget.setup.localPlayer,
      );
    }
  }

  /// Elo считается по итогу матча целиком, а не каждой партии серии (§P5).
  Future<void> _applyRating() async {
    final RatingService? rating = widget.rating;
    final OnlineMatch? match = widget.online;
    if (rating == null || match == null) return;
    if (_ratingApplied || !_controller.isMatchOver) return;
    _ratingApplied = true;
    final RatingChange change = await rating.applyMatch(
      opponentRating: match.opponentRating,
      won: _controller.score.winner == widget.setup.localPlayer,
    );
    if (mounted) setState(() => _ratingChange = change);
  }

  /// Реванш начинается, только когда его подтвердили оба (§P5).
  void _onOnlineChanged() {
    final OnlineMatch? match = widget.online;
    if (match == null || !mounted) return;
    if (!match.rematchAgreed) {
      _rematchStarting = false;
      return;
    }
    if (_rematchStarting || !_controller.isMatchOver) return;
    _rematchStarting = true;
    setState(() {
      _ratingApplied = false;
      _ratingChange = null;
    });
    _controller.newMatch();
  }

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    final BoardTheme theme = _settings.boardTheme;
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable?>[
            _controller,
            _settings,
            widget.online,
          ]),
          builder: (BuildContext context, Widget? child) => Stack(
            children: <Widget>[
              if (MediaQuery.orientationOf(context) == Orientation.landscape)
                _buildLandscape(text, theme)
              else
                _buildPortrait(text, theme),
              // Фраза соперника — всплывашкой поверх доски, раскладку не двигает.
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: switch (widget.online?.opponentPhrase) {
                      final String phrase => PhraseBubble(
                        key: ValueKey<String>(phrase),
                        phrase: phrase,
                      ),
                      null => const SizedBox.shrink(),
                    },
                  ),
                ),
              ),
              if (widget.online case final OnlineMatch match
                  when match.incomingOffer != null && !_controller.isOver)
                Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  child: _buildOfferCard(text, match),
                ),
              if (_controller.phase == TurnPhase.finished && !_switchingGame)
                Positioned.fill(child: _buildResultOverlay(text)),
              if (_controller.phase == TurnPhase.aborted)
                Positioned.fill(child: _buildAbortOverlay(text)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortrait(AppText text, BoardTheme theme) => Column(
    children: <Widget>[
      _buildTopBar(text),
      if (_isOnline)
        OnlineStatusBar(
          match: widget.online!,
          isOver: _controller.isOver,
          voice: _voice,
        ),
      _buildPlayerStrip(text, theme, _controller.perspective.opponent),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Center(child: _boardBox(child: _buildBoard(theme))),
        ),
      ),
      _buildPlayerStrip(text, theme, _controller.perspective),
      _buildActionBar(text),
    ],
  );

  /// Альбом: доска слева во всю высоту, справа — панель с игроками и кнопками.
  Widget _buildLandscape(AppText text, BoardTheme theme) => Row(
    children: <Widget>[
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Center(
            child: _boardBox(landscape: true, child: _buildBoard(theme)),
          ),
        ),
      ),
      SizedBox(
        width: 240,
        child: AdaptiveColumn(
          tallHeight: 360,
          children: (Widget Function(int flex) gap) => <Widget>[
            _buildTopBar(text),
            if (_isOnline)
              OnlineStatusBar(
                match: widget.online!,
                isOver: _controller.isOver,
                voice: _voice,
              ),
            _buildPlayerStrip(
              text,
              theme,
              _controller.perspective.opponent,
              compact: true,
            ),
            gap(1),
            _buildPlayerStrip(
              text,
              theme,
              _controller.perspective,
              compact: true,
            ),
            _buildActionBar(text, compact: true),
          ],
        ),
      ),
    ],
  );

  Widget _buildBoard(BoardTheme theme) => BoardView(
    state: _controller.state,
    theme: theme,
    perspective: _controller.perspective,
    selected: _controller.selected,
    destinations: _controller.destinations,
    chained: _controller.chainedDestinations,
    movable: _controller.movableSources.toSet(),
    lastMoves: _controller.lastTurnMoves,
    animated: _controller.animated,
    interactive: _controller.canInteract,
    moveDuration: _controller.timing.move,
    onTapPoint: _controller.tapPoint,
    onTapTray: _controller.tapBearOff,
    onDragStart: _controller.beginDrag,
    onDrop: (int fromAbs, int? toAbs) =>
        _controller.drop(fromAbs: fromAbs, toAbs: toAbs),
  );

  Widget _buildAbortOverlay(AppText text) => ModalOverlay(
    title: text.onlineAborted,
    titleSize: 20,
    children: <Widget>[
      const SizedBox(height: 8),
      Text(
        switch (_controller.abortReason) {
          MatchAbortReason.desync => text.onlineAbortedDesync,
          MatchAbortReason.connection || null => text.onlineAbortedConnection,
        },
        textAlign: TextAlign.center,
        style: const TextStyle(color: NardaColors.textMuted),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(text.actionMenu),
      ),
    ],
  );

  /// Портрет: доска во всю высоту, но не уже 0.62 ширины к высоте.
  /// Альбом: во всю высоту, но не шире 1.7 высоты.
  Widget _boardBox({required Widget child, bool landscape = false}) =>
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => SizedBox(
          width: landscape
              ? math.min(constraints.maxWidth, constraints.maxHeight * 1.7)
              : constraints.maxWidth,
          height: landscape
              ? constraints.maxHeight
              : math.min(constraints.maxHeight, constraints.maxWidth / 0.62),
          child: child,
        ),
      );

  Widget _buildTopBar(AppText text) => Row(
    children: <Widget>[
      IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back),
        color: NardaColors.textMuted,
      ),
      Expanded(
        child: Column(
          children: <Widget>[
            Text(
              _statusText(text),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: NardaColors.textPrimary,
              ),
            ),
            if (widget.setup.target != MatchTarget.single)
              Text(
                '${_scoreLine(text)}'
                ' · ${text.matchToPoints(widget.setup.target.points)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: NardaColors.textMuted,
                ),
              ),
          ],
        ),
      ),
      IconButton(
        onPressed: _controller.isOver ? null : () => _confirmResign(text),
        icon: const Icon(Icons.flag_outlined),
        tooltip: text.actionResign,
        color: NardaColors.textMuted,
      ),
    ],
  );

  /// [compact] — узкая панель альбома: кубики уходят на вторую строку,
  /// иначе дубль из четырёх кубиков не влезает в ширину.
  Widget _buildPlayerStrip(
    AppText text,
    BoardTheme theme,
    Player player, {
    bool compact = false,
  }) {
    final GameState state = _controller.state;
    final bool active = state.turn == player;
    final Widget? dice = active && !_controller.isOver && !_controller.rollSkipped
        ? DiceView(
            roll: state.roll,
            remaining: state.remainingDice,
            rolling: _controller.phase == TurnPhase.rolling,
            theme: theme,
          )
        : null;
    final List<Widget> identity = <Widget>[
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.checkerFace(player),
          border: Border.all(color: theme.checkerEdge(player)),
        ),
      ),
      const SizedBox(width: 8),
      // В онлайне рядом с именем стоит аватар из профиля (§P5).
      if (_isOnline) ...<Widget>[
        NardaAvatar(index: _avatarOf(player), size: 20),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          _playerName(text, player),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: NardaColors.textPrimary,
          ),
        ),
      ),
      const SizedBox(width: 10),
      if (_settings.showPips)
        Text(
          '${state.pipCount(player)} ${text.labelPip}',
          style: const TextStyle(color: NardaColors.textMuted, fontSize: 13),
        ),
    ];
    final Widget? borneOff = state.borneOff(player) > 0
        ? Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              '${state.borneOff(player)} ${text.labelBorneOff}',
              style: const TextStyle(
                color: NardaColors.textMuted,
                fontSize: 13,
              ),
            ),
          )
        : null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NardaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? NardaColors.gold : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: compact
          ? Column(
              children: <Widget>[
                Row(children: identity),
                if (borneOff != null || dice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: <Widget>[
                        ?borneOff,
                        const Spacer(),
                        ?dice,
                      ],
                    ),
                  ),
              ],
            )
          : Row(
              children: <Widget>[
                ...identity,
                const Spacer(),
                ?borneOff,
                ?dice,
              ],
            ),
    );
  }

  /// [compact] — панель альбома: «отменить» только иконкой, без подписи.
  Widget _buildActionBar(AppText text, {bool compact = false}) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
    child: Row(
      children: <Widget>[
        if (compact)
          IconButton.outlined(
            onPressed: _controller.canUndo ? _controller.undo : null,
            icon: const Icon(Icons.undo),
            tooltip: text.actionUndo,
          )
        else
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _controller.canUndo ? _controller.undo : null,
              icon: const Icon(Icons.undo),
              label: Text(text.actionUndo),
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: _controller.canConfirm ? _controller.confirm : null,
            icon: const Icon(Icons.check),
            // В узкой панели альбома подпись ужимается, а не переносится.
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _controller.movesRequired > 0 && !_controller.canConfirm
                    ? '${_controller.movesPlayed}/${_controller.movesRequired}'
                    : text.actionConfirm,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildResultOverlay(AppText text) {
    final GameResult result = _controller.result!;
    final bool series = widget.setup.target != MatchTarget.single;
    final bool matchOver = _controller.isMatchOver;
    return ModalOverlay(
      title: series && matchOver
          ? _matchTitle(text)
          : _resultTitle(text, result),
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          _resultSubtitle(text, result),
          textAlign: TextAlign.center,
          style: const TextStyle(color: NardaColors.textMuted),
        ),
        if (series) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            _scoreLine(text, separator: ' : '),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: NardaColors.textPrimary,
            ),
          ),
        ],
        if (_ratingChange case final RatingChange change) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            text.ratingResult(change.after, _signed(change.delta)),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: NardaColors.textPrimary,
            ),
          ),
        ],
        const SizedBox(height: 20),
        ..._resultActions(text, series: series, matchOver: matchOver),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(text.actionMenu),
        ),
      ],
    );
  }

  /// Кнопки под итогом. В онлайне доигранный матч продолжается только
  /// реваншем по обоюдному согласию: соперник не должен обнаружить себя в
  /// новой серии, о которой не просил (§P5).
  List<Widget> _resultActions(
    AppText text, {
    required bool series,
    required bool matchOver,
  }) {
    final OnlineMatch? match = widget.online;
    if (match != null && matchOver) {
      return <Widget>[
        if (match.rematchRequestedByOpponent && !match.rematchRequestedByMe)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              text.rematchOffered,
              textAlign: TextAlign.center,
              style: const TextStyle(color: NardaColors.gold),
            ),
          ),
        FilledButton(
          onPressed: match.rematchRequestedByMe
              ? null
              : () => unawaited(match.requestRematch()),
          child: Text(
            match.rematchRequestedByMe
                ? text.rematchWaiting
                : text.actionRematchOnline,
          ),
        ),
      ];
    }
    return <Widget>[
      FilledButton(
        onPressed: _continue,
        child: Text(
          series && !matchOver
              ? (_autoNext == null
                    ? text.actionNextGame
                    : '${text.actionNextGame} ($_autoNextLeft)')
              : series
              ? text.actionNewMatch
              : text.actionRematch,
        ),
      ),
    ];
  }

  String _signed(int delta) => delta >= 0 ? '+$delta' : '$delta';

  /// Переход к следующей партии. Interstitial показывается **здесь** — между
  /// партиями и никогда во время партии (§P3). В онлайне его нет вовсе:
  /// соперник не должен ждать чужой ролик.
  Future<void> _continue() async {
    _autoNext?.cancel();
    _autoNext = null;
    final bool startNewMatch =
        widget.setup.target != MatchTarget.single && _controller.isMatchOver;
    setState(() => _switchingGame = true);
    if (!_isOnline) await _ads.maybeShowInterstitial();
    if (!mounted) return;
    setState(() => _switchingGame = false);
    if (startNewMatch) {
      _controller.newMatch();
    } else {
      _controller.nextGame();
    }
  }

  /// Сдача: марс (2 очка) — сразу, обычная (1 очко) — с согласия соперника.
  Future<void> _confirmResign(AppText text) async {
    // Шашка уже выброшена — марса нет, выбирать не из чего.
    if (_controller.resignationIsSingle) {
      if (await confirmAction(context, text.resignQuestion)) {
        _controller.resign();
      }
      return;
    }
    final bool? mars = await showNardaSheet<bool>(
      context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            NardaSheetTitle(text.resignQuestion),
            for (final (bool value, String title, String hint)
                in <(bool, String, String)>[
                  (true, text.resignMars, text.resignMarsHint),
                  (false, text.resignSingle, text.resignSingleHint),
                ])
              ListTile(
                title: Text(
                  title,
                  style: const TextStyle(color: NardaColors.textPrimary),
                ),
                subtitle: Text(
                  hint,
                  style: const TextStyle(color: NardaColors.textMuted),
                ),
                onTap: () => Navigator.of(context).pop(value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mars == null || !mounted) return;
    if (mars) {
      _controller.resign();
      return;
    }
    // В hotseat отвечает второй игрок прямо на этом экране.
    if (_isHotseat && !await confirmAction(context, text.resignOfferIncoming)) {
      if (mounted) _snack(text.resignOfferDeclined);
      return;
    }
    if (_isOnline) _snack(text.resignOfferWaiting);
    final bool accepted = await _controller.offerResignation();
    if (!accepted && mounted) _snack(text.resignOfferDeclined);
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// Соперник по сети предлагает сдаться на 1 очко — принять или отказать.
  Widget _buildOfferCard(AppText text, OnlineMatch match) => Card(
    color: NardaColors.surfaceHigh,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: NardaColors.goldDeep),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            text.resignOfferIncoming,
            style: const TextStyle(color: NardaColors.textPrimary),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => unawaited(match.declineOffer()),
                child: Text(text.resignOfferDecline),
              ),
              TextButton(
                onPressed: () => unawaited(match.acceptOffer()),
                child: Text(text.resignOfferAccept),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  String _statusText(AppText text) => switch (_controller.phase) {
    TurnPhase.rolling => text.statusRolling,
    TurnPhase.thinking => _isOnline
        ? text.onlineOpponentTurn
        : text.statusThinking,
    TurnPhase.noMoves => text.statusNoMoves,
    TurnPhase.finished => _resultTitle(text, _controller.result!),
    TurnPhase.aborted => text.onlineAborted,
    TurnPhase.choosing =>
      _controller.canConfirm
          ? text.statusConfirmTurn
          : _turnText(text, _controller.state.turn),
  };

  /// Счёт серии глазами локального игрока: его очки всегда слева.
  String _scoreLine(AppText text, {String separator = ':'}) =>
      '${text.labelScore} '
      '${_controller.score.pointsOf(widget.setup.localPlayer)}'
      '$separator'
      '${_controller.score.pointsOf(widget.setup.opponentPlayer)}';

  String _turnText(AppText text, Player player) {
    if (_isHotseat) {
      return player == Player.white
          ? text.statusWhiteTurn
          : text.statusBlackTurn;
    }
    return text.statusYourTurn;
  }

  int _avatarOf(Player player) => player == widget.setup.localPlayer
      ? _profile.avatar
      : (widget.online?.opponentAvatar ?? 0);

  String _playerName(AppText text, Player player) {
    final String side = player == Player.white
        ? text.sideWhite
        : text.sideBlack;
    // В онлайне игрок подписан своим ником из профиля (§P5).
    if (player == widget.setup.localPlayer) return _isOnline ? _profile.name : side;
    if (widget.setup.mode == GameMode.bot) {
      return 'Bot · ${_levelName(text, widget.setup.botLevel ?? BotLevel.orta)}';
    }
    if (_isOnline) {
      final String name = widget.online?.opponentName ??
          widget.setup.opponentName ??
          '';
      return name.isEmpty ? text.onlineOpponentLabel : name;
    }
    return side;
  }

  String _levelName(AppText text, BotLevel level) => switch (level) {
    BotLevel.oson => text.levelOson,
    BotLevel.orta => text.levelOrta,
    BotLevel.kuchli => text.levelKuchli,
  };

  String _resultTitle(AppText text, GameResult result) {
    if (_isHotseat) {
      return result.winner == Player.white
          ? text.resultWhiteWins
          : text.resultBlackWins;
    }
    return result.winner == widget.setup.localPlayer
        ? text.resultYouWin
        : text.resultYouLose;
  }

  String _matchTitle(AppText text) {
    final Player? winner = _controller.score.winner;
    if (_isHotseat) {
      return winner == Player.white ? text.matchWhiteWins : text.matchBlackWins;
    }
    return winner == widget.setup.localPlayer
        ? text.matchWonTitle
        : text.matchLostTitle;
  }

  String _resultSubtitle(AppText text, GameResult result) {
    final String points = result.isMars ? text.resultMars : text.resultOyin;
    return result.byResignation ? '$points · ${text.resultByResign}' : points;
  }
}

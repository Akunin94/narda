import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

import '../ads/ads_controller.dart';
import '../app.dart';
import '../game/feedback.dart';
import '../game/game_setup.dart';
import '../game/match_controller.dart';
import '../game/settings.dart';
import '../game/stats.dart';
import '../game/turn_coordinator.dart';
import '../l10n/gen/app_text.dart';
import '../online/online_match.dart';
import '../online/online_opponent.dart';
import '../online/rating_service.dart';
import '../profile/profile.dart';
import '../theme/board_theme.dart';
import '../theme/narda_theme.dart';
import 'avatar.dart';
import 'board/board_view.dart';
import 'dice_view.dart';
import 'online/phrase_bar.dart';

/// Экран партии: доска, кости, счёт серии и кнопки хода.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.setup,
    this.controller,
    this.online,
    this.rating,
  });

  final GameSetup setup;

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

class _GameScreenState extends State<GameScreen> {
  late final SettingsController _settings = SettingsScope.of(context);
  late final StatsStore _stats = StatsScope.of(context);
  late final AdsController _ads = AdsScope.of(context);
  late final ProfileController _profile = ProfileScope.of(context);

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
      );

  bool get _isOnline => widget.setup.mode == GameMode.online;

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
    _controller.start();
  }

  @override
  void dispose() {
    widget.online?.removeListener(_onOnlineChanged);
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
              Column(
                children: <Widget>[
                  _buildTopBar(text),
                  if (_isOnline) _buildOnlineBar(text),
                  _buildPlayerStrip(text, theme, _controller.perspective.opponent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Center(
                        child: _boardBox(
                          child: BoardView(
                            state: _controller.state,
                            theme: theme,
                            perspective: _controller.perspective,
                            selected: _controller.selected,
                            destinations: _controller.destinations,
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
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildPlayerStrip(text, theme, _controller.perspective),
                  _buildActionBar(text),
                ],
              ),
              if (_controller.phase == TurnPhase.finished && !_switchingGame)
                _buildResultOverlay(text),
              if (_controller.phase == TurnPhase.aborted)
                _buildAbortOverlay(text),
            ],
          ),
        ),
      ),
    );
  }

  /// Полоска онлайна: реплика соперника, связь, таймер хода и клейм (§6).
  Widget _buildOnlineBar(AppText text) {
    final OnlineMatch match = widget.online!;
    final Duration? left = match.turnRemaining;
    final String? phrase = match.opponentPhrase;
    return Column(
      children: <Widget>[
        if (phrase != null) PhraseBubble(phrase: phrase),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              Icon(
                match.opponentOnline ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: match.opponentOnline
                    ? NardaColors.textMuted
                    : NardaColors.gold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  match.opponentOnline
                      ? match.opponentName
                      : text.onlineOpponentOffline,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NardaColors.textMuted,
                  ),
                ),
              ),
              if (match.canClaimWin && !_controller.isOver)
                TextButton(
                  onPressed: () => unawaited(match.claimWin()),
                  child: Text(
                    text.onlineClaimWin,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (left != null && !_controller.isOver)
                Text(
                  text.onlineSecondsLeft(left.inSeconds),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: left.inSeconds <= 10
                        ? NardaColors.gold
                        : NardaColors.textMuted,
                  ),
                ),
              IconButton(
                onPressed: () => showPhraseSheet(
                  context,
                  onSend: (String phrase) => unawaited(match.sendPhrase(phrase)),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                color: NardaColors.textMuted,
                tooltip: text.onlinePhrasesTitle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAbortOverlay(AppText text) => Positioned.fill(
    child: ColoredBox(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: NardaColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NardaColors.goldDeep),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                text.onlineAborted,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: NardaColors.gold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                switch (_controller.abortReason) {
                  MatchAbortReason.desync => text.onlineAbortedDesync,
                  MatchAbortReason.connection || null =>
                    text.onlineAbortedConnection,
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
          ),
        ),
      ),
    ),
  );

  /// Доска занимает всю доступную высоту, но не вытягивается уже,
  /// чем 0.62 ширины к высоте.
  Widget _boardBox({required Widget child}) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) => SizedBox(
      width: constraints.maxWidth,
      height: math.min(constraints.maxHeight, constraints.maxWidth / 0.62),
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
                '${text.labelScore} '
                '${_controller.score.pointsOf(widget.setup.localPlayer)}:'
                '${_controller.score.pointsOf(widget.setup.opponentPlayer)}'
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

  Widget _buildPlayerStrip(AppText text, BoardTheme theme, Player player) {
    final GameState state = _controller.state;
    final bool active = state.turn == player;
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
      child: Row(
        children: <Widget>[
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
          Text(
            _playerName(text, player),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: NardaColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          if (_settings.showPips)
            Text(
              '${state.pipCount(player)} ${text.labelPip}',
              style: const TextStyle(color: NardaColors.textMuted, fontSize: 13),
            ),
          const Spacer(),
          if (state.borneOff(player) > 0)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '${state.borneOff(player)} ${text.labelBorneOff}',
                style: const TextStyle(
                  color: NardaColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          if (active && !_controller.isOver)
            DiceView(
              roll: state.roll,
              remaining: state.remainingDice,
              rolling: _controller.phase == TurnPhase.rolling,
              theme: theme,
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(AppText text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
    child: Row(
      children: <Widget>[
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
            label: Text(
              _controller.movesRequired > 0 && !_controller.canConfirm
                  ? '${_controller.movesPlayed}/${_controller.movesRequired}'
                  : text.actionConfirm,
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
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: NardaColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NardaColors.goldDeep),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  series && matchOver
                      ? _matchTitle(text)
                      : _resultTitle(text, result),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: NardaColors.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _resultSubtitle(text, result),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NardaColors.textMuted),
                ),
                if (series) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    '${text.labelScore} '
                    '${_controller.score.pointsOf(widget.setup.localPlayer)}'
                    ' : '
                    '${_controller.score.pointsOf(widget.setup.opponentPlayer)}',
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
            ),
          ),
        ),
      ),
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
              ? text.actionNextGame
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

  Future<void> _confirmResign(AppText text) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: NardaColors.surface,
        content: Text(text.resignQuestion),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(text.actionNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(text.actionYes),
          ),
        ],
      ),
    );
    if (confirmed ?? false) _controller.resign();
  }

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

  String _turnText(AppText text, Player player) {
    if (widget.setup.mode == GameMode.hotseat) {
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
    if (widget.setup.mode == GameMode.hotseat) {
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
    if (widget.setup.mode == GameMode.hotseat) {
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

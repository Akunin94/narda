import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

import '../game/game_setup.dart';
import '../game/match_controller.dart';
import '../game/settings.dart';
import '../l10n/gen/app_text.dart';
import '../theme/narda_theme.dart';
import 'board/board_view.dart';
import 'dice_view.dart';

/// Экран партии: доска, кости, счёт и кнопки хода.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.setup,
    required this.settings,
    this.controller,
  });

  final GameSetup setup;
  final SettingsController settings;

  /// Готовый контроллер — нужен тестам, чтобы подставить кости и соперника.
  final MatchController? controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final MatchController _controller =
      widget.controller ??
      MatchController(setup: widget.setup, settings: widget.settings);

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_controller, widget.settings]),
          builder: (BuildContext context, Widget? child) => Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  _buildTopBar(text),
                  _buildPlayerStrip(text, _controller.perspective.opponent),
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
                  _buildPlayerStrip(text, _controller.perspective),
                  _buildActionBar(text),
                ],
              ),
              if (_controller.phase == TurnPhase.finished)
                _buildResultOverlay(text),
            ],
          ),
        ),
      ),
    );
  }

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
        child: Text(
          _statusText(text),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: NardaColors.textPrimary,
          ),
        ),
      ),
      IconButton(
        onPressed: _controller.phase == TurnPhase.finished
            ? null
            : () => _confirmResign(text),
        icon: const Icon(Icons.flag_outlined),
        tooltip: text.actionResign,
        color: NardaColors.textMuted,
      ),
    ],
  );

  Widget _buildPlayerStrip(AppText text, Player player) {
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
              color: NardaColors.checkerFace(player),
              border: Border.all(color: NardaColors.checkerEdge(player)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _playerName(text, player),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: NardaColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          if (widget.settings.showPips)
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
          if (active && _controller.phase != TurnPhase.finished)
            DiceView(
              roll: state.roll,
              remaining: state.remainingDice,
              rolling: _controller.phase == TurnPhase.rolling,
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
                  _resultTitle(text, result),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: NardaColors.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _resultSubtitle(text, result),
                  style: const TextStyle(color: NardaColors.textMuted),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _controller.rematch,
                  child: Text(text.actionRematch),
                ),
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
    TurnPhase.thinking => text.statusThinking,
    TurnPhase.noMoves => text.statusNoMoves,
    TurnPhase.finished => _resultTitle(text, _controller.result!),
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

  String _playerName(AppText text, Player player) {
    final String side = player == Player.white
        ? text.sideWhite
        : text.sideBlack;
    if (widget.setup.mode == GameMode.bot && player != widget.setup.localPlayer) {
      return 'Bot · ${_levelName(text, widget.setup.botLevel ?? BotLevel.orta)}';
    }
    return side;
  }

  String _levelName(AppText text, BotLevel level) => switch (level) {
    BotLevel.oson => text.levelOson,
    BotLevel.orta => text.levelOrta,
    BotLevel.kuchli => text.levelKuchli,
  };

  String _resultTitle(AppText text, GameResult result) {
    if (widget.setup.mode == GameMode.bot) {
      return result.winner == widget.setup.localPlayer
          ? text.resultYouWin
          : text.resultYouLose;
    }
    return result.winner == Player.white
        ? text.resultWhiteWins
        : text.resultBlackWins;
  }

  String _resultSubtitle(AppText text, GameResult result) {
    final String points = result.isMars ? text.resultMars : text.resultOyin;
    return result.byResignation ? '$points · ${text.resultByResign}' : points;
  }
}

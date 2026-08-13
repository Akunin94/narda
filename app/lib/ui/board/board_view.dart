import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

import '../../game/match_controller.dart';
import '../../theme/board_theme.dart';
import 'board_geometry.dart';
import 'board_painter.dart';

/// Доска: рисование, тап по шашке с подсветкой назначений, перетаскивание и
/// анимация перемещений.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.state,
    required this.theme,
    required this.perspective,
    required this.selected,
    required this.destinations,
    required this.movable,
    required this.lastMoves,
    required this.animated,
    required this.interactive,
    required this.onTapPoint,
    required this.onTapTray,
    required this.onDragStart,
    required this.onDrop,
    this.moveDuration = const Duration(milliseconds: 260),
  });

  final GameState state;
  final BoardTheme theme;
  final Player perspective;
  final int? selected;
  final List<int?> destinations;
  final Set<int> movable;
  final List<Move> lastMoves;
  final AnimatedMove? animated;
  final bool interactive;
  final Duration moveDuration;

  final ValueChanged<int> onTapPoint;
  final VoidCallback onTapTray;
  final ValueChanged<int> onDragStart;
  final void Function(int fromAbs, int? toAbs) onDrop;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.moveDuration,
  )..addStatusListener(_onAnimationStatus);

  Move? _flying;
  int _shownSerial = 0;
  int? _dragFrom;
  Offset? _dragPosition;

  @override
  void initState() {
    super.initState();
    _shownSerial = widget.animated?.serial ?? 0;
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final AnimatedMove? animated = widget.animated;
    if (animated == null) {
      _flying = null;
      return;
    }
    if (animated.serial == _shownSerial) return;
    _shownSerial = animated.serial;
    if (widget.moveDuration <= Duration.zero) {
      _flying = null;
      return;
    }
    _flying = animated.move;
    _controller
      ..duration = widget.moveDuration
      ..forward(from: 0);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _flying = null);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Size size = constraints.biggest;
      final BoardGeometry geometry = BoardGeometry(
        size: size,
        perspective: widget.perspective,
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (TapUpDetails details) =>
            _handleTap(geometry, details.localPosition),
        onPanStart: (DragStartDetails details) =>
            _handlePanStart(geometry, details.localPosition),
        onPanUpdate: (DragUpdateDetails details) {
          if (_dragFrom == null) return;
          setState(() => _dragPosition = details.localPosition);
        },
        onPanEnd: (DragEndDetails details) => _handlePanEnd(geometry),
        onPanCancel: _cancelDrag,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                painter: BoardBackgroundPainter(
                  geometry: geometry,
                  theme: widget.theme,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) => CustomPaint(
                painter: BoardPiecesPainter(
                  geometry: geometry,
                  theme: widget.theme,
                  state: widget.state,
                  selected: widget.selected,
                  destinations: widget.destinations,
                  movable: widget.movable,
                  lastMoves: widget.lastMoves,
                  flying: _flying,
                  progress: Curves.easeInOut.transform(_controller.value),
                  dragFrom: _dragFrom,
                  dragPosition: _dragPosition,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  void _handleTap(BoardGeometry geometry, Offset position) {
    if (!widget.interactive) return;
    final int? abs = geometry.pointAt(position);
    if (abs != null) {
      widget.onTapPoint(abs);
      return;
    }
    if (geometry.trayHit(position, widget.state.turn)) widget.onTapTray();
  }

  void _handlePanStart(BoardGeometry geometry, Offset position) {
    if (!widget.interactive) return;
    final int? abs = geometry.pointAt(position);
    if (abs == null || !widget.movable.contains(abs)) return;
    widget.onDragStart(abs);
    setState(() {
      _dragFrom = abs;
      _dragPosition = position;
    });
  }

  void _handlePanEnd(BoardGeometry geometry) {
    final int? from = _dragFrom;
    final Offset? position = _dragPosition;
    _cancelDrag();
    if (from == null || position == null) return;
    final int? target = geometry.pointAt(position);
    if (target != null) {
      widget.onDrop(from, target);
      return;
    }
    if (geometry.trayHit(position, widget.state.turn)) {
      widget.onDrop(from, null);
    }
  }

  void _cancelDrag() {
    if (_dragFrom == null && _dragPosition == null) return;
    setState(() {
      _dragFrom = null;
      _dragPosition = null;
    });
  }
}

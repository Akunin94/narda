import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

import '../theme/board_theme.dart';

/// Кости хода: два числа обычного броска или четыре при дубле.
/// Уже сыгранные числа гаснут, во время броска кости «крутятся».
class DiceView extends StatefulWidget {
  const DiceView({
    super.key,
    required this.roll,
    required this.remaining,
    required this.rolling,
    required this.theme,
    this.dieSize = 30,
  });

  final DiceRoll roll;
  final List<int> remaining;
  final bool rolling;
  final BoardTheme theme;
  final double dieSize;

  @override
  State<DiceView> createState() => _DiceViewState();
}

class _DiceViewState extends State<DiceView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    if (widget.rolling) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(DiceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rolling && !oldWidget.rolling) _controller.forward(from: 0);
    if (!widget.rolling && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Какие числа броска ещё не сыграны.
  List<bool> _availability() {
    final List<int> pool = List<int>.of(widget.remaining);
    return <bool>[
      for (final int die in widget.roll.toRemaining()) pool.remove(die),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<int> faces = widget.roll.toRemaining();
    final List<bool> available = _availability();
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final bool spinning = widget.rolling && _controller.value < 1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < faces.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: CustomPaint(
                  size: Size.square(widget.dieSize),
                  painter: _DiePainter(
                    value: spinning
                        ? _spinFace(i, _controller.value)
                        : faces[i],
                    dimmed: !spinning && !available[i],
                    theme: widget.theme,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Мелькающее значение во время броска.
  int _spinFace(int index, double t) =>
      1 + (((t * 16).floor() * 7) + index * 3) % 6;
}

class _DiePainter extends CustomPainter {
  const _DiePainter({
    required this.value,
    required this.dimmed,
    required this.theme,
  });

  final int value;
  final bool dimmed;
  final BoardTheme theme;

  /// Точки граней в долях стороны кубика.
  static const Map<int, List<Offset>> _pips = <int, List<Offset>>{
    1: <Offset>[Offset(0.5, 0.5)],
    2: <Offset>[Offset(0.3, 0.3), Offset(0.7, 0.7)],
    3: <Offset>[Offset(0.28, 0.28), Offset(0.5, 0.5), Offset(0.72, 0.72)],
    4: <Offset>[
      Offset(0.3, 0.3),
      Offset(0.7, 0.3),
      Offset(0.3, 0.7),
      Offset(0.7, 0.7),
    ],
    5: <Offset>[
      Offset(0.28, 0.28),
      Offset(0.72, 0.28),
      Offset(0.5, 0.5),
      Offset(0.28, 0.72),
      Offset(0.72, 0.72),
    ],
    6: <Offset>[
      Offset(0.3, 0.24),
      Offset(0.7, 0.24),
      Offset(0.3, 0.5),
      Offset(0.7, 0.5),
      Offset(0.3, 0.76),
      Offset(0.7, 0.76),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final double opacity = dimmed ? 0.3 : 1;
    final Rect rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(size.width * 0.2)),
      Paint()..color = theme.dieFace.withValues(alpha: opacity),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(size.width * 0.2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = theme.dieEdge.withValues(alpha: opacity),
    );
    final Paint pip = Paint()
      ..color = theme.diePip.withValues(alpha: opacity);
    for (final Offset point in _pips[value] ?? const <Offset>[]) {
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        size.width * 0.085,
        pip,
      );
    }
  }

  @override
  bool shouldRepaint(_DiePainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.dimmed != dimmed ||
      oldDelegate.theme.id != theme.id;
}

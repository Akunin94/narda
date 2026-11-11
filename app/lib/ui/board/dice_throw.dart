import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

import '../../theme/board_theme.dart';
import '../dice_view.dart';

/// Бросок костей на доску: два кубика влетают со стороны ходящего,
/// кувыркаются в 3D, отскакивают и показывают выпавшее. Только анимация:
/// числа хода по-прежнему в полосе игрока.
class DiceThrow extends StatefulWidget {
  const DiceThrow({
    super.key,
    required this.roll,
    required this.throwId,
    required this.fromBottom,
    required this.theme,
  });

  /// Что выпало; `null` — бросать нечего (бросок ещё не известен или прошёл).
  final DiceRoll? roll;

  /// Номер хода: новый номер — новый бросок.
  final int throwId;

  /// Ходящий сидит снизу доски.
  final bool fromBottom;
  final BoardTheme theme;

  @override
  State<DiceThrow> createState() => _DiceThrowState();
}

class _DiceThrowState extends State<DiceThrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  DiceRoll? _roll;
  bool _fromBottom = true;
  int? _thrown;

  @override
  void initState() {
    super.initState();
    _maybeThrow();
  }

  @override
  void didUpdateWidget(DiceThrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeThrow();
  }

  /// Каждый ход бросается один раз — пересборка позиции его не повторяет.
  void _maybeThrow() {
    final DiceRoll? roll = widget.roll;
    if (roll == null || widget.throwId == _thrown) return;
    _thrown = widget.throwId;
    _roll = roll;
    _fromBottom = widget.fromBottom;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final DiceRoll? roll = _roll;
        final double t = _controller.value;
        if (roll == null || !_controller.isAnimating) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = constraints.biggest;
            final double side = size.shortestSide * 0.12;
            final double opacity = t < 0.85 ? 1 : (1 - t) / 0.15;
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Stack(
                children: <Widget>[
                  for (int i = 0; i < 2; i++)
                    ..._die(i, i == 0 ? roll.a : roll.b, t, size, side),
                ],
              ),
            );
          },
        );
      },
    ),
  );

  /// Тень и кубик номер [index] в момент [t] броска.
  List<Widget> _die(int index, int value, double t, Size size, double side) {
    final double flight = Curves.easeOutCubic.transform(math.min(t / 0.75, 1));
    final double sign = _fromBottom ? 1 : -1;
    final Offset start = Offset(
      size.width * (0.88 - 0.1 * index),
      size.height * (0.5 + sign * 0.58),
    );
    final Offset land = Offset(
      size.width * (0.6 + 0.16 * index),
      size.height * (0.5 + sign * (0.2 + 0.05 * index)),
    );
    final Offset position = Offset.lerp(start, land, flight)!;
    // Высота над доской: три затухающих отскока.
    final double hop =
        math.sin(flight * math.pi * 3).abs() *
        math.pow(1 - flight, 1.5).toDouble();
    final double spin = 1 - flight;
    final Matrix4 rotation = Matrix4.rotationZ(
      spin * math.pi * (index.isEven ? 1.5 : -1.5) + (index.isEven ? 0.25 : -0.35),
    ).multiplied(Matrix4.rotationY(spin * math.pi * 2 * (3 - index)))
        .multiplied(Matrix4.rotationX(spin * math.pi * 2 * (2 + index)))
        .multiplied(_base[value]!);
    final double scale = 1 + hop * 0.7;
    return <Widget>[
      Positioned(
        left: position.dx - side / 2 + hop * side * 0.5,
        top: position.dy - side * 0.3 + hop * side * 0.8,
        width: side,
        height: side * 0.6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(side / 2, side * 0.3)),
            color: Colors.black.withValues(alpha: 0.3 * (1 - hop * 0.6)),
          ),
        ),
      ),
      Positioned(
        left: position.dx - side / 2,
        top: position.dy - side / 2,
        width: side,
        height: side,
        child: Transform.scale(
          scale: scale,
          child: _Cube(rotation: rotation, side: side, theme: widget.theme),
        ),
      ),
    ];
  }

  /// Поворот, выводящий грань со значением к зрителю.
  static final Map<int, Matrix4> _base = <int, Matrix4>{
    1: Matrix4.identity(),
    6: Matrix4.rotationY(math.pi),
    3: Matrix4.rotationY(math.pi / 2),
    4: Matrix4.rotationY(-math.pi / 2),
    2: Matrix4.rotationX(math.pi / 2),
    5: Matrix4.rotationX(-math.pi / 2),
  };
}

/// Кубик из шести граней: видимые рисуются от дальней к ближней.
class _Cube extends StatelessWidget {
  const _Cube({required this.rotation, required this.side, required this.theme});

  final Matrix4 rotation;
  final double side;
  final BoardTheme theme;

  /// Грань: значение и поворот, ставящий переднюю грань на её место.
  /// Противоположные грани в сумме дают 7.
  static final List<(int, Matrix4)> _faces = <(int, Matrix4)>[
    (1, Matrix4.identity()),
    (6, Matrix4.rotationY(math.pi)),
    (3, Matrix4.rotationY(-math.pi / 2)),
    (4, Matrix4.rotationY(math.pi / 2)),
    (2, Matrix4.rotationX(-math.pi / 2)),
    (5, Matrix4.rotationX(math.pi / 2)),
  ];

  @override
  Widget build(BuildContext context) {
    final Matrix4 perspective = Matrix4.identity()..setEntry(3, 2, 0.0015);
    final List<(double, Widget)> visible = <(double, Widget)>[];
    for (final (int value, Matrix4 face) in _faces) {
      final Matrix4 placed = rotation.multiplied(face);
      // Нормаль грани (0, 0, -1) после поворота; к зрителю — z < 0.
      final double z = -placed.entry(2, 2);
      if (z >= 0) continue;
      visible.add((
        z,
        Transform(
          alignment: Alignment.center,
          transform: perspective
              .multiplied(placed)
              .multiplied(Matrix4.translationValues(0, 0, -side / 2)),
          child: _face(value, 1 + z),
        ),
      ));
    }
    visible.sort(((double, Widget) a, (double, Widget) b) => b.$1.compareTo(a.$1));
    return Stack(
      children: <Widget>[for (final (double _, Widget face) in visible) face],
    );
  }

  /// Грань, затенённая тем сильнее, чем больше она повёрнута боком.
  Widget _face(int value, double shade) => SizedBox.square(
    dimension: side,
    child: Stack(
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: DieFacePainter(value: value, dimmed: false, theme: theme),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(side * 0.2),
              color: Colors.black.withValues(alpha: shade * 0.45),
            ),
          ),
        ),
      ],
    ),
  );
}

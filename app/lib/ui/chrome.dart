import 'package:flutter/material.dart';

import '../theme/narda_theme.dart';

/// Мелкие детали оболочки, одинаковые у всех разделов меню (§7).
///
/// Здесь нет ни игровой логики, ни состояния — только повторяющееся
/// оформление, чтобы экраны не расходились между собой по цветам и отступам.

/// Шапка раздела: заголовок на цвете поверхности.
class NardaAppBar extends AppBar {
  NardaAppBar({super.key, required String title})
    : super(
        title: Text(title),
        backgroundColor: NardaColors.surface,
        foregroundColor: NardaColors.textPrimary,
      );
}

/// Плашка с золотой обводкой: рейтинг, винрейт, итог партии.
class NardaCard extends StatelessWidget {
  const NardaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: NardaColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: NardaColors.goldDeep),
    ),
    child: child,
  );
}

/// Приглушённая подпись под списком: пояснение, а не действие.
class NardaHint extends StatelessWidget {
  const NardaHint(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    textAlign: TextAlign.center,
    style: const TextStyle(color: NardaColors.textMuted, fontSize: 13),
  );
}

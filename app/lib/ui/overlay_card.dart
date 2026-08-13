import 'package:flutter/material.dart';

import '../theme/narda_theme.dart';
import 'chrome.dart';

/// Затемнение поверх доски с карточкой посередине: итог партии и
/// аннулирование партии показываются одинаково.
///
/// Виджет не позиционирует себя сам — на доске он оборачивается в
/// [Positioned.fill], потому что `Positioned` обязан быть прямым ребёнком
/// `Stack`.
class ModalOverlay extends StatelessWidget {
  const ModalOverlay({
    super.key,
    required this.title,
    required this.children,
    this.titleSize = 22,
  });

  final String title;

  /// Размер заголовка: у итога партии он крупнее, чем у аннулирования.
  final double titleSize;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.65),
    child: Center(
      child: NardaCard(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        radius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: NardaColors.gold,
              ),
            ),
            ...children,
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../theme/narda_theme.dart';

/// Модальный лист приложения: цвет поверхности и скруглённая верхушка (§7).
/// Через такие листы идут выбор уровня, настройки и фразы онлайна.
Future<T?> showNardaSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollable = false,
}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: NardaColors.surface,
  // Настройкам нужна полная высота: список в них длиннее половины экрана.
  isScrollControlled: scrollable,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: builder,
);

/// Заголовок листа или его раздела.
class NardaSheetTitle extends StatelessWidget {
  const NardaSheetTitle(
    this.label, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 10),
  });

  final String label;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: NardaColors.textPrimary,
      ),
    ),
  );
}

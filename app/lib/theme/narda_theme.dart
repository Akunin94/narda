import 'package:flutter/material.dart';

/// Палитра оболочки приложения: тёплое дерево, золото, тёплый светлый текст
/// (§7). Всё рисуется программно, ни одной заимствованной текстуры.
/// Цвета самой доски, шашек и костей живут в [BoardTheme] — их меняет игрок.
abstract final class NardaColors {
  static const Color background = Color(0xFF231710);
  static const Color surface = Color(0xFF322115);
  static const Color surfaceHigh = Color(0xFF43301F);

  static const Color gold = Color(0xFFE8BC57);
  static const Color goldDeep = Color(0xFFA9781F);

  static const Color textPrimary = Color(0xFFF3E4CB);
  static const Color textMuted = Color(0xFFB79C7B);
}

ThemeData buildNardaTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: NardaColors.gold,
    brightness: Brightness.dark,
    surface: NardaColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NardaColors.background,
    textTheme: Typography.material2021().white.apply(
      bodyColor: NardaColors.textPrimary,
      displayColor: NardaColors.textPrimary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NardaColors.gold,
        foregroundColor: NardaColors.background,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NardaColors.textPrimary,
        side: const BorderSide(color: NardaColors.goldDeep),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? NardaColors.gold
            : NardaColors.textMuted,
      ),
    ),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ads_controller.dart';
import '../app.dart';
import '../game/settings.dart';
import '../l10n/gen/app_text.dart';
import '../theme/board_theme.dart';
import '../theme/narda_theme.dart';
import 'chrome.dart';
import 'paint.dart';

/// Оформление доски и костей. Классика доступна всегда, две другие темы
/// открываются просмотром rewarded-ролика на 24 часа (§P3).
class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  bool _watching = false;

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    final SettingsController settings = SettingsScope.of(context);
    final AdsController ads = AdsScope.of(context);
    return Scaffold(
      appBar: NardaAppBar(title: text.themesTitle),
      body: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[settings, ads]),
        builder: (BuildContext context, Widget? child) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            for (final BoardTheme theme in boardThemes)
              _ThemeTile(
                theme: theme,
                title: _themeName(text, theme),
                selected: settings.boardTheme.id == theme.id,
                unlocked: settings.isUnlocked(theme),
                remaining: settings.unlockRemaining(theme),
                busy: _watching,
                rewardedReady: ads.rewardedReady,
                onTap: () => _onTap(settings, ads, theme, text),
              ),
            const SizedBox(height: 12),
            NardaHint(text.themeUnlockedHint),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap(
    SettingsController settings,
    AdsController ads,
    BoardTheme theme,
    AppText text,
  ) async {
    if (settings.isUnlocked(theme)) {
      settings.boardTheme = theme;
      return;
    }
    if (!ads.rewardedReady) {
      _snack(text.themeAdsUnavailable);
      unawaited(ads.loadRewarded());
      return;
    }
    setState(() => _watching = true);
    final bool earned = await ads.showRewarded();
    if (!mounted) return;
    setState(() => _watching = false);
    if (!earned) return;
    settings.unlockTheme(theme);
    settings.boardTheme = theme;
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  String _themeName(AppText text, BoardTheme theme) => switch (theme.id) {
    'kok_gumbaz' => text.themeKokGumbaz,
    'zar' => text.themeZar,
    _ => text.themeKlassik,
  };
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.title,
    required this.selected,
    required this.unlocked,
    required this.remaining,
    required this.busy,
    required this.rewardedReady,
    required this.onTap,
  });

  final BoardTheme theme;
  final String title;
  final bool selected;
  final bool unlocked;
  final Duration? remaining;
  final bool busy;
  final bool rewardedReady;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: NardaColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? NardaColors.gold : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 96,
                    height: 64,
                    child: CustomPaint(
                      painter: _ThemePreviewPainter(theme: theme),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: NardaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _status(text),
                        style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? NardaColors.gold
                              : NardaColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    selected
                        ? Icons.check_circle
                        : unlocked
                        ? Icons.circle_outlined
                        : rewardedReady
                        ? Icons.play_circle_outline
                        : Icons.lock_outline,
                    color: selected ? NardaColors.gold : NardaColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _status(AppText text) {
    if (selected) return text.themeSelected;
    final Duration? left = remaining;
    if (left != null) {
      return left.inHours >= 1
          ? text.themeHoursLeft(left.inHours)
          : text.themeMinutesLeft(left.inMinutes + 1);
    }
    if (theme.free) return '';
    return text.themeUnlockWatch;
  }
}

/// Уменьшенная доска: рамка с орнаментом, четыре пункта, две шашки и кубик.
class _ThemePreviewPainter extends CustomPainter {
  const _ThemePreviewPainter({required this.theme});

  final BoardTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[theme.frameLight, theme.frameDark],
        ).createShader(rect),
    );
    final Rect inner = rect.deflate(size.height * 0.11);
    canvas.drawRect(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[theme.feltLight, theme.feltDark],
        ).createShader(inner),
    );

    final double width = inner.width / 4;
    for (int i = 0; i < 4; i++) {
      final Path path = Path()
        ..moveTo(inner.left + width * i, inner.top)
        ..lineTo(inner.left + width * (i + 1), inner.top)
        ..lineTo(inner.left + width * (i + 0.5), inner.top + inner.height * 0.62)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = i.isEven ? theme.pointLight : theme.pointDark,
      );
    }

    final double radius = inner.height * 0.17;
    _checker(canvas, Offset(inner.left + width * 0.9, inner.bottom - radius * 1.3), radius, true);
    _checker(canvas, Offset(inner.left + width * 2.0, inner.bottom - radius * 1.3), radius, false);

    final Rect die = Rect.fromCenter(
      center: Offset(inner.right - width * 0.6, inner.bottom - radius * 1.3),
      width: radius * 2,
      height: radius * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(die, Radius.circular(radius * 0.4)),
      Paint()..color = theme.dieFace,
    );
    canvas.drawCircle(die.center, radius * 0.22, Paint()..color = theme.diePip);
  }

  void _checker(Canvas canvas, Offset center, double radius, bool white) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = white ? theme.checkerWhiteFace : theme.checkerBlackFace,
    );
    canvas.drawCircle(
      center,
      radius * 0.9,
      strokePaint(
        white ? theme.checkerWhiteEdge : theme.checkerBlackEdge,
        radius * 0.2,
      ),
    );
  }

  @override
  bool shouldRepaint(_ThemePreviewPainter oldDelegate) =>
      oldDelegate.theme.id != theme.id;
}

import 'package:flutter/material.dart';

import '../app.dart';
import '../game/stats.dart';
import '../l10n/gen/app_text.dart';
import '../theme/narda_theme.dart';
import 'chrome.dart';
import 'paint.dart';

/// Локальная статистика: партии, винрейт, марсы, серии (§P3).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    final StatsStore store = StatsScope.of(context);
    return Scaffold(
      appBar: NardaAppBar(title: text.statsTitle),
      body: AnimatedBuilder(
        animation: store,
        builder: (BuildContext context, Widget? child) {
          final Stats stats = store.stats;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              _WinRateCard(stats: stats),
              const SizedBox(height: 16),
              _row(text.statsGames, '${stats.games}'),
              _row(text.statsWins, '${stats.wins}'),
              _row(text.statsMarsWins, '${stats.marsWins}'),
              _row(text.statsMarsLosses, '${stats.marsLosses}'),
              _row(text.statsMatches, '${stats.matches}'),
              _row(text.statsMatchWins, '${stats.matchWins}'),
              const SizedBox(height: 16),
              NardaHint(stats.games == 0 ? text.statsEmpty : text.statsNote),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: NardaColors.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: const TextStyle(color: NardaColors.textPrimary)),
        Text(
          value,
          style: const TextStyle(
            color: NardaColors.gold,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ],
    ),
  );
}

/// Крупная плашка винрейта с дугой заполнения.
class _WinRateCard extends StatelessWidget {
  const _WinRateCard({required this.stats});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    return NardaCard(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 132,
            height: 132,
            child: CustomPaint(
              painter: _WinRatePainter(ratio: stats.winRate / 100),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '${stats.winRate}%',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: NardaColors.gold,
                      ),
                    ),
                    Text(
                      '${stats.wins} / ${stats.games}',
                      style: const TextStyle(
                        color: NardaColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text.statsWinRate,
            style: const TextStyle(color: NardaColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _WinRatePainter extends CustomPainter {
  const _WinRatePainter({required this.ratio});

  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double stroke = size.width * 0.09;
    final Rect arc = rect.deflate(stroke / 2 + 2);
    canvas.drawArc(
      arc,
      0,
      3.1415926 * 2,
      false,
      strokePaint(NardaColors.surfaceHigh, stroke),
    );
    if (ratio <= 0) return;
    canvas.drawArc(
      arc,
      -3.1415926 / 2,
      3.1415926 * 2 * ratio.clamp(0.0, 1.0),
      false,
      strokePaint(NardaColors.gold, stroke, cap: StrokeCap.round),
    );
  }

  @override
  bool shouldRepaint(_WinRatePainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}

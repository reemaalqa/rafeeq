import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../domain/entities/ayah.dart';

/// Mushaf-styled ayah card:
/// - Ornamental circular verse-number badge (gold when active)
/// - Large Uthmanic-leaning Arabic text with generous line-height
/// - Tap anywhere to start playback from this ayah
/// - Subtle highlight + border when it's the one being recited
class AyahCard extends StatelessWidget {
  final Ayah ayah;
  final bool isCurrentlyPlaying;
  final VoidCallback? onTap;

  const AyahCard({
    super.key,
    required this.ayah,
    this.isCurrentlyPlaying = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFBFA254);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            decoration: BoxDecoration(
              gradient: isCurrentlyPlaying
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.islamicColor.withOpacity(0.08),
                        AppTheme.islamicLight.withOpacity(0.04),
                      ],
                    )
                  : null,
              color: isCurrentlyPlaying
                  ? null
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: isCurrentlyPlaying
                    ? AppTheme.islamicColor
                    : AppTheme.dividerColor.withOpacity(0.5),
                width: isCurrentlyPlaying ? 2 : 1,
              ),
              boxShadow: isCurrentlyPlaying
                  ? [
                      BoxShadow(
                        color: AppTheme.islamicColor.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Arabic ayah text (Amiri — Quranic-grade typography) ─────
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: ayah.arabicText.trim(),
                          style: AppTheme.quranText(
                            color: isCurrentlyPlaying
                                ? const Color(0xFF0D3F12)
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const WidgetSpan(child: SizedBox(width: 6)),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: _AyahNumberBadge(
                            number: ayah.number,
                            active: isCurrentlyPlaying,
                            gold: gold,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                // ── Optional transliteration / translation ────────────────────
                if (ayah.transliteration.trim().isNotEmpty ||
                    ayah.translation.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppTheme.dividerColor),
                  const SizedBox(height: 10),
                  if (ayah.transliteration.trim().isNotEmpty)
                    Text(
                      ayah.transliteration,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  if (ayah.translation.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      ayah.translation,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
                // ── Bottom row: play hint + now-playing indicator ────────────
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (isCurrentlyPlaying) ...[
                      const _PlayingBars(),
                      const SizedBox(width: 8),
                      Text(
                        'قيد التلاوة',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.islamicColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_outline_rounded,
                            size: 18,
                            color: AppTheme.islamicColor.withOpacity(0.65),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'اضغط للاستماع',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),
                    Text(
                      'الآية ${ayah.number}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ornamental ayah number — 8-pointed star that mimics the Mushaf marker.
class _AyahNumberBadge extends StatelessWidget {
  final int number;
  final bool active;
  final Color gold;

  const _AyahNumberBadge({
    required this.number,
    required this.active,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppTheme.islamicColor : gold;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg, bg.withOpacity(0.75)],
        ),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Tiny animated equaliser bars, shown on the currently-playing ayah.
class _PlayingBars extends StatefulWidget {
  const _PlayingBars();

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        double bar(int i) {
          final t = (_c.value + i * 0.33) % 1.0;
          final v = 0.3 + 0.7 * (1 - (2 * t - 1).abs());
          return v;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (int i = 0; i < 3; i++) ...[
              Container(
                width: 3,
                height: 4 + bar(i) * 12,
                decoration: BoxDecoration(
                  color: AppTheme.islamicColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (i != 2) const SizedBox(width: 2),
            ],
          ],
        );
      },
    );
  }
}

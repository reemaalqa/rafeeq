import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/bmi_result.dart';

/// A clean BMI card with a coloured zone bar — no custom painting glitches.
class BmiGaugeWidget extends StatelessWidget {
  final BmiResult bmiResult;

  const BmiGaugeWidget({super.key, required this.bmiResult});

  // BMI scale used for the marker position
  static const double _scaleMin = 15.0;
  static const double _scaleMax = 40.0;

  Color _zoneColor(BmiCategory cat) {
    switch (cat) {
      case BmiCategory.underweight: return AppTheme.infoColor;
      case BmiCategory.normal:      return AppTheme.successColor;
      case BmiCategory.overweight:  return AppTheme.warningColor;
      case BmiCategory.obese:       return AppTheme.errorColor;
    }
  }

  String _categoryLabel(BmiCategory cat, AppLocalizations l10n) {
    switch (cat) {
      case BmiCategory.underweight: return l10n.underweight;
      case BmiCategory.normal:      return l10n.normalWeight;
      case BmiCategory.overweight:  return l10n.overweight;
      case BmiCategory.obese:       return l10n.obese;
    }
  }

  double get _markerFraction {
    final clamped = bmiResult.value.clamp(_scaleMin, _scaleMax);
    return (clamped - _scaleMin) / (_scaleMax - _scaleMin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _zoneColor(bmiResult.category);
    final label = _categoryLabel(bmiResult.category, l10n);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Value + category row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                bmiResult.value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'BMI',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Category label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spaceMD),

          // Zone bar
          _ZoneBar(markerFraction: _markerFraction, activeColor: color),

          const SizedBox(height: 6),

          // Zone labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ZoneLabel(l10n.underweight, AppTheme.infoColor),
              _ZoneLabel(l10n.normalWeight, AppTheme.successColor),
              _ZoneLabel(l10n.overweight, AppTheme.warningColor),
              _ZoneLabel(l10n.obese, AppTheme.errorColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _ZoneLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ZoneBar extends StatefulWidget {
  final double markerFraction; // 0.0–1.0
  final Color activeColor;
  const _ZoneBar({required this.markerFraction, required this.activeColor});

  @override
  State<_ZoneBar> createState() => _ZoneBarState();
}

class _ZoneBarState extends State<_ZoneBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // Four equal zones: underweight 0-25%, normal 25-55%, overweight 55-75%, obese 75-100%
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final animated = widget.markerFraction * _anim.value;
        return LayoutBuilder(builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          // In RTL the bar zones are flipped, so mirror the marker position
          final markerX = isRtl ? (1 - animated) * barWidth : animated * barWidth;

          return SizedBox(
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Coloured zones
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        Expanded(flex: 25, child: Container(color: AppTheme.infoColor.withOpacity(0.75))),
                        Expanded(flex: 30, child: Container(color: AppTheme.successColor.withOpacity(0.75))),
                        Expanded(flex: 20, child: Container(color: AppTheme.warningColor.withOpacity(0.75))),
                        Expanded(flex: 25, child: Container(color: AppTheme.errorColor.withOpacity(0.75))),
                      ],
                    ),
                  ),
                ),
                // Marker triangle
                Positioned(
                  left: (markerX - 8).clamp(0, barWidth - 16),
                  top: -2,
                  child: CustomPaint(
                    size: const Size(16, 32),
                    painter: _MarkerPainter(color: widget.activeColor),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final Color color;
  const _MarkerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw a downward-pointing triangle as marker
    final path = Path()
      ..moveTo(size.width / 2, size.height - 4)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);

    // White border
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => old.color != color;
}

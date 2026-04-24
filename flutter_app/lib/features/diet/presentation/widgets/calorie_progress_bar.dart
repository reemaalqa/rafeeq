import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';

class CalorieProgressBar extends StatelessWidget {
  final int consumed;
  final int target;

  const CalorieProgressBar({super.key, required this.consumed, required this.target});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final remaining = (target - consumed).clamp(0, target);
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final progressColor = progress > 0.9
        ? AppTheme.errorColor
        : progress > 0.7
            ? AppTheme.warningColor
            : AppTheme.successColor;
    final remainingColor = remaining == 0 ? AppTheme.errorColor : AppTheme.successColor;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.calories,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(color: progressColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              backgroundColor: AppTheme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CalStat(
                label: l10n.consumed,
                value: '$consumed',
                unit: l10n.cal,
                color: AppTheme.primaryColor,
              ),
              _CalStat(
                label: l10n.remaining,
                value: '$remaining',
                unit: l10n.cal,
                color: remainingColor,
              ),
              _CalStat(
                label: l10n.target,
                value: '$target',
                unit: l10n.cal,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _CalStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(fontSize: 13, color: color.withOpacity(0.8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

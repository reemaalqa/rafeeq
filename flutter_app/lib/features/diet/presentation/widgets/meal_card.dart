import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/meal.dart';

class MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onToggleEaten;

  const MealCard({super.key, required this.meal, required this.onToggleEaten});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: meal.isEaten ? AppTheme.successColor : AppTheme.dividerColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSM),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(_mealIcon(meal.mealTime), color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.nameAr,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Badge(
                          label: _mealTimeLabel(meal.mealTime, l10n),
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: AppTheme.spaceSM),
                        _Badge(
                          label: '${meal.calories} ${l10n.cal}',
                          color: AppTheme.warningColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (meal.isEaten)
                const Icon(Icons.check_circle, color: AppTheme.successColor, size: 32),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Wrap(
            spacing: AppTheme.spaceSM,
            runSpacing: 4,
            children: meal.ingredients
                .map((i) => Chip(
                      label: Text(i, style: const TextStyle(fontSize: 14)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onToggleEaten,
              style: ElevatedButton.styleFrom(
                backgroundColor: meal.isEaten ? AppTheme.successColor : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              child: Text(meal.isEaten ? '✓ ${l10n.eaten}' : l10n.markAsEaten),
            ),
          ),
        ],
      ),
    );
  }

  String _mealTimeLabel(MealTime t, AppLocalizations l10n) {
    switch (t) {
      case MealTime.breakfast: return l10n.breakfast;
      case MealTime.lunch:     return l10n.lunch;
      case MealTime.dinner:    return l10n.dinner;
      case MealTime.snack:     return l10n.snack;
    }
  }

  IconData _mealIcon(MealTime t) {
    switch (t) {
      case MealTime.breakfast: return Icons.wb_sunny;
      case MealTime.lunch:     return Icons.restaurant;
      case MealTime.dinner:    return Icons.nightlight;
      case MealTime.snack:     return Icons.apple;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

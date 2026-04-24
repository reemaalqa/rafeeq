import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';

class FoodPreferenceChip extends StatelessWidget {
  final String food;
  final bool isDisliked;
  final bool isAllergen;
  final VoidCallback? onToggle;

  const FoodPreferenceChip({
    super.key,
    required this.food,
    required this.isDisliked,
    this.isAllergen = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final Color iconColor;

    if (isAllergen) {
      bgColor     = AppTheme.errorColor.withOpacity(0.12);
      borderColor = AppTheme.errorColor;
      textColor   = AppTheme.errorColor;
      icon        = Icons.warning_amber_rounded;
      iconColor   = AppTheme.errorColor;
    } else if (isDisliked) {
      bgColor     = AppTheme.errorColor.withOpacity(0.10);
      borderColor = AppTheme.errorColor.withOpacity(0.7);
      textColor   = AppTheme.errorColor;
      icon        = Icons.cancel;
      iconColor   = AppTheme.errorColor;
    } else {
      bgColor     = AppTheme.successColor.withOpacity(0.08);
      borderColor = AppTheme.dividerColor;
      textColor   = AppTheme.textSecondary;
      icon        = Icons.check_circle_outline;
      iconColor   = AppTheme.successColor;
    }

    return GestureDetector(
      onTap: isAllergen ? null : onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceSM),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              food,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isDisliked ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../domain/entities/allergy.dart';

class AllergyChip extends StatelessWidget {
  final Allergy allergy;
  final bool isSelected;
  final VoidCallback onTap;

  const AllergyChip({
    super.key,
    required this.allergy,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceSM,
        ),
        decoration: BoxDecoration(
          color: isSelected ? _severityColor(allergy.severity) : AppTheme.dividerColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected ? _severityColor(allergy.severity) : AppTheme.dividerColor,
            width: 2,
          ),
        ),
        child: Text(
          allergy.name,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _severityColor(AllergySeverity severity) {
    switch (severity) {
      case AllergySeverity.mild: return AppTheme.warningColor;
      case AllergySeverity.moderate: return Colors.orange.shade700;
      case AllergySeverity.severe: return AppTheme.errorColor;
    }
  }
}

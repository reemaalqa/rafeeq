import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/reminder.dart';

class ReminderTypeSelector extends StatelessWidget {
  final ReminderType selected;
  final ValueChanged<ReminderType> onChanged;

  const ReminderTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppTheme.spaceSM,
      crossAxisSpacing: AppTheme.spaceSM,
      childAspectRatio: 1.2,
      children: ReminderType.values.map((type) {
        final isSelected = type == selected;
        return InkWell(
          onTap: () => onChanged(type),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _iconForType(type),
                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  _labelForType(type, l10n),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForType(ReminderType type) {
    switch (type) {
      case ReminderType.medication: return Icons.medication;
      case ReminderType.prayer: return Icons.mosque;
      case ReminderType.appointment: return Icons.event;
      case ReminderType.hydration: return Icons.water_drop;
      case ReminderType.custom: return Icons.notifications;
    }
  }

  String _labelForType(ReminderType type, AppLocalizations l10n) {
    switch (type) {
      case ReminderType.medication: return l10n.medication;
      case ReminderType.prayer: return l10n.prayer;
      case ReminderType.appointment: return l10n.appointment;
      case ReminderType.hydration: return l10n.water;
      case ReminderType.custom: return l10n.custom;
    }
  }
}

import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/reminder.dart';

class ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onSnooze;
  final VoidCallback onDelete;

  const ReminderTile({
    super.key,
    required this.reminder,
    required this.onSnooze,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: _colorForType(reminder.type).withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _colorForType(reminder.type).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForType(reminder.type),
                  color: _colorForType(reminder.type),
                  size: 28,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(reminder.scheduledTime),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 24),
                onPressed: onDelete,
                color: AppTheme.errorColor,
              ),
            ],
          ),
          if (reminder.isActive) ...[
            const SizedBox(height: AppTheme.spaceSM),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSnooze,
                    icon: const Icon(Icons.snooze, size: 20),
                    label: Text(AppLocalizations.of(context)!.snooze10m),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Chip(
                    label: Builder(builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx)!;
                      return Text(
                        reminder.repeat == RepeatInterval.none
                            ? l10n.once
                            : reminder.repeat == RepeatInterval.daily
                                ? l10n.daily
                                : l10n.weekly,
                        style: const TextStyle(fontSize: 13),
                      );
                    }),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    // Uses TimeOfDay.format which respects the device locale (Arabic 12h/24h)
    final tod = TimeOfDay.fromDateTime(time);
    // Format: day name + date + time
    final weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final weekday = weekdays[time.weekday - 1];
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'ص' : 'م';
    return '$weekday  $h:$m $period';
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

  Color _colorForType(ReminderType type) {
    switch (type) {
      case ReminderType.medication: return AppTheme.errorColor;
      case ReminderType.prayer: return AppTheme.islamicColor;
      case ReminderType.appointment: return AppTheme.secondaryColor;
      case ReminderType.hydration: return AppTheme.infoColor;
      case ReminderType.custom: return AppTheme.warningColor;
    }
  }
}

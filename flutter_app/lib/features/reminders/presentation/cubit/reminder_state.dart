import 'package:equatable/equatable.dart';
import '../../domain/entities/reminder.dart';

enum ReminderStatus { initial, loading, loaded, error }

class ReminderState extends Equatable {
  final List<Reminder> reminders;
  final ReminderStatus status;
  final String? errorMessage;

  /// Set to true after adding a reminder when the OS denied exact-alarm
  /// permission. The UI listens for this and opens the system settings page.
  final bool needsExactAlarmPermission;

  const ReminderState({
    this.reminders = const [],
    this.status = ReminderStatus.initial,
    this.errorMessage,
    this.needsExactAlarmPermission = false,
  });

  ReminderState copyWith({
    List<Reminder>? reminders,
    ReminderStatus? status,
    String? errorMessage,
    bool? needsExactAlarmPermission,
  }) {
    return ReminderState(
      reminders: reminders ?? this.reminders,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      needsExactAlarmPermission:
          needsExactAlarmPermission ?? this.needsExactAlarmPermission,
    );
  }

  List<Reminder> get todayReminders {
    final now = DateTime.now();
    return reminders
        .where((r) =>
            r.scheduledTime.year == now.year &&
            r.scheduledTime.month == now.month &&
            r.scheduledTime.day == now.day)
        .toList();
  }

  List<Reminder> get upcomingReminders {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return reminders
        .where((r) =>
            r.scheduledTime.year == tomorrow.year &&
            r.scheduledTime.month == tomorrow.month &&
            r.scheduledTime.day == tomorrow.day)
        .toList();
  }

  @override
  List<Object?> get props =>
      [reminders, status, errorMessage, needsExactAlarmPermission];
}

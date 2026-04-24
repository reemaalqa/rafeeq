import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show PendingNotificationRequest;

import '../../features/reminders/data/datasources/reminder_local_datasource.dart';
import '../../features/reminders/data/models/reminder_model.dart';
import '../../features/reminders/domain/entities/reminder.dart';
import 'notification_scheduler.dart';

/// Outcome of a single alarm-scheduling attempt.
class AlarmResult {
  final Reminder reminder;
  final int outcome;

  const AlarmResult({required this.reminder, required this.outcome});

  bool get isScheduledExact =>
      outcome == NotificationScheduler.outcomeScheduledExact;

  /// True when the OS rejected the exact-alarm permission and the user should
  /// be prompted to open Settings > Apps > Special access > Alarms & reminders.
  bool get needsPermission =>
      outcome == NotificationScheduler.outcomePermissionDenied ||
      outcome == NotificationScheduler.outcomeScheduledInexact;

  bool get timeInPast =>
      outcome == NotificationScheduler.outcomeTimeInPast;

  bool get disabledInApp =>
      outcome == NotificationScheduler.outcomeDisabledInSettings;
}

/// Single source of truth for the full alarm lifecycle:
///   permission request → local persistence → OS alarm scheduling
///
/// Both [ReminderCubit] (UI path) and [ConversationCubit] (voice path) go
/// through this service so there is no duplicated logic and no diverging IDs.
///
/// The reminder's UUID is ALWAYS used as the canonical ID for local storage
/// and OS notification registration. The server ID (returned by remote sync)
/// is never allowed to replace the UUID here — doing so would produce
/// mismatched notification IDs and cause duplicate alarms after a reboot.
class AlarmService {
  final ReminderLocalDatasource _local;
  final NotificationScheduler _scheduler;

  AlarmService({
    required ReminderLocalDatasource local,
    required NotificationScheduler scheduler,
  })  : _local = local,
        _scheduler = scheduler;

  // ── Core operations ────────────────────────────────────────────────────────

  /// Saves [reminder] locally (keyed by its UUID) and registers an OS alarm.
  /// Permissions are requested first so [zonedSchedule] does not throw silently.
  Future<AlarmResult> addAndSchedule(Reminder reminder) async {
    // 1. Ask for permissions before touching the alarm manager.
    await _scheduler.requestPermissions();

    // 2. Persist locally using UUID — never overwrite with a server-issued ID.
    final list = await _local.getReminders();
    list.removeWhere((r) => r.id == reminder.id); // idempotent upsert
    list.add(ReminderModel.fromEntity(reminder));
    await _local.saveReminders(list);

    // 3. Register the OS alarm.
    final outcome = await _scheduler.scheduleReminder(reminder);
    return AlarmResult(reminder: reminder, outcome: outcome);
  }

  /// Cancels the OS alarm and removes the reminder from local storage.
  Future<void> cancel(String id) async {
    await _scheduler.cancelReminder(id);
    final list = await _local.getReminders();
    list.removeWhere((r) => r.id == id);
    await _local.saveReminders(list);
  }

  /// Returns all locally stored reminders.
  Future<List<Reminder>> getAll() => _local.getReminders();

  /// Re-registers every locally stored reminder with the OS alarm manager.
  /// Called at app start and after device reboot so no alarm is silently lost.
  Future<void> rescheduleAll() async {
    final reminders = await _local.getReminders();
    for (final r in reminders) {
      await _scheduler.scheduleReminder(r);
    }
  }

  // ── Permission & diagnostics delegates ────────────────────────────────────

  Future<bool> openAlarmSettings() => _scheduler.openExactAlarmSettings();
  Future<bool> openNotificationSettings() =>
      _scheduler.openNotificationSettings();
  Future<bool> openBatteryOptimisationSettings() =>
      _scheduler.openBatteryOptimisationSettings();
  Future<NotificationDiagnosis> diagnose() => _scheduler.diagnose();
  Future<bool> rawRemindersEnabled() => _scheduler.rawRemindersEnabled();
  Future<void> forceEnableReminders() => _scheduler.forceEnableReminders();
  Future<List<PendingNotificationRequest>> pending() => _scheduler.pending();
  Future<void> showTestNow() => _scheduler.showTestNow();
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/alarm_service.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/usecases/delete_reminder.dart';
import 'reminder_state.dart';

class ReminderCubit extends Cubit<ReminderState> {
  final AlarmService _alarmService;
  final DeleteReminder _deleteReminder;

  ReminderCubit({
    required AlarmService alarmService,
    required DeleteReminder deleteReminder,
  })  : _alarmService = alarmService,
        _deleteReminder = deleteReminder,
        super(const ReminderState());

  Future<void> loadReminders() async {
    emit(state.copyWith(status: ReminderStatus.loading));
    try {
      final list = await _alarmService.getAll();
      emit(state.copyWith(status: ReminderStatus.loaded, reminders: list));
      await _alarmService.rescheduleAll();
    } catch (_) {
      emit(state.copyWith(
        status: ReminderStatus.error,
        errorMessage: 'حدث خطأ في تحميل التذكيرات',
      ));
    }
  }

  Future<void> addReminder(Reminder reminder) async {
    final result = await _alarmService.addAndSchedule(reminder);
    emit(state.copyWith(
      reminders: [...state.reminders, result.reminder],
      needsExactAlarmPermission: result.needsPermission,
    ));
  }

  void clearAlarmPermissionFlag() {
    emit(state.copyWith(needsExactAlarmPermission: false));
  }

  Future<void> deleteReminder(String id) async {
    await _alarmService.cancel(id);
    final updated = state.reminders.where((r) => r.id != id).toList();
    emit(state.copyWith(reminders: updated));
    _deleteReminder(id).catchError((_) {}); // best-effort remote sync
  }

  Future<void> snoozeReminder(String id, {int minutes = 10}) async {
    final index = state.reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final snoozed = state.reminders[index].copyWith(
      scheduledTime:
          state.reminders[index].scheduledTime.add(Duration(minutes: minutes)),
    );
    await _alarmService.cancel(id);
    final result = await _alarmService.addAndSchedule(snoozed);
    final updated = List<Reminder>.from(state.reminders);
    updated[index] = result.reminder;
    emit(state.copyWith(reminders: updated));
  }

  Future<void> sendTestNotification() => _alarmService.showTestNow();

  Future<void> openAlarmSettings() async {
    await _alarmService.openAlarmSettings();
    clearAlarmPermissionFlag();
  }
}

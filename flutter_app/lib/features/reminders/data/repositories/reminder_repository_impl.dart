import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminder_local_datasource.dart';
import '../datasources/reminder_remote_datasource.dart';
import '../models/reminder_model.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  final ReminderLocalDatasource _local;
  final ReminderRemoteDataSource _remote;

  const ReminderRepositoryImpl(this._local, this._remote);

  // ── Mapping helpers ──────────────────────────────────────────────────────────

  static const _typeMap = {
    1: ReminderType.medication,   // category: medication
    2: ReminderType.appointment,  // category: appointment
    4: ReminderType.prayer,       // category: prayer
    6: ReminderType.hydration,    // category: water
  };

  ReminderType _categoryToType(int? categoryId) =>
      _typeMap[categoryId] ?? ReminderType.custom;

  int _typeToCategory(ReminderType t) {
    switch (t) {
      case ReminderType.medication:  return 1;
      case ReminderType.appointment: return 2;
      case ReminderType.prayer:      return 4;
      case ReminderType.hydration:   return 6;
      case ReminderType.custom:      return 8;
    }
  }

  RepeatInterval _repeatFromString(String? s) {
    switch (s) {
      case 'daily':   return RepeatInterval.daily;
      case 'weekly':  return RepeatInterval.weekly;
      default:        return RepeatInterval.none;
    }
  }

  String _repeatToString(RepeatInterval r) {
    switch (r) {
      case RepeatInterval.daily:  return 'daily';
      case RepeatInterval.weekly: return 'weekly';
      case RepeatInterval.none:   return 'once';
    }
  }

  Reminder _fromMap(Map<String, dynamic> m) {
    // Support both camelCase (current) and snake_case (legacy) field names
    final timeStr = (m['reminderTime'] ?? m['reminder_time'] ?? '08:00:00') as String;
    final parts = timeStr.split(':');
    final now = DateTime.now();
    final scheduled = DateTime(
      now.year, now.month, now.day,
      int.tryParse(parts[0]) ?? 8,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    return Reminder(
      id: m['id'].toString(),
      title: m['title'] as String? ?? '',
      description: m['description'] as String? ?? '',
      scheduledTime: scheduled,
      type: _categoryToType((m['categoryId'] ?? m['category_id']) as int?),
      isActive: (m['isActive'] ?? m['is_active'] ?? true) as bool,
      snoozeDurationMinutes: (m['snoozeMinutes'] ?? m['snooze_minutes'] ?? 10) as int,
      repeat: _repeatFromString((m['reminderType'] ?? m['reminder_type']) as String?),
    );
  }

  Map<String, dynamic> _toMap(Reminder r) => {
        'categoryId': _typeToCategory(r.type),
        'title': r.title,
        'description': r.description,
        'reminderType': _repeatToString(r.repeat),
        'startDate': r.scheduledTime.toIso8601String().split('T').first,
        'reminderTime':
            '${r.scheduledTime.hour.toString().padLeft(2, '0')}:${r.scheduledTime.minute.toString().padLeft(2, '0')}:00',
        'snoozeMinutes': r.snoozeDurationMinutes,
        'isActive': r.isActive,
      };

  // ── Repository methods ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Reminder>>> getReminders() async {
    try {
      final data = await _remote.getReminders();
      final reminders = data.map(_fromMap).toList();
      await _local.saveReminders(
        reminders.map(ReminderModel.fromEntity).toList(),
      );
      return Right(reminders);
    } on NetworkException {
      // offline — fall through
    } catch (_) {
      // fall through
    }
    try {
      return Right(await _local.getReminders());
    } catch (_) {
      return const Left(CacheFailure('Failed to load reminders'));
    }
  }

  @override
  Future<Either<Failure, void>> addReminder(Reminder reminder) async {
    // Try remote first to get a real server id
    try {
      final result = await _remote.createReminder(_toMap(reminder));
      final savedReminder = reminder.copyWith(id: result['id'].toString());
      final list = await _local.getReminders();
      list.add(ReminderModel.fromEntity(savedReminder));
      await _local.saveReminders(list);
      return const Right(null);
    } on NetworkException {
      // offline — save locally with temp id
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (_) {
      // fall through to local
    }
    try {
      final list = await _local.getReminders();
      list.add(ReminderModel.fromEntity(reminder));
      await _local.saveReminders(list);
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to add reminder'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReminder(String id) async {
    try {
      await _remote.deleteReminder(id);
    } catch (_) {
      // best-effort
    }
    try {
      final list = await _local.getReminders();
      list.removeWhere((r) => r.id == id);
      await _local.saveReminders(list);
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to delete reminder'));
    }
  }

  @override
  Future<Either<Failure, void>> snoozeReminder(String id, int minutes) async {
    // Snooze is local time-state — update local only
    try {
      final list = await _local.getReminders();
      final index = list.indexWhere((r) => r.id == id);
      if (index != -1) {
        final original = list[index];
        list[index] = ReminderModel.fromEntity(
          original.copyWith(
            scheduledTime:
                original.scheduledTime.add(Duration(minutes: minutes)),
          ),
        );
        await _local.saveReminders(list);
      }
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to snooze reminder'));
    }
  }

  @override
  Future<Either<Failure, void>> updateReminder(Reminder reminder) async {
    try {
      await _remote.updateReminder(reminder.id, _toMap(reminder));
    } catch (_) {
      // best-effort
    }
    try {
      final list = await _local.getReminders();
      final index = list.indexWhere((r) => r.id == reminder.id);
      if (index != -1) {
        list[index] = ReminderModel.fromEntity(reminder);
        await _local.saveReminders(list);
      }
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to update reminder'));
    }
  }
}

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reminder.dart';

abstract class ReminderRepository {
  Future<Either<Failure, List<Reminder>>> getReminders();
  Future<Either<Failure, void>> addReminder(Reminder reminder);
  Future<Either<Failure, void>> deleteReminder(String id);
  Future<Either<Failure, void>> snoozeReminder(String id, int minutes);
  Future<Either<Failure, void>> updateReminder(Reminder reminder);
}

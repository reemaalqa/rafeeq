import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

class GetReminders {
  final ReminderRepository repository;
  const GetReminders(this.repository);
  Future<Either<Failure, List<Reminder>>> call() => repository.getReminders();
}

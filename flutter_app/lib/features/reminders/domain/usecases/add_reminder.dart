import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

class AddReminder {
  final ReminderRepository repository;
  const AddReminder(this.repository);
  Future<Either<Failure, void>> call(Reminder reminder) => repository.addReminder(reminder);
}

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/reminder_repository.dart';

class SnoozeReminder {
  final ReminderRepository repository;
  const SnoozeReminder(this.repository);
  Future<Either<Failure, void>> call(String id, int minutes) => repository.snoozeReminder(id, minutes);
}

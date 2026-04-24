import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/reminder_repository.dart';

class DeleteReminder {
  final ReminderRepository repository;
  const DeleteReminder(this.repository);
  Future<Either<Failure, void>> call(String id) => repository.deleteReminder(id);
}

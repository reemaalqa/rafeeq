import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/emergency_repository.dart';

class DeleteEmergencyContact {
  final EmergencyRepository repository;
  const DeleteEmergencyContact(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteEmergencyContact(id);
  }
}

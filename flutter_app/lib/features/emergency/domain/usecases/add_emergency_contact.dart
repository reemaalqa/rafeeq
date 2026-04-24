import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/emergency_contact.dart';
import '../repositories/emergency_repository.dart';

class AddEmergencyContact {
  final EmergencyRepository repository;
  const AddEmergencyContact(this.repository);

  Future<Either<Failure, EmergencyContact>> call(EmergencyContact contact) {
    return repository.addEmergencyContact(contact);
  }
}

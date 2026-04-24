import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/emergency_contact.dart';
import '../repositories/emergency_repository.dart';

class GetEmergencyContacts {
  final EmergencyRepository repository;

  const GetEmergencyContacts(this.repository);

  Future<Either<Failure, List<EmergencyContact>>> call() {
    return repository.getEmergencyContacts();
  }
}

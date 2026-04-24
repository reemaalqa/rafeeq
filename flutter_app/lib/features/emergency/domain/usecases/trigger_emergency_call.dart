import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/emergency_repository.dart';

class TriggerEmergencyCall {
  final EmergencyRepository repository;

  const TriggerEmergencyCall(this.repository);

  Future<Either<Failure, void>> call(String phoneNumber) {
    return repository.triggerCall(phoneNumber);
  }
}

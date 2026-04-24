import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/emergency_repository.dart';

class SendEmergencySms {
  final EmergencyRepository repository;

  const SendEmergencySms(this.repository);

  Future<Either<Failure, void>> call({
    required String phoneNumber,
    required String senderName,
  }) {
    return repository.sendEmergencySms(
      phoneNumber: phoneNumber,
      senderName: senderName,
    );
  }
}

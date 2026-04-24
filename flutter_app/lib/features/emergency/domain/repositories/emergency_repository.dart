import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/emergency_contact.dart';

abstract class EmergencyRepository {
  Future<Either<Failure, List<EmergencyContact>>> getEmergencyContacts();
  Future<Either<Failure, EmergencyContact>> addEmergencyContact(EmergencyContact contact);
  Future<Either<Failure, void>> deleteEmergencyContact(String id);
  Future<Either<Failure, void>> triggerCall(String phoneNumber);
  Future<Either<Failure, void>> sendEmergencySms({
    required String phoneNumber,
    required String senderName,
  });
}

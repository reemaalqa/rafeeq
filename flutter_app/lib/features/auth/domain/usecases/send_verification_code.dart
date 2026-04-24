import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Use case: dispatch a verification code to the supplied email address.
class SendVerificationCode {
  final AuthRepository repository;

  const SendVerificationCode(this.repository);

  Future<Either<Failure, void>> call(String email) {
    return repository.sendVerificationCode(email);
  }
}

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

/// Use case: verify an OTP code for a given email and return the authenticated user.
class VerifyOtp {
  final AuthRepository repository;

  const VerifyOtp(this.repository);

  Future<Either<Failure, AuthUser>> call(String email, String code) {
    return repository.verifyOtp(email, code);
  }
}

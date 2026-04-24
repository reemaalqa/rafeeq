import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/auth_user.dart';

/// Abstract contract for authentication operations.
/// All implementations must honour the Either<Failure, T> return convention.
abstract class AuthRepository {
  /// Sends a verification code to [email].
  Future<Either<Failure, void>> sendVerificationCode(String email);

  /// Verifies [code] for [email] and returns the authenticated user on success.
  Future<Either<Failure, AuthUser>> verifyOtp(String email, String code);

  /// Clears local session data and marks the user as logged out.
  Future<Either<Failure, void>> logout();

  /// Returns [true] if a valid session currently exists.
  Future<Either<Failure, bool>> isLoggedIn();
}

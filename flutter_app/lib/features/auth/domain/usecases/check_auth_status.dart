import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Use case: determine whether a valid session currently exists.
class CheckAuthStatus {
  final AuthRepository repository;

  const CheckAuthStatus(this.repository);

  Future<Either<Failure, bool>> call() {
    return repository.isLoggedIn();
  }
}

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class GetProfile {
  final ProfileRepository repository;
  const GetProfile(this.repository);
  Future<Either<Failure, UserProfile?>> call() => repository.getProfile();
}

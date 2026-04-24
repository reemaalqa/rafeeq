import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class SaveProfile {
  final ProfileRepository repository;
  const SaveProfile(this.repository);
  Future<Either<Failure, void>> call(UserProfile profile) => repository.saveProfile(profile);
}

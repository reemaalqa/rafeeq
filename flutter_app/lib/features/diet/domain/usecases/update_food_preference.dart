import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/diet_repository.dart';

class UpdateFoodPreference {
  final DietRepository repository;
  const UpdateFoodPreference(this.repository);
  Future<Either<Failure, void>> call(String food, bool isDisliked) => repository.updateFoodPreference(food, isDisliked);
}

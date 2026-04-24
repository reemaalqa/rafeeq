import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/diet_repository.dart';

class GetFoodPreferences {
  final DietRepository repository;
  const GetFoodPreferences(this.repository);
  Future<Either<Failure, List<String>>> call() => repository.getFoodPreferences();
}

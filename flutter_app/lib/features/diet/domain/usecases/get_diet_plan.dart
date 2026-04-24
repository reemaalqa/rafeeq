import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/bmi_result.dart';
import '../entities/diet_plan.dart';
import '../repositories/diet_repository.dart';

class GetDietPlan {
  final DietRepository repository;
  const GetDietPlan(this.repository);
  Future<Either<Failure, DietPlan>> call({
    required BmiResult bmiResult,
    required List<String> dislikedFoods,
    required List<String> allergies,
    int rotationIndex = 0,
  }) =>
      repository.getDietPlan(
        bmiResult: bmiResult,
        dislikedFoods: dislikedFoods,
        allergies: allergies,
        rotationIndex: rotationIndex,
      );
}

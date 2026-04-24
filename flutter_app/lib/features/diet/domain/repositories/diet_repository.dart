import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/bmi_result.dart';
import '../entities/diet_plan.dart';
import '../entities/meal.dart';

abstract class DietRepository {
  Future<Either<Failure, BmiResult>> calculateBmi({required double heightCm, required double weightKg});
  Future<Either<Failure, DietPlan>> getDietPlan({
    required BmiResult bmiResult,
    required List<String> dislikedFoods,
    required List<String> allergies,
    int rotationIndex,
  });
  Future<Either<Failure, List<String>>> getFoodPreferences();
  Future<Either<Failure, void>> updateFoodPreference(String food, bool isDisliked);
  Future<Either<Failure, void>> markMealEaten(String mealId, bool eaten);
}

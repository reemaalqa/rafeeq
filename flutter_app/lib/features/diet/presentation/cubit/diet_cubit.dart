import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/meal.dart';
import '../../domain/usecases/calculate_bmi.dart';
import '../../domain/usecases/get_diet_plan.dart';
import '../../domain/usecases/get_food_preferences.dart';
import '../../domain/usecases/update_food_preference.dart';
import 'diet_state.dart';

class DietCubit extends Cubit<DietState> {
  final CalculateBmi _calculateBmi;
  final GetDietPlan _getDietPlan;
  final GetFoodPreferences _getPreferences;
  final UpdateFoodPreference _updatePreference;

  DietCubit({
    required CalculateBmi calculateBmi,
    required GetDietPlan getDietPlan,
    required GetFoodPreferences getPreferences,
    required UpdateFoodPreference updatePreference,
  })  : _calculateBmi = calculateBmi,
        _getDietPlan = getDietPlan,
        _getPreferences = getPreferences,
        _updatePreference = updatePreference,
        super(const DietState());

  Future<void> init({double? heightCm, double? weightKg, List<String> allergies = const []}) async {
    if (heightCm == null || weightKg == null || heightCm == 0 || weightKg == 0) {
      emit(state.copyWith(status: DietStatus.loaded, needsProfileSetup: true));
      return;
    }

    emit(state.copyWith(status: DietStatus.loading));

    final bmiResult = await _calculateBmi(heightCm: heightCm, weightKg: weightKg);
    if (bmiResult.isLeft()) {
      emit(state.copyWith(status: DietStatus.error, errorMessage: 'BMI calculation failed'));
      return;
    }
    final bmi = bmiResult.getOrElse(() => throw Error());

    final prefsResult = await _getPreferences();
    final prefs = prefsResult.getOrElse(() => []);

    final planResult = await _getDietPlan(bmiResult: bmi, dislikedFoods: prefs, allergies: allergies);
    planResult.fold(
      (f) => emit(state.copyWith(status: DietStatus.error, errorMessage: f.message)),
      (plan) => emit(state.copyWith(
        status: DietStatus.loaded,
        bmiResult: bmi,
        dietPlan: plan,
        dislikedFoods: prefs,
        allergies: allergies,
        needsProfileSetup: false,
      )),
    );
  }

  Future<void> toggleFoodPreference(String food) async {
    final isCurrentlyDisliked = state.dislikedFoods.contains(food);
    await _updatePreference(food, !isCurrentlyDisliked);

    final updated = List<String>.from(state.dislikedFoods);
    if (isCurrentlyDisliked) {
      updated.remove(food);
    } else {
      updated.add(food);
    }

    emit(state.copyWith(dislikedFoods: updated));

    final bmi = state.bmiResult;
    if (bmi == null) return;

    final planResult = await _getDietPlan(
      bmiResult: bmi,
      dislikedFoods: updated,
      allergies: state.allergies,
    );
    planResult.fold(
      (f) => emit(state.copyWith(status: DietStatus.error, errorMessage: f.message)),
      (plan) => emit(state.copyWith(
        status: DietStatus.loaded,
        dietPlan: plan,
        dislikedFoods: updated,
      )),
    );
  }

  void markMealEaten(String mealId) {
    if (state.dietPlan == null) return;
    final updated = state.dietPlan!.meals
        .map((m) => m.id == mealId ? m.copyWith(isEaten: !m.isEaten) : m)
        .toList();
    final newPlan = state.dietPlan!.copyWith(meals: updated);
    emit(state.copyWith(dietPlan: newPlan));
  }
}

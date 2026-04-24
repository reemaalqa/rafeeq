import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/bmi_result.dart';
import '../../domain/entities/diet_plan.dart';
import '../../domain/entities/meal.dart';
import '../../domain/repositories/diet_repository.dart';
import '../datasources/diet_local_datasource.dart';
import '../datasources/diet_remote_datasource.dart';

class DietRepositoryImpl implements DietRepository {
  final DietLocalDatasource _local;
  final DietRemoteDataSource _remote;

  const DietRepositoryImpl(this._local, this._remote);

  /// BMI calculation is pure math — always local.
  @override
  Future<Either<Failure, BmiResult>> calculateBmi({
    required double heightCm,
    required double weightKg,
  }) async {
    try {
      return Right(_local.calculateBmi(heightCm: heightCm, weightKg: weightKg));
    } catch (e) {
      return Left(ServerFailure('BMI calculation failed: $e'));
    }
  }

  /// Remote first: fetch meal suggestions from backend by BMI category.
  /// Falls back to locally generated plan if offline or no suggestions seeded yet.
  @override
  Future<Either<Failure, DietPlan>> getDietPlan({
    required BmiResult bmiResult,
    required List<String> dislikedFoods,
    required List<String> allergies,
    int rotationIndex = 0,
  }) async {
    final categoryKey = bmiResult.category.name; // e.g. "normal"
    final dislikes = {...dislikedFoods.map((f) => f.toLowerCase()), ...allergies.map((a) => a.toLowerCase())};

    try {
      final suggestions = await _remote.getMealSuggestions(categoryKey);
      if (suggestions.isNotEmpty) {
        // Group incoming Firestore docs by meal_type so rotation picks one
        // meal per slot rather than deduping at the whole-list level.
        final bySlot = <MealTime, List<Map<String, dynamic>>>{};
        for (final m in suggestions) {
          final mealTypeStr = m['meal_type'] as String? ?? 'breakfast';
          final slot = MealTime.values.firstWhere(
            (t) => t.name == mealTypeStr,
            orElse: () => MealTime.breakfast,
          );
          bySlot.putIfAbsent(slot, () => []).add(m);
        }

        bool passesAllergy(Map<String, dynamic> m) {
          final ings = List<String>.from(m['ingredients_ar'] as List? ?? const []);
          return !ings.any(
            (i) => dislikes.any((d) => d.isNotEmpty && i.toLowerCase().contains(d)),
          );
        }

        final result = <Meal>[];
        for (final slot in const [MealTime.breakfast, MealTime.lunch, MealTime.dinner, MealTime.snack]) {
          final slotMeals = bySlot[slot] ?? const <Map<String, dynamic>>[];
          if (slotMeals.isEmpty) continue;
          final compat = slotMeals.where(passesAllergy).toList();
          final pool = compat.isNotEmpty ? compat : slotMeals;
          final idx = ((rotationIndex + slot.hashCode.abs()) % pool.length).abs();
          final m = pool[idx];
          result.add(Meal(
            id: m['id'].toString(),
            name: m['name_ar'] as String,
            nameAr: m['name_ar'] as String,
            ingredients: List<String>.from(m['ingredients_ar'] as List? ?? const []),
            calories: (m['calories'] as num).toInt(),
            mealTime: slot,
          ));
        }
        if (result.isNotEmpty) {
          return Right(DietPlan(meals: result, targetCalories: bmiResult.recommendedCalories));
        }
      }
    } on NetworkException {
      // offline — fall through
    } catch (_) {
      // fall through
    }

    // Local fallback
    try {
      final plan = await _local.getDietPlan(
        bmiResult: bmiResult,
        dislikedFoods: dislikedFoods,
        allergies: allergies,
        rotationIndex: rotationIndex,
      );
      return Right(plan);
    } catch (e) {
      return Left(ServerFailure('Diet plan generation failed: $e'));
    }
  }

  /// Remote first: returns food preference name keys; local fallback.
  @override
  Future<Either<Failure, List<String>>> getFoodPreferences() async {
    try {
      final data = await _remote.getFoodPreferences();
      // data = [{ food_item_id, preference, food_item: { name_key } }]
      final disliked = data
          .where((p) =>
              p['preference'] == 'dislike' || p['preference'] == 'avoid')
          .map((p) {
            final item = p['food_item'] as Map<String, dynamic>?;
            return item?['name_key'] as String? ?? '';
          })
          .where((s) => s.isNotEmpty)
          .toList();
      // Sync to local cache
      await _local.saveFoodPreferences(disliked);
      return Right(disliked);
    } on NetworkException {
      // offline — fall through
    } catch (_) {
      // fall through
    }
    try {
      return Right(await _local.getFoodPreferences());
    } catch (_) {
      return const Left(CacheFailure('Failed to load food preferences'));
    }
  }

  @override
  Future<Either<Failure, void>> updateFoodPreference(
    String food,
    bool isDisliked,
  ) async {
    // Sync to backend best-effort (food is a name_key — need to find id)
    try {
      final foods = await _remote.getFoods();
      final match = foods.firstWhere(
        (f) => f['name_key'] == food,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        await _remote.upsertFoodPreference({
          'food_item_id': match['id'],
          'preference': isDisliked ? 'dislike' : 'like',
        });
      }
    } catch (_) {
      // best-effort
    }
    // Always update local
    try {
      final prefs = await _local.getFoodPreferences();
      if (isDisliked && !prefs.contains(food)) {
        prefs.add(food);
      } else if (!isDisliked) {
        prefs.remove(food);
      }
      await _local.saveFoodPreferences(prefs);
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to update food preference'));
    }
  }

  @override
  Future<Either<Failure, void>> markMealEaten(String mealId, bool eaten) async {
    return const Right(null); // UI state — managed in cubit
  }
}

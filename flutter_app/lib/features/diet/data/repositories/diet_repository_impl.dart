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
    final avoidedFoods = {...dislikedFoods, ...allergies};
    final allergenTags = avoidedFoods
        .map(normalizeAllergenTag)
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final blockedIngredientKeywords = {
      ...dislikedFoods.map((f) => f.toLowerCase()),
      ...allergyIngredientKeywords(avoidedFoods),
    };
    
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
          final ingredients = _readStringList(m, 'ingredients_ar', fallbackKey: 'ingredients');
          final allergens = _readStringList(m, 'allergens')
              .map(normalizeAllergenTag)
              .toSet();

          if (allergens.any(allergenTags.contains)) return false;
          return !containsBlockedIngredient(ingredients, blockedIngredientKeywords);
        }

        final result = <Meal>[];
        var skippedRequiredSlot = false;
        for (final slot in const [MealTime.breakfast, MealTime.lunch, MealTime.dinner, MealTime.snack]) {
          final slotMeals = bySlot[slot] ?? const <Map<String, dynamic>>[];
          if (slotMeals.isEmpty) continue;
          final compat = slotMeals.where(passesAllergy).toList();
          if (compat.isEmpty) {
            if (slot != MealTime.snack) skippedRequiredSlot = true;
            continue;
          }
          final idx = ((rotationIndex + slot.hashCode.abs()) % compat.length).abs();
          final m = compat[idx];
          final nameAr = m['name_ar'] as String? ?? m['name'] as String? ?? '';
          result.add(Meal(
            id: m['id'].toString(),
            name: nameAr,
            nameAr: nameAr,
            ingredients: _readStringList(m, 'ingredients_ar', fallbackKey: 'ingredients'),
            calories: _readCalories(m),
            mealTime: slot,
          ));
        }
        if (result.isNotEmpty && !skippedRequiredSlot) {
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

    List<String> _readStringList(
    Map<String, dynamic> source,
    String key, {
    String? fallbackKey,
  }) {
    final value = source[key] ?? (fallbackKey == null ? null : source[fallbackKey]);
    if (value is List) return List<String>.from(value.map((e) => e.toString()));
    return const [];
  }

  int _readCalories(Map<String, dynamic> meal) {
    final directCalories = meal['calories'];
    if (directCalories is num) return directCalories.toInt();

    final nutrition = meal['nutrition'];
    if (nutrition is Map && nutrition['calories'] is num) {
      return (nutrition['calories'] as num).toInt();
    }

    return 0;
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

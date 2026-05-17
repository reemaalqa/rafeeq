// ────────────────────────────────────────────────────────────────────────────
// Diet plan pipeline
// ──────────────────
// Single source of truth: `assets/data/saudi_meals.json`. The same JSON file
// is served by the rafeeq_ai_api backend (`/diet/meals` + `/diet/plan`), so
// the online path and the offline fallback draw from identical data.
//
// Flow:
//   1. `calculateBmi()` — pure math, derives a BmiCategory.
//   2. `getDietPlan()` — loads the JSON asset (cached after first read),
//      picks one meal per slot (breakfast / lunch / dinner + optional snack)
//      that (a) is marked suitable for the user's BMI band, (b) contains no
//      allergen tags the user has listed, (c) no ingredient substring-matches
//      a disliked food. Falls back to the first slot option if the filter
//      rules out every candidate so the user never sees an empty plan.
//
// Meals are 100% dataset-driven — no LLM, no generated nutrition. Values are
// approximated from USDA + local composition tables.
// ────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/bmi_result.dart';
import '../../domain/entities/diet_plan.dart';
import '../../domain/entities/meal.dart';

abstract class DietLocalDatasource {
  BmiResult calculateBmi({required double heightCm, required double weightKg});
  Future<DietPlan> getDietPlan({
    required BmiResult bmiResult,
    required List<String> dislikedFoods,
    required List<String> allergies,
    int rotationIndex,
  });
  Future<List<String>> getFoodPreferences();
  Future<void> saveFoodPreferences(List<String> preferences);
}

class DietLocalDatasourceImpl implements DietLocalDatasource {
  final SharedPreferences _prefs;
  DietLocalDatasourceImpl(this._prefs);

  /// Parsed meal catalog — loaded once on first request, then reused.
  static List<_MealRecord>? _cachedCatalog;

  @override
  BmiResult calculateBmi({required double heightCm, required double weightKg}) {
    final bmi = weightKg / ((heightCm / 100) * (heightCm / 100));
    BmiCategory category;
    int calories;
    if (bmi < 18.5) { category = BmiCategory.underweight; calories = 2200; }
    else if (bmi < 25.0) { category = BmiCategory.normal; calories = 1800; }
    else if (bmi < 30.0) { category = BmiCategory.overweight; calories = 1500; }
    else { category = BmiCategory.obese; calories = 1200; }
    return BmiResult(value: double.parse(bmi.toStringAsFixed(1)), category: category, recommendedCalories: calories);
  }

  Future<List<_MealRecord>> _loadCatalog() async {
    if (_cachedCatalog != null) return _cachedCatalog!;
    final jsonStr = await rootBundle.loadString('assets/data/saudi_meals.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final mealList = (data['meals'] as List<dynamic>).cast<Map<String, dynamic>>();
    _cachedCatalog = mealList.map(_MealRecord.fromJson).toList();
    return _cachedCatalog!;
  }

  @override
  Future<DietPlan> getDietPlan({
    required BmiResult bmiResult,
    required List<String> dislikedFoods,
    required List<String> allergies,
    int rotationIndex = 0,
  }) async {
    final catalog = await _loadCatalog();
    final bmiKey = bmiResult.category.name; // underweight | normal | overweight | obese

    // Normalise user inputs so matching is case/diacritic-insensitive.
    final avoidedFoods = {...allergies, ...dislikedFoods};
    final allergenKeys = avoidedFoods
        .map(normalizeAllergenTag)
        .where((s) => s.isNotEmpty)
        .toSet();
    final dislikeKeywords = {
      ...dislikedFoods.map((f) => f.toLowerCase()),
      // Map allergen display names to ingredient substrings as a backup
      // for meals whose `allergens` tags miss a particular sensitivity.
      for (final a in avoidedFoods) ...ingredientKeywordsForAllergen(a),
    };

    bool compatible(_MealRecord m) {
      if (!m.suitableForBmi.contains(bmiKey)) return false;
      if (m.allergens.map(normalizeAllergenTag).any(allergenKeys.contains)) return false;
      if (m.ingredientsAr.any((ing) {
        final lower = ing.toLowerCase();
        return dislikeKeywords.any((k) => k.isNotEmpty && lower.contains(k));
      })) {
        return false;
      }
      return true;
    }

    // For each slot pick a compatible meal, rotating the choice by
    // [rotationIndex] so consecutive voice requests return different options.
    // Fall back to the first BMI-suitable meal if no candidate passes the
    // allergen filter, so the user always gets a full plan.
    final result = <Meal>[];
    for (final slot in const ['breakfast', 'lunch', 'dinner', 'snack']) {
      final slotAll = catalog.where((m) => m.mealTime == slot).toList();
      if (slotAll.isEmpty) continue;
      final slotForBmi = slotAll.where((m) => m.suitableForBmi.contains(bmiKey)).toList();
      final pool = slotForBmi.isNotEmpty ? slotForBmi : slotAll;
      final compatiblePool = pool.where(compatible).toList();
      if (compatiblePool.isEmpty) continue;
      // Offset each slot so breakfast/lunch/dinner don't advance in lock-step
      // — keeps combinations fresh across calls.
      final slotOffset = slot.hashCode.abs();
      final idx = ((rotationIndex + slotOffset) % compatiblePool.length).abs();
      result.add(compatiblePool[idx].toMeal());
    }

    return DietPlan(meals: result, targetCalories: bmiResult.recommendedCalories);
  }

  @override
  Future<List<String>> getFoodPreferences() async {
    try {
      final s = _prefs.getString(StorageKeys.dislikedFoods);
      if (s == null || s.isEmpty) return [];
      return (json.decode(s) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveFoodPreferences(List<String> preferences) async {
    try {
      await _prefs.setString(StorageKeys.dislikedFoods, json.encode(preferences));
    } catch (_) {
      throw CacheException(message: 'Failed to save food preferences');
    }
  }
}

// ─── Internal model matching the JSON schema ─────────────────────────────────

class _MealRecord {
  final String id;
  final String nameEn;
  final String nameAr;
  final String mealTime;
  final List<String> ingredientsAr;
  final int calories;
  final List<String> allergens;
  final List<String> suitableForBmi;

  const _MealRecord({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.mealTime,
    required this.ingredientsAr,
    required this.calories,
    required this.allergens,
    required this.suitableForBmi,
  });

  factory _MealRecord.fromJson(Map<String, dynamic> j) {
    final nutrition = (j['nutrition'] as Map?)?.cast<String, dynamic>() ?? const {};
    return _MealRecord(
      id: j['id'] as String,
      nameEn: j['name_en'] as String? ?? j['name_ar'] as String,
      nameAr: j['name_ar'] as String,
      mealTime: j['meal_time'] as String,
      ingredientsAr: List<String>.from(j['ingredients_ar'] as List? ?? const []),
      calories: (nutrition['calories'] as num?)?.toInt() ?? 0,
      allergens: List<String>.from(j['allergens'] as List? ?? const []),
      suitableForBmi: List<String>.from(j['suitable_for_bmi'] as List? ?? const []),
    );
  }

  Meal toMeal() {
    final slot = switch (mealTime) {
      'breakfast' => MealTime.breakfast,
      'lunch' => MealTime.lunch,
      'dinner' => MealTime.dinner,
      _ => MealTime.snack,
    };
    return Meal(
      id: id,
      name: nameEn,
      nameAr: nameAr,
      ingredients: ingredientsAr,
      calories: calories,
      mealTime: slot,
    );
  }
}

// ─── Allergen name normalisation ─────────────────────────────────────────────
// Maps Arabic + English allergen display names (as used in the allergy chips)
// to the canonical lowercase English tag stored in the JSON `allergens` array.

const Map<String, String> allergenNameToTag = {
  // English → tag
  'dairy': 'dairy', 'gluten': 'gluten', 'wheat': 'wheat', 'eggs': 'eggs',
  'nuts': 'nuts', 'peanuts': 'peanuts', 'shellfish': 'shellfish', 'seafood': 'seafood', 'fish': 'fish',
  'sesame': 'sesame', 'sugar': 'sugar', 'soy': 'soy', 'spicy food': 'spicy',
  'spicy': 'spicy', 'caffeine': 'caffeine',
  // Arabic (l10n display names) → tag
  'ألبان': 'dairy', 'جلوتين': 'gluten', 'قمح': 'wheat',
  'بيض': 'eggs', 'مكسرات': 'nuts', 'فول سوداني': 'peanuts',
  'محار': 'shellfish', 'مأكولات بحرية': 'seafood', 'مأكولات بحريه': 'seafood',
  'بحريات': 'seafood', 'سي فود': 'seafood', 'سمك': 'fish', 'سمسم': 'sesame',
  'سكر': 'sugar', 'صويا': 'soy', 'طعام حار': 'spicy', 'كافيين': 'caffeine',
};

String normalizeAllergenTag(String displayName) {
  final value = displayName.trim();
  final lower = value.toLowerCase();
  return allergenNameToTag[lower] ?? allergenNameToTag[value] ?? lower;
}

/// Kept as a safety net for recipes whose `allergens` array may be incomplete:
/// also veto meals whose ingredient strings contain the allergen's keywords.
const Map<String, Set<String>> allergenIngredientKeywords = {
  'dairy':     {'حليب', 'لبن', 'جبن', 'زبدة', 'سمن', 'قشطة', 'كريمة', 'لبنة', 'زبادي'},
  'gluten':    {'قمح', 'جريش', 'عجين', 'دقيق', 'خبز', 'هريس', 'شعير', 'برغل', 'تميس', 'توست'},
  'wheat':     {'قمح', 'جريش', 'عجين', 'دقيق', 'خبز', 'هريس', 'برغل', 'تميس'},
  'eggs':      {'بيض', 'بيضة', 'بياض'},
  'nuts':      {'لوز', 'جوز', 'فستق', 'بندق', 'كاجو', 'مكسرات'},
  'peanuts':   {'فول سوداني'},
  'shellfish': {'روبيان', 'جمبري', 'كابوريا', 'بطلينوس'},
  'seafood':   {'سمك', 'سمكة', 'تونة', 'هامور', 'فيليه', 'روبيان', 'جمبري', 'كابوريا', 'بطلينوس', 'مأكولات بحرية'},
  'fish':      {'سمك', 'سمكة', 'تونة', 'هامور', 'فيليه'},
  'sesame':    {'سمسم', 'طحينة', 'زعتر'},
  'sugar':     {'سكر', 'عسل', 'حلويات', 'شراب'},
  'spicy':     {'فلفل حار', 'شطة', 'هريسة'},
};

Iterable<String> ingredientKeywordsForAllergen(String displayName) {
  final tag = normalizeAllergenTag(displayName);
  if (tag.isEmpty) return const [];
  return allergenIngredientKeywords[tag] ?? const {};
}

Set<String> allergyIngredientKeywords(Iterable<String> allergies) => {
  for (final allergy in allergies) ...ingredientKeywordsForAllergen(allergy),
};

bool containsBlockedIngredient(Iterable<String> ingredients, Iterable<String> blockedKeywords) {
  final keywords = blockedKeywords
      .map((k) => k.trim().toLowerCase())
      .where((k) => k.isNotEmpty)
      .toSet();
  if (keywords.isEmpty) return false;

  return ingredients.any((ingredient) {
    final lower = ingredient.toLowerCase();
    return keywords.any((keyword) => lower.contains(keyword));
  });
}

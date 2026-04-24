import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_helpers.dart';

abstract class DietRemoteDataSource {
  Future<List<Map<String, dynamic>>> getMealSuggestions(String bmiCategory);
  Future<List<Map<String, dynamic>>> getFoods({String? category, bool halalOnly = true});
  Future<List<Map<String, dynamic>>> getDietPlans();
  Future<Map<String, dynamic>> createDietPlan(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateDietPlan(String id, Map<String, dynamic> data);
  Future<void> deleteDietPlan(String id);
  Future<List<Map<String, dynamic>>> getMeals(String planId);
  Future<Map<String, dynamic>> createMeal(String planId, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getFoodPreferences();
  Future<void> upsertFoodPreference(Map<String, dynamic> data);
}

class DietRemoteDataSourceImpl implements DietRemoteDataSource {
  final FirebaseHelpers _fb;
  DietRemoteDataSourceImpl({FirebaseHelpers? fb}) : _fb = fb ?? FirebaseHelpers();

  @override
  Future<List<Map<String, dynamic>>> getMealSuggestions(String bmiCategory) async {
    final qs = await _fb.firestore
        .collection('mealSuggestions')
        .where('isActive', isEqualTo: true)
        .where('bmiCategory', isEqualTo: bmiCategory)
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<List<Map<String, dynamic>>> getFoods({String? category, bool halalOnly = true}) async {
    Query<Map<String, dynamic>> q = _fb.firestore
        .collection('foodItems')
        .where('isActive', isEqualTo: true);
    if (category != null) q = q.where('category', isEqualTo: category);
    if (halalOnly) q = q.where('isHalal', isEqualTo: true);
    final qs = await q.get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<List<Map<String, dynamic>>> getDietPlans() async {
    final qs = await _fb
        .userSub('dietPlans')
        .orderBy('createdAt', descending: true)
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<Map<String, dynamic>> createDietPlan(Map<String, dynamic> data) async {
    final ref = await _fb.userSub('dietPlans').add({
      ...data,
      'isActive': data['isActive'] ?? true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snap = await ref.get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<Map<String, dynamic>> updateDietPlan(String id, Map<String, dynamic> data) async {
    await _fb.userSub('dietPlans').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await _fb.userSub('dietPlans').doc(id).get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<void> deleteDietPlan(String id) async {
    await _fb.userSub('dietPlans').doc(id).delete();
  }

  @override
  Future<List<Map<String, dynamic>>> getMeals(String planId) async {
    final qs = await _fb
        .userSub('dietPlans')
        .doc(planId)
        .collection('meals')
        .orderBy('mealDate')
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<Map<String, dynamic>> createMeal(String planId, Map<String, dynamic> data) async {
    final ref = await _fb
        .userSub('dietPlans')
        .doc(planId)
        .collection('meals')
        .add({...data, 'createdAt': FieldValue.serverTimestamp()});
    final snap = await ref.get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<List<Map<String, dynamic>>> getFoodPreferences() async {
    final qs = await _fb.userSub('foodPreferences').get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<void> upsertFoodPreference(Map<String, dynamic> data) async {
    final foodItemId = data['foodItemId'] ?? data['food_item_id'];
    if (foodItemId == null) {
      throw ArgumentError('foodItemId is required');
    }
    await _fb.userSub('foodPreferences').doc(foodItemId.toString()).set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}

import '../../domain/entities/meal.dart';

class MealModel extends Meal {
  const MealModel({
    required super.id, required super.name, required super.nameAr,
    required super.ingredients, required super.calories, required super.mealTime,
    super.isEaten,
  });

  factory MealModel.fromEntity(Meal m) => MealModel(
    id: m.id, name: m.name, nameAr: m.nameAr, ingredients: m.ingredients,
    calories: m.calories, mealTime: m.mealTime, isEaten: m.isEaten,
  );
}

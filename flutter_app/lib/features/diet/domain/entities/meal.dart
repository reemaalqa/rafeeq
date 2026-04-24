import 'package:equatable/equatable.dart';

enum MealTime { breakfast, lunch, dinner, snack }

class Meal extends Equatable {
  final String id;
  final String name;
  final String nameAr;
  final List<String> ingredients;
  final int calories;
  final MealTime mealTime;
  final bool isEaten;

  const Meal({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.ingredients,
    required this.calories,
    required this.mealTime,
    this.isEaten = false,
  });

  Meal copyWith({String? id, String? name, String? nameAr, List<String>? ingredients, int? calories, MealTime? mealTime, bool? isEaten}) {
    return Meal(id: id ?? this.id, name: name ?? this.name, nameAr: nameAr ?? this.nameAr, ingredients: ingredients ?? this.ingredients, calories: calories ?? this.calories, mealTime: mealTime ?? this.mealTime, isEaten: isEaten ?? this.isEaten);
  }

  @override
  List<Object?> get props => [id, name, nameAr, ingredients, calories, mealTime, isEaten];
}

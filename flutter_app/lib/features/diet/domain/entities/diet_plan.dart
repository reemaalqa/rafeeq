import 'package:equatable/equatable.dart';
import 'meal.dart';

class DietPlan extends Equatable {
  final List<Meal> meals;
  final int targetCalories;

  const DietPlan({required this.meals, required this.targetCalories});

  int get consumedCalories => meals.where((m) => m.isEaten).fold(0, (sum, m) => sum + m.calories);
  int get remainingCalories => targetCalories - consumedCalories;
  double get progress => targetCalories > 0 ? consumedCalories / targetCalories : 0;

  DietPlan copyWith({List<Meal>? meals, int? targetCalories}) {
    return DietPlan(meals: meals ?? this.meals, targetCalories: targetCalories ?? this.targetCalories);
  }

  @override
  List<Object?> get props => [meals, targetCalories];
}

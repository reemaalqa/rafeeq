import 'package:equatable/equatable.dart';

enum BmiCategory { underweight, normal, overweight, obese }

class BmiResult extends Equatable {
  final double value;
  final BmiCategory category;
  final int recommendedCalories;

  const BmiResult({
    required this.value,
    required this.category,
    required this.recommendedCalories,
  });

  @override
  List<Object?> get props => [value, category, recommendedCalories];
}

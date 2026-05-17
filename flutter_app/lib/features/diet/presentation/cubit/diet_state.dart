import 'package:equatable/equatable.dart';
import '../../domain/entities/bmi_result.dart';
import '../../domain/entities/diet_plan.dart';
import '../../domain/entities/meal.dart';

enum DietStatus { initial, loading, loaded, error }

class DietState extends Equatable {
  final DietPlan? dietPlan;
  final BmiResult? bmiResult;
  final List<String> dislikedFoods;
  final List<String> allergies;
  final DietStatus status;
  final String? errorMessage;
  final bool needsProfileSetup;

  const DietState({
    this.dietPlan,
    this.bmiResult,
    this.dislikedFoods = const [],
    this.allergies = const [],
    this.status = DietStatus.initial,
    this.errorMessage,
    this.needsProfileSetup = false,
  });

  DietState copyWith({
    DietPlan? dietPlan,
    BmiResult? bmiResult,
    List<String>? dislikedFoods,
    List<String>? allergies,
    DietStatus? status,
    String? errorMessage,
    bool? needsProfileSetup,
  }) {
    return DietState(
      dietPlan: dietPlan ?? this.dietPlan,
      bmiResult: bmiResult ?? this.bmiResult,
      dislikedFoods: dislikedFoods ?? this.dislikedFoods,
      allergies: allergies ?? this.allergies,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      needsProfileSetup: needsProfileSetup ?? this.needsProfileSetup,
    );
  }

  @override
  List<Object?> get props => [dietPlan, bmiResult, dislikedFoods, allergies, status, errorMessage, needsProfileSetup];
}

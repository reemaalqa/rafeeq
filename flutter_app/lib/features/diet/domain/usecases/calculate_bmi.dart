import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/bmi_result.dart';
import '../repositories/diet_repository.dart';

class CalculateBmi {
  final DietRepository repository;
  const CalculateBmi(this.repository);
  Future<Either<Failure, BmiResult>> call({required double heightCm, required double weightKg}) =>
      repository.calculateBmi(heightCm: heightCm, weightKg: weightKg);
}

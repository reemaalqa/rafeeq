import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/islamic_advice.dart';
import '../repositories/islamic_repository.dart';

class GetDailyAdvice {
  final IslamicRepository repository;
  const GetDailyAdvice(this.repository);

  Future<Either<Failure, IslamicAdvice>> call() async {
    final result = await repository.getAdviceList();
    return result.map((list) {
      final dayOfYear = _dayOfYear(DateTime.now());
      return list[dayOfYear % list.length];
    });
  }

  int _dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays;
  }
}

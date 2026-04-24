import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/islamic_advice.dart';
import '../repositories/islamic_repository.dart';

/// Returns the full advice catalog — used by the voice assistant to rotate
/// through entries on consecutive "نصيحة" requests instead of repeating the
/// same daily advice that [GetDailyAdvice] returns.
class GetAdviceList {
  final IslamicRepository repository;
  const GetAdviceList(this.repository);

  Future<Either<Failure, List<IslamicAdvice>>> call() =>
      repository.getAdviceList();
}

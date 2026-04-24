import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/surah.dart';
import '../repositories/islamic_repository.dart';

class GetSurahs {
  final IslamicRepository repository;
  const GetSurahs(this.repository);
  Future<Either<Failure, List<Surah>>> call() => repository.getSurahs();
}

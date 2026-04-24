import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/surah.dart';
import '../entities/islamic_advice.dart';
import '../entities/prayer_times.dart';

abstract class IslamicRepository {
  Future<Either<Failure, List<Surah>>> getSurahs();
  Future<Either<Failure, List<IslamicAdvice>>> getAdviceList();
  Future<Either<Failure, PrayerTimes>> getPrayerTimes({required double lat, required double lng});
}

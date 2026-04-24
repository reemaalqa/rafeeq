import 'dart:math' as math;
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/prayer_times.dart';
import '../repositories/islamic_repository.dart';

class CalculatePrayerTimes {
  final IslamicRepository repository;
  const CalculatePrayerTimes(this.repository);

  Future<Either<Failure, PrayerTimes>> call({required double lat, required double lng}) {
    return repository.getPrayerTimes(lat: lat, lng: lng);
  }
}

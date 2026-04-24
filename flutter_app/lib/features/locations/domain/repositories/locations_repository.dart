import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/error/failures.dart';
import '../entities/place.dart';

abstract class LocationsRepository {
  /// Returns a filtered list of places for the given [category].
  Future<Either<Failure, List<Place>>> getPlacesByCategory(
    PlaceCategory category,
  );

  /// Returns the device's current GPS position.
  Future<Either<Failure, Position>> getCurrentLocation();
}

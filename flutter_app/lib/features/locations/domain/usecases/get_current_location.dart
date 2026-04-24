import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/error/failures.dart';
import '../repositories/locations_repository.dart';

class GetCurrentLocation {
  final LocationsRepository _repository;

  const GetCurrentLocation(this._repository);

  Future<Either<Failure, Position>> call() {
    return _repository.getCurrentLocation();
  }
}

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/place.dart';
import '../repositories/locations_repository.dart';

class GetPlacesByCategory {
  final LocationsRepository _repository;

  const GetPlacesByCategory(this._repository);

  Future<Either<Failure, List<Place>>> call(PlaceCategory category) {
    return _repository.getPlacesByCategory(category);
  }
}

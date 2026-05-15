import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/locations_repository.dart';
import '../datasources/locations_local_datasource.dart';
import '../datasources/locations_remote_datasource.dart';

class LocationsRepositoryImpl implements LocationsRepository {
  final LocationsLocalDatasource _local;
  final LocationsRemoteDataSource _remote;

  const LocationsRepositoryImpl(this._local, this._remote);

  /// Maps backend location_type string to domain PlaceCategory.
  PlaceCategory _categoryFromString(String? s) {
    switch (s) {
      case 'mosque':   return PlaceCategory.mosque;
      case 'hospital': return PlaceCategory.hospital;
      case 'clinic':   return PlaceCategory.clinic;
      case 'pharmacy': return PlaceCategory.pharmacy;
      default:         return PlaceCategory.mosque;
    }
  }

  String _categoryToString(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.mosque:     return 'mosque';
      case PlaceCategory.hospital:   return 'hospital';
      case PlaceCategory.clinic:     return 'clinic';
      case PlaceCategory.pharmacy:   return 'pharmacy';
      case PlaceCategory.park:       return 'other';
      case PlaceCategory.restaurant: return 'other';
    }
  }

  Place _fromMap(Map<String, dynamic> m) => Place(
        id: m['id'].toString(),
        name: m['name'] as String? ?? '',
        nameAr: m['name'] as String? ?? '',
        category: _categoryFromString(m['location_type'] as String?),
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        address: m['address'] as String? ?? '',
        phone: m['phone_number'] as String?,
      );

  @override
  Future<Either<Failure, List<Place>>> getPlacesByCategory(
    PlaceCategory category,
  ) async {
    if (category == PlaceCategory.hospital) {
      try {
        final hospitals = await _local.getPlacesByCategory(category);
        return Right(hospitals);
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (_) {
        return const Left(CacheFailure('Failed to load hospitals'));
      }
    }

    if (category == PlaceCategory.mosque) {
      try {
        final mosques = await _local.getPlacesByCategory(category);
        return Right(mosques);
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (_) {
        return const Left(CacheFailure('Failed to load mosques'));
      }
    }
    
    // Keep all other categories on the existing local fallback path.
    try {
      final data = await _remote.getSavedLocations(
        locationType: _categoryToString(category),
      );
      if (data.isNotEmpty) {
        return Right(data.map(_fromMap).toList());
      }
    } on NetworkException {
      // offline — fall through
    } catch (_) {
      // fall through
    }
    // Local static fallback
    try {
      final places = await _local.getPlacesByCategory(category);
      return Right(places);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (_) {
      return const Left(CacheFailure('Failed to load places'));
    }
  }

  @override
  Future<Either<Failure, Position>> getCurrentLocation() async {
    try {
      return Right(await _local.getCurrentLocation());
    } on PermissionException catch (e) {
      return Left(PermissionFailure(e.message));
    } on LocationException catch (e) {
      return Left(LocationFailure(e.message));
    } catch (_) {
      return const Left(
          LocationFailure('Failed to determine current location'));
    }
  }
}

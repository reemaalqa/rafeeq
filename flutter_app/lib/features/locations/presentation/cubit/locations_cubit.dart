import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/place.dart';
import '../../domain/usecases/get_current_location.dart';
import '../../domain/usecases/get_places_by_category.dart';
import '../../domain/usecases/launch_directions.dart';
import 'locations_state.dart';

class LocationsCubit extends Cubit<LocationsState> {
  final GetPlacesByCategory _getPlaces;
  final GetCurrentLocation _getCurrentLocation;
  final LaunchDirections _launchDirections;

  LocationsCubit({
    required GetPlacesByCategory getPlaces,
    required GetCurrentLocation getCurrentLocation,
    required LaunchDirections launchDirections,
  })  : _getPlaces = getPlaces,
        _getCurrentLocation = getCurrentLocation,
        _launchDirections = launchDirections,
        super(const LocationsState());

  // ---------------------------------------------------------------------------
  // Public interface
  // ---------------------------------------------------------------------------

  /// Initialises the feature: resolves the device location first, then loads
  /// [initialCategory] (defaults to mosque when not specified).
  Future<void> init({PlaceCategory? initialCategory}) async {
    emit(state.copyWith(status: LocationsStatus.loading));

    final locationResult = await _getCurrentLocation();
    locationResult.fold(
      (failure) {
        emit(state.copyWith(status: LocationsStatus.noPermission));
      },
      (position) {
        emit(state.copyWith(currentPosition: position));
        loadCategory(initialCategory ?? PlaceCategory.mosque);
      },
    );
  }

  /// Switches the selected category and fetches its places.
  Future<void> loadCategory(PlaceCategory category) async {
    emit(
      state.copyWith(
        status: LocationsStatus.loading,
        selectedCategory: category,
      ),
    );

    final result = await _getPlaces(category);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LocationsStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (places) => emit(
        state.copyWith(
          status: LocationsStatus.loaded,
          places: _preparePlacesForDisplay(category, places),
        ),
      ),
    );
  }


  List<Place> _preparePlacesForDisplay(
    PlaceCategory category,
    List<Place> places,
  ) {
    if (category != PlaceCategory.mosque && category != PlaceCategory.hospital) {
      return places;
    }

    final sorted = List<Place>.from(places);
    final position = state.currentPosition;
    if (position != null) {
      sorted.sort((a, b) {
        final aDistance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          a.latitude,
          a.longitude,
        );
        final bDistance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          b.latitude,
          b.longitude,
        );
        return aDistance.compareTo(bDistance);
      });
    }

    return sorted.take(20).toList(growable: false);
  }

  

  /// Opens Google Maps directions to [place] via the system browser or Maps
  /// app.  Errors are swallowed because a failed launch should not block the
  /// UI — the launcher logs internally.
  Future<void> launchDirections(Place place) async {
    await _launchDirections(place);
  }
}

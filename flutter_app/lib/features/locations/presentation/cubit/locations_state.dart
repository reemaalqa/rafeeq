import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/place.dart';

enum LocationsStatus { initial, loading, loaded, error, noPermission }

class LocationsState extends Equatable {
  final List<Place> places;
  final PlaceCategory selectedCategory;
  final Position? currentPosition;
  final LocationsStatus status;
  final String? errorMessage;

  const LocationsState({
    this.places = const [],
    this.selectedCategory = PlaceCategory.mosque,
    this.currentPosition,
    this.status = LocationsStatus.initial,
    this.errorMessage,
  });

  LocationsState copyWith({
    List<Place>? places,
    PlaceCategory? selectedCategory,
    Position? currentPosition,
    LocationsStatus? status,
    String? errorMessage,
  }) {
    return LocationsState(
      places: places ?? this.places,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      currentPosition: currentPosition ?? this.currentPosition,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        places,
        selectedCategory,
        currentPosition,
        status,
        errorMessage,
      ];
}

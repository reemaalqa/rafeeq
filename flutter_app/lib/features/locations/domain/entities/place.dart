import 'package:equatable/equatable.dart';

enum PlaceCategory { mosque, hospital, clinic, pharmacy, park, restaurant }

class Place extends Equatable {
  final String id;
  final String name;
  final String nameAr;
  final PlaceCategory category;
  final double latitude;
  final double longitude;
  final String address;
  final String? phone;

  const Place({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.phone,
  });

  Place copyWith({
    String? id,
    String? name,
    String? nameAr,
    PlaceCategory? category,
    double? latitude,
    double? longitude,
    String? address,
    String? phone,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      phone: phone ?? this.phone,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        nameAr,
        category,
        latitude,
        longitude,
        address,
        phone,
      ];
}

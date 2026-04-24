import '../../domain/entities/place.dart';

/// Data-layer representation of [Place] with JSON serialisation support.
class PlaceModel extends Place {
  const PlaceModel({
    required super.id,
    required super.name,
    required super.nameAr,
    required super.category,
    required super.latitude,
    required super.longitude,
    required super.address,
    super.phone,
  });

  // ── Factories ────────────────────────────────────────────────────────────────

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      category: PlaceCategory.values.firstWhere(
        (e) => e.name == (json['category'] as String),
      ),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String,
      phone: json['phone'] as String?,
    );
  }

  factory PlaceModel.fromEntity(Place entity) {
    return PlaceModel(
      id: entity.id,
      name: entity.name,
      nameAr: entity.nameAr,
      category: entity.category,
      latitude: entity.latitude,
      longitude: entity.longitude,
      address: entity.address,
      phone: entity.phone,
    );
  }

  // ── Serialisation ────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
      'category': category.name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phone': phone,
    };
  }
}

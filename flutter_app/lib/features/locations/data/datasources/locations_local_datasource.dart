import 'package:geolocator/geolocator.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/place.dart';
import '../models/place_model.dart';

abstract class LocationsLocalDatasource {
  /// Returns all hardcoded places that belong to [category].
  Future<List<PlaceModel>> getPlacesByCategory(PlaceCategory category);

  /// Requests location permission (if not already granted) and returns the
  /// device's current [Position].
  Future<Position> getCurrentLocation();
}

// ── Implementation ────────────────────────────────────────────────────────────

class LocationsLocalDatasourceImpl implements LocationsLocalDatasource {
  const LocationsLocalDatasourceImpl();

  // ---------------------------------------------------------------------------
  // Static hardcoded Riyadh places data (offline-first, no API key required)
  // ---------------------------------------------------------------------------

  static const List<PlaceModel> _allPlaces = [
    // ── Mosques ───────────────────────────────────────────────────────────────
    PlaceModel(
      id: 'mosque_001',
      name: 'المسجد الحرام',
      nameAr: 'المسجد الحرام',
      category: PlaceCategory.mosque,
      latitude: 24.4239,
      longitude: 39.8262,
      address: 'مكة المكرمة، المملكة العربية السعودية',
      phone: '+966125500000',
    ),
    PlaceModel(
      id: 'mosque_002',
      name: 'مسجد الملك فهد',
      nameAr: 'مسجد الملك فهد',
      category: PlaceCategory.mosque,
      latitude: 24.7136,
      longitude: 46.6753,
      address: 'طريق الملك فهد، حي العليا، الرياض',
    ),
    PlaceModel(
      id: 'mosque_003',
      name: 'مسجد الراجحي',
      nameAr: 'مسجد الراجحي',
      category: PlaceCategory.mosque,
      latitude: 24.6920,
      longitude: 46.7080,
      address: 'حي البطحاء، وسط الرياض',
    ),

    // ── Hospitals ─────────────────────────────────────────────────────────────
    PlaceModel(
      id: 'hospital_001',
      name: 'مستشفى الملك فيصل التخصصي',
      nameAr: 'مستشفى الملك فيصل التخصصي',
      category: PlaceCategory.hospital,
      latitude: 24.7090,
      longitude: 46.6733,
      address: 'شارع الزهراوي، حي العليا، الرياض',
      phone: '+966114647272',
    ),
    PlaceModel(
      id: 'hospital_002',
      name: 'مستشفى الحرس الوطني',
      nameAr: 'مستشفى الحرس الوطني',
      category: PlaceCategory.hospital,
      latitude: 24.7500,
      longitude: 46.7550,
      address: 'طريق الملك عبدالعزيز، حي الشميسي، الرياض',
      phone: '+966114291000',
    ),
    PlaceModel(
      id: 'hospital_003',
      name: 'مستشفى الملك خالد الجامعي',
      nameAr: 'مستشفى الملك خالد الجامعي',
      category: PlaceCategory.hospital,
      latitude: 24.6930,
      longitude: 46.7190,
      address: 'طريق الملك عبدالله، حي الدرعية، الرياض',
      phone: '+966114670011',
    ),

    // ── Clinics ───────────────────────────────────────────────────────────────
    PlaceModel(
      id: 'clinic_001',
      name: 'عيادة السلام',
      nameAr: 'عيادة السلام',
      category: PlaceCategory.clinic,
      latitude: 24.6952,
      longitude: 46.6875,
      address: 'حي العليا، شارع العروبة، الرياض',
      phone: '+966114780000',
    ),
    PlaceModel(
      id: 'clinic_002',
      name: 'عيادة رعاية الأسرة',
      nameAr: 'عيادة رعاية الأسرة',
      category: PlaceCategory.clinic,
      latitude: 24.7200,
      longitude: 46.6900,
      address: 'حي الملز، شارع الستين، الرياض',
      phone: '+966114563000',
    ),
    PlaceModel(
      id: 'clinic_003',
      name: 'مركز الحياة الطبي',
      nameAr: 'مركز الحياة الطبي',
      category: PlaceCategory.clinic,
      latitude: 24.7050,
      longitude: 46.7300,
      address: 'حي الروضة، طريق الأمير سلطان، الرياض',
      phone: '+966114227000',
    ),

    // ── Pharmacies ────────────────────────────────────────────────────────────
    PlaceModel(
      id: 'pharmacy_001',
      name: 'صيدلية النهدي',
      nameAr: 'صيدلية النهدي',
      category: PlaceCategory.pharmacy,
      latitude: 24.7000,
      longitude: 46.7000,
      address: 'الشارع العام، حي العليا، الرياض',
      phone: '+966114001234',
    ),
    PlaceModel(
      id: 'pharmacy_002',
      name: 'صيدلية الدواء',
      nameAr: 'صيدلية الدواء',
      category: PlaceCategory.pharmacy,
      latitude: 24.6800,
      longitude: 46.7200,
      address: 'داخل مركز العثيم التجاري، الرياض',
      phone: '+966114005678',
    ),
    PlaceModel(
      id: 'pharmacy_003',
      name: 'الصيدلية المتحدة',
      nameAr: 'الصيدلية المتحدة',
      category: PlaceCategory.pharmacy,
      latitude: 24.7150,
      longitude: 46.6850,
      address: 'حي النزهة، طريق الملك عبدالله، الرياض',
      phone: '+966114009900',
    ),

    // ── Parks ─────────────────────────────────────────────────────────────────
    PlaceModel(
      id: 'park_001',
      name: 'حديقة الملك عبدالله',
      nameAr: 'حديقة الملك عبدالله',
      category: PlaceCategory.park,
      latitude: 24.7450,
      longitude: 46.6500,
      address: 'طريق الملك عبدالله، حي الياسمين، الرياض',
    ),
    PlaceModel(
      id: 'park_002',
      name: 'حديقة السلي',
      nameAr: 'حديقة السلي',
      category: PlaceCategory.park,
      latitude: 24.6600,
      longitude: 46.7100,
      address: 'حي السلي، الدائري الجنوبي، الرياض',
    ),
    PlaceModel(
      id: 'park_003',
      name: 'حديقة وادي حنيفة',
      nameAr: 'حديقة وادي حنيفة',
      category: PlaceCategory.park,
      latitude: 24.6800,
      longitude: 46.6200,
      address: 'وادي حنيفة، جنوب غرب الرياض',
    ),

    // ── Restaurants ───────────────────────────────────────────────────────────
    PlaceModel(
      id: 'restaurant_001',
      name: 'مطعم البيك',
      nameAr: 'مطعم البيك',
      category: PlaceCategory.restaurant,
      latitude: 24.6800,
      longitude: 46.7100,
      address: 'طريق الملك فهد، حي العليا، الرياض',
      phone: '+966114321000',
    ),
    PlaceModel(
      id: 'restaurant_002',
      name: 'مطعم هرفي',
      nameAr: 'مطعم هرفي',
      category: PlaceCategory.restaurant,
      latitude: 24.7200,
      longitude: 46.6500,
      address: 'شارع العليا، حي العليا، الرياض',
      phone: '+966114322000',
    ),
    PlaceModel(
      id: 'restaurant_003',
      name: 'مطعم كودو',
      nameAr: 'مطعم كودو',
      category: PlaceCategory.restaurant,
      latitude: 24.7050,
      longitude: 46.6780,
      address: 'حي المربع، وسط الرياض',
      phone: '+966114323000',
    ),
  ];

  // ---------------------------------------------------------------------------
  // Interface implementation
  // ---------------------------------------------------------------------------

  @override
  Future<List<PlaceModel>> getPlacesByCategory(PlaceCategory category) async {
    try {
      return _allPlaces
          .where((place) => place.category == category)
          .toList(growable: false);
    } catch (e) {
      throw CacheException(
        message: 'Failed to retrieve places for category: ${category.name}',
      );
    }
  }

  @override
  Future<Position> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationException(
          message: 'Location services are disabled on this device',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionException(
          message: 'Location permission was denied',
        );
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } on LocationException {
      rethrow;
    } on PermissionException {
      rethrow;
    } catch (e) {
      throw LocationException(
        message: 'Failed to obtain current location: $e',
      );
    }
  }
}

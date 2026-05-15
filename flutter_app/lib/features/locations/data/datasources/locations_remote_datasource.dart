import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/firebase/firebase_helpers.dart';

abstract class LocationsRemoteDataSource {
  Future<List<Map<String, dynamic>>> getSavedLocations({String? locationType, bool favoritesOnly = false});
  Future<Map<String, dynamic>> createLocation(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateLocation(String id, Map<String, dynamic> data);
  Future<void> deleteLocation(String id);
  Future<List<Map<String, dynamic>>> getNearby({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    String? locationType,
  });
}

class LocationsRemoteDataSourceImpl implements LocationsRemoteDataSource {
  final FirebaseHelpers _fb;
  LocationsRemoteDataSourceImpl({FirebaseHelpers? fb})
      : _fb = fb ?? FirebaseHelpers();

  CollectionReference<Map<String, dynamic>> get _col =>
      _fb.firestore.collection('savedLocations');

  @override
  Future<List<Map<String, dynamic>>> getSavedLocations({
    String? locationType,
    bool favoritesOnly = false,
  }) async {
    // Fetch user rows and system rows (userId == null) in two queries.
    Query<Map<String, dynamic>> userQ = _col.where('userId', isEqualTo: _fb.uid);
    Query<Map<String, dynamic>> sysQ = _col.where('userId', isNull: true);
    if (locationType != null) {
      userQ = userQ.where('locationType', isEqualTo: locationType);
      sysQ = sysQ.where('locationType', isEqualTo: locationType);
    }
    if (favoritesOnly) {
      userQ = userQ.where('isFavorite', isEqualTo: true);
    }
    final results = await Future.wait([userQ.get(), sysQ.get()]);
    final combined = <Map<String, dynamic>>[
      ..._fb.normalizeQuery(results[0]),
      ..._fb.normalizeQuery(results[1]),
    ];
    return combined;
  }

  @override
  Future<Map<String, dynamic>> createLocation(Map<String, dynamic> data) async {
    final ref = await _col.add({
      ...data,
      'userId': _fb.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snap = await ref.get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<Map<String, dynamic>> updateLocation(String id, Map<String, dynamic> data) async {
    await _col.doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    final snap = await _col.doc(id).get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<void> deleteLocation(String id) async {
    await _col.doc(id).delete();
  }

  @override
  Future<List<Map<String, dynamic>>> getNearby({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    String? locationType,
  }) async {
    // Firestore does not do geo-radius natively. Pull a bounded set (by type
    // if given) then filter client-side via Haversine.
    final all = await getSavedLocations(locationType: locationType);
    final filtered = all.where((row) {
      final latRaw = row['latitude'] ?? row['lat'];
      final lngRaw = row['longitude'] ?? row['lng'];
      if (latRaw is! num || lngRaw is! num) return false;
      final d = _haversineKm(lat, lng, latRaw.toDouble(), lngRaw.toDouble());
      row['distanceKm'] = d;
      return d <= radiusKm;
    }).toList()
      ..sort((a, b) => (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));
    return filtered;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    double toRad(double d) => d * math.pi / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) * math.cos(toRad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}

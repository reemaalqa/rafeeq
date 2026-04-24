import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_helpers.dart';

abstract class EmergencyRemoteDataSource {
  Future<List<Map<String, dynamic>>> getContacts();
  Future<Map<String, dynamic>> createContact(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateContact(String id, Map<String, dynamic> data);
  Future<void> deleteContact(String id);
  Future<Map<String, dynamic>> triggerEmergency(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getEvents();
  Future<void> resolveEvent(String eventId);
}

class EmergencyRemoteDataSourceImpl implements EmergencyRemoteDataSource {
  final FirebaseHelpers _fb;

  EmergencyRemoteDataSourceImpl({FirebaseHelpers? fb})
      : _fb = fb ?? FirebaseHelpers();

  @override
  Future<List<Map<String, dynamic>>> getContacts() async {
    final qs = await _fb
        .userSub('emergencyContacts')
        .where('isActive', isEqualTo: true)
        .orderBy('priority')
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<Map<String, dynamic>> createContact(Map<String, dynamic> data) async {
    final ref = await _fb.userSub('emergencyContacts').add({
      ...data,
      'isActive': data['isActive'] ?? true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snap = await ref.get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<Map<String, dynamic>> updateContact(
      String id, Map<String, dynamic> data) async {
    await _fb.userSub('emergencyContacts').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await _fb.userSub('emergencyContacts').doc(id).get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<void> deleteContact(String id) async {
    await _fb.userSub('emergencyContacts').doc(id).delete();
  }

  @override
  Future<Map<String, dynamic>> triggerEmergency(
      Map<String, dynamic> data) async {
    // Spark plan: no Cloud Functions. Write the event directly; SMS/push
    // fan-out would be added in a Cloud Function once the project upgrades.
    final ref = await _fb.userSub('emergencyEvents').add({
      ...data,
      'status': 'triggered',
      'createdAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
    });
    final snap = await ref.get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<List<Map<String, dynamic>>> getEvents() async {
    final qs = await _fb
        .userSub('emergencyEvents')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<void> resolveEvent(String eventId) async {
    await _fb.userSub('emergencyEvents').doc(eventId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_helpers.dart';

abstract class ProfileRemoteDataSource {
  Future<Map<String, dynamic>> getProfile();
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data);
  Future<Map<String, dynamic>> getPreferences();
  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getEmergencyContacts();
  Future<void> createEmergencyContact(Map<String, dynamic> data);
  Future<void> deleteEmergencyContact(String id);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseHelpers _fb;

  ProfileRemoteDataSourceImpl({FirebaseHelpers? fb})
      : _fb = fb ?? FirebaseHelpers();

  @override
  Future<Map<String, dynamic>> getProfile() async {
    final d = await _fb.userDoc().get();
    return _fb.normalize(d.data() ?? <String, dynamic>{});
  }

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final payload = {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _fb.userDoc().set(payload, SetOptions(merge: true));
    final updated = await _fb.userDoc().get();
    return _fb.normalize(updated.data() ?? <String, dynamic>{});
  }

  @override
  Future<Map<String, dynamic>> getPreferences() async {
    final d = await _fb.userSub('preferences').doc('main').get();
    return _fb.normalize(d.data() ?? <String, dynamic>{});
  }

  @override
  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> data) async {
    await _fb.userSub('preferences').doc('main').set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    // Also mark the user doc as onboarded.
    await _fb.userDoc().set(
      {'preferencesOnboarded': true},
      SetOptions(merge: true),
    );
    final d = await _fb.userSub('preferences').doc('main').get();
    return _fb.normalize(d.data() ?? <String, dynamic>{});
  }

  @override
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final qs = await _fb
        .userSub('emergencyContacts')
        .orderBy('priority')
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<void> createEmergencyContact(Map<String, dynamic> data) async {
    await _fb.userSub('emergencyContacts').add({
      ...data,
      'isActive': data['isActive'] ?? true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteEmergencyContact(String id) async {
    await _fb.userSub('emergencyContacts').doc(id).delete();
  }
}

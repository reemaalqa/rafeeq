import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_helpers.dart';

abstract class SettingsRemoteDataSource {
  Future<Map<String, String>> getTranslations({String languageCode = 'ar', String? context});
  Future<Map<String, dynamic>> getPublicConfigs();
  Future<Map<String, dynamic>?> getLatestVersion({String? platform});
  Future<Map<String, dynamic>> getUserPreferences();
  Future<void> updateUserPreferences(Map<String, dynamic> prefs);
}

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  final FirebaseHelpers _fb;
  SettingsRemoteDataSourceImpl({FirebaseHelpers? fb}) : _fb = fb ?? FirebaseHelpers();

  @override
  Future<Map<String, String>> getTranslations({String languageCode = 'ar', String? context}) async {
    final qs = await _fb.firestore
        .collection('translations')
        .doc(languageCode)
        .collection('keys')
        .get();
    final out = <String, String>{};
    for (final d in qs.docs) {
      final data = d.data();
      if (context != null && data['context'] != context) continue;
      out[d.id] = (data['value'] ?? '').toString();
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>> getPublicConfigs() async {
    final qs = await _fb.firestore
        .collection('systemConfigs')
        .where('isPublic', isEqualTo: true)
        .get();
    return {for (final d in qs.docs) d.id: d.data()['value']};
  }

  @override
  Future<Map<String, dynamic>?> getLatestVersion({String? platform}) async {
    final docId = platform ?? 'both';
    final d = await _fb.firestore.collection('appVersions').doc(docId).get();
    if (!d.exists) return null;
    return _fb.normalizeDoc(d);
  }

  @override
  Future<Map<String, dynamic>> getUserPreferences() async {
    final d = await _fb.userSub('preferences').doc('main').get();
    return _fb.normalize(d.data() ?? <String, dynamic>{});
  }

  @override
  Future<void> updateUserPreferences(Map<String, dynamic> prefs) async {
    await _fb.userSub('preferences').doc('main').set(
      {...prefs, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}

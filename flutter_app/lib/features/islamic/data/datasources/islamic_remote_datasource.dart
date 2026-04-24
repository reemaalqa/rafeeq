import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_helpers.dart';

abstract class IslamicRemoteDataSource {
  Future<List<Map<String, dynamic>>> getPrayerTimes({String? date});
  Future<Map<String, dynamic>> savePrayerTimes(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getQuranRecitations();
  Future<Map<String, dynamic>> logRecitation(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getIslamicContent({String? contentType, String? category});
}

class IslamicRemoteDataSourceImpl implements IslamicRemoteDataSource {
  final FirebaseHelpers _fb;
  IslamicRemoteDataSourceImpl({FirebaseHelpers? fb}) : _fb = fb ?? FirebaseHelpers();

  @override
  Future<List<Map<String, dynamic>>> getPrayerTimes({String? date}) async {
    if (date != null) {
      final d = await _fb.userSub('prayerTimes').doc(date).get();
      return d.exists ? [_fb.normalizeDoc(d)] : [];
    }
    final qs = await _fb
        .userSub('prayerTimes')
        .orderBy('prayerDate', descending: true)
        .limit(7)
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<Map<String, dynamic>> savePrayerTimes(Map<String, dynamic> data) async {
    final docId = (data['prayerDate'] ?? data['prayer_date'])?.toString();
    if (docId == null) {
      throw ArgumentError('prayerDate is required');
    }
    await _fb.userSub('prayerTimes').doc(docId).set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    final snap = await _fb.userSub('prayerTimes').doc(docId).get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<List<Map<String, dynamic>>> getQuranRecitations() async {
    final qs = await _fb
        .userSub('quranRecitations')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<Map<String, dynamic>> logRecitation(Map<String, dynamic> data) async {
    final ref = await _fb.userSub('quranRecitations').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snap = await ref.get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<List<Map<String, dynamic>>> getIslamicContent({String? contentType, String? category}) async {
    Query<Map<String, dynamic>> q = _fb.firestore
        .collection('islamicContent')
        .where('isActive', isEqualTo: true);
    if (contentType != null) q = q.where('contentType', isEqualTo: contentType);
    if (category != null) q = q.where('category', isEqualTo: category);
    final qs = await q.get();
    return _fb.normalizeQuery(qs);
  }
}

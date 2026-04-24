import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../error/exceptions.dart';

/// Shared helpers used by every Firestore-backed datasource.
///
/// Wraps [FirebaseFirestore] so callers can fetch user-scoped refs with a
/// single line and converts snapshot maps into JSON-like `Map<String,dynamic>`
/// with the document id injected as `id`.
class FirebaseHelpers {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  FirebaseHelpers({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;

  String get uid {
    final u = auth.currentUser;
    if (u == null) {
      throw const AuthenticationException(message: 'Not signed in');
    }
    return u.uid;
  }

  DocumentReference<Map<String, dynamic>> userDoc([String? overrideUid]) =>
      firestore.collection('users').doc(overrideUid ?? uid);

  CollectionReference<Map<String, dynamic>> userSub(String sub) =>
      userDoc().collection(sub);

  Map<String, dynamic> docToJson(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? <String, dynamic>{};
    return {...data, 'id': d.id};
  }

  List<Map<String, dynamic>> snapshotToList(QuerySnapshot<Map<String, dynamic>> qs) =>
      qs.docs.map(docToJson).toList();

  /// Converts Firestore Timestamps to ISO strings so the existing entity
  /// parsing (DateTime.parse) stays happy.
  Map<String, dynamic> normalize(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v is Timestamp) {
        out[k] = v.toDate().toIso8601String();
      } else if (v is Map<String, dynamic>) {
        out[k] = normalize(v);
      } else if (v is List) {
        out[k] = v
            .map((e) => e is Map<String, dynamic> ? normalize(e) : e)
            .toList();
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  Map<String, dynamic> normalizeDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      normalize(docToJson(d));

  List<Map<String, dynamic>> normalizeQuery(QuerySnapshot<Map<String, dynamic>> qs) =>
      qs.docs.map(normalizeDoc).toList();
}

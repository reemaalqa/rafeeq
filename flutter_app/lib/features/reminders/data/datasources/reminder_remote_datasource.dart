import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_helpers.dart';

abstract class ReminderRemoteDataSource {
  Future<List<Map<String, dynamic>>> getCategories();
  Future<List<Map<String, dynamic>>> getReminders();
  Future<Map<String, dynamic>> createReminder(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateReminder(String id, Map<String, dynamic> data);
  Future<void> deleteReminder(String id);
  Future<List<Map<String, dynamic>>> getMedications();
  Future<Map<String, dynamic>> createMedication(String reminderId, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getAppointments();
  Future<Map<String, dynamic>> createAppointment(String reminderId, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getLogs();
}

class ReminderRemoteDataSourceImpl implements ReminderRemoteDataSource {
  final FirebaseHelpers _fb;
  ReminderRemoteDataSourceImpl({FirebaseHelpers? fb})
      : _fb = fb ?? FirebaseHelpers();

  @override
  Future<List<Map<String, dynamic>>> getCategories() async {
    final qs = await _fb.firestore
        .collection('reminderCategories')
        .where('isActive', isEqualTo: true)
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<List<Map<String, dynamic>>> getReminders() async {
    final qs = await _fb
        .userSub('reminders')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<Map<String, dynamic>> createReminder(Map<String, dynamic> data) async {
    final ref = await _fb.userSub('reminders').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snap = await ref.get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<Map<String, dynamic>> updateReminder(
      String id, Map<String, dynamic> data) async {
    await _fb.userSub('reminders').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await _fb.userSub('reminders').doc(id).get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<void> deleteReminder(String id) async {
    // Soft delete
    await _fb.userSub('reminders').doc(id).update({
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getMedications() async {
    final qs = await _fb
        .userSub('reminders')
        .where('isActive', isEqualTo: true)
        .where('medication', isNull: false)
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<Map<String, dynamic>> createMedication(
      String reminderId, Map<String, dynamic> data) async {
    await _fb.userSub('reminders').doc(reminderId).set(
      {'medication': data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    final snap = await _fb.userSub('reminders').doc(reminderId).get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<List<Map<String, dynamic>>> getAppointments() async {
    final qs = await _fb
        .userSub('reminders')
        .where('isActive', isEqualTo: true)
        .where('appointment', isNull: false)
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<Map<String, dynamic>> createAppointment(
      String reminderId, Map<String, dynamic> data) async {
    await _fb.userSub('reminders').doc(reminderId).set(
      {'appointment': data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    final snap = await _fb.userSub('reminders').doc(reminderId).get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<List<Map<String, dynamic>>> getLogs() async {
    // Aggregate logs from all reminders via collectionGroup
    final qs = await _fb.firestore
        .collectionGroup('logs')
        .orderBy('scheduledAt', descending: true)
        .limit(100)
        .get();
    return qs.docs
        .where((d) => d.reference.path.startsWith('users/${_fb.uid}/'))
        .map(_fb.normalizeDoc)
        .toList();
  }
}

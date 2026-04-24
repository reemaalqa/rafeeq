import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_helpers.dart';

// ────────────────────────────────────────────────────────────────────────────
// ConversationRemoteDataSource
// ────────────────────────────────────────────────────────────────────────────
//
// PIPELINE OVERVIEW
// ─────────────────
//   Voice → [device Speech-to-Text SDK]            → text
//   Text  → [RafeeqAiApiClient → local fallback]   → intent   (in cubit)
//   Text  → [Google Gemini API]                    → Arabic reply
//   Log   → [Cloud Firestore]                      → session / messages
//
// This datasource is only responsible for Firestore session/message logging.
// Intent detection lives in ConversationCubit — it calls the rafeeq_ai_api
// FastAPI backend when healthy and falls back to the client-side
// IntentDetector otherwise.
// ────────────────────────────────────────────────────────────────────────────

abstract class ConversationRemoteDataSource {
  Future<List<Map<String, dynamic>>> getSessions();
  Future<Map<String, dynamic>> startSession();
  Future<void> endSession(String sessionId);
  Future<List<Map<String, dynamic>>> getMessages(String sessionId);
  Future<Map<String, dynamic>> sendMessage(String sessionId, String content,
      {String? audioUrl});
  Future<Map<String, dynamic>> sendVoiceCommand(String audioUrl,
      {String languageCode = 'ar'});
}

class ConversationRemoteDataSourceImpl implements ConversationRemoteDataSource {
  final FirebaseHelpers _fb;

  ConversationRemoteDataSourceImpl({FirebaseHelpers? fb})
      : _fb = fb ?? FirebaseHelpers();

  // ── Sessions ────────────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getSessions() async {
    final qs = await _fb
        .userSub('sessions')
        .orderBy('sessionStart', descending: true)
        .limit(20)
        .get();
    return _fb.normalizeQuery(qs);
  }

  @override
  Future<Map<String, dynamic>> startSession() async {
    final ref = await _fb.userSub('sessions').add({
      'sessionStart': FieldValue.serverTimestamp(),
      'sessionEnd': null,
      'totalMessages': 0,
      'durationSeconds': 0,
      'moodDetected': null,
    });
    final snap = await ref.get();
    return _fb.normalizeDoc(snap);
  }

  @override
  Future<void> endSession(String sessionId) async {
    await _fb.userSub('sessions').doc(sessionId).update({
      'sessionEnd': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getMessages(String sessionId) async {
    final qs = await _fb
        .userSub('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('createdAt')
        .get();
    return _fb.normalizeQuery(qs);
  }

  // ── Text message ─────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> sendMessage(
    String sessionId,
    String content, {
    String? audioUrl,
  }) async {
    final messagesCol =
        _fb.userSub('sessions').doc(sessionId).collection('messages');

    final userRef = await messagesCol.add({
      'sessionId': sessionId,
      'messageType': 'user',
      'content': content,
      'audioUrl': audioUrl,
      'intentDetected': null,
      'confidenceScore': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _fb.userSub('sessions').doc(sessionId).update({
      'totalMessages': FieldValue.increment(1),
    });

    final snap = await userRef.get();
    return _fb.normalizeDoc(snap);
  }

  // ── Voice command ────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> sendVoiceCommand(
    String audioUrl, {
    String languageCode = 'ar',
  }) async {
    // Voice is transcribed by the device Speech-to-Text SDK and classified
    // in ConversationCubit (rafeeq_ai_api with local keyword fallback).
    // This datasource is not involved in either step.
    return {
      'audioUrl': audioUrl,
      'languageCode': languageCode,
      'transcription': null,
      'intent': null,
      'method': 'handled_in_cubit',
    };
  }
}

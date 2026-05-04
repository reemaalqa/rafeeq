import 'dart:io';
import 'package:dio/dio.dart';

// ────────────────────────────────────────────────────────────────────────────
// RafeeqAiApiClient
// ────────────────────────────────────────────────────────────────────────────
//
// HTTP client for the self-hosted rafeeq_ai_api FastAPI backend.
//
//   POST /predict/text   { "text": "…" }
//     → { intent, intent_ar, text, method }
//
//   POST /predict/audio  multipart/form-data (field name: "audio")
//     → { intent, intent_ar, text, method }
//
//   GET  /health
//     → { status, whisper, arabert, nlu_mode }
//
// The client is *always* active. Callers use [isHealthy] (cached for
// [_kHealthCacheTtl]) to decide whether to hit the API or fall back to
// the local keyword detector. The base URL can be overridden at build
// time via --dart-define=RAFEEQ_AI_API_URL=http://host:port
// ────────────────────────────────────────────────────────────────────────────

const String _kBaseUrl = String.fromEnvironment(
  'RAFEEQ_AI_API_URL',
  defaultValue: 'http://192.168.1.107:8000',
);

const Duration _kHealthCacheTtl = Duration(seconds: 30);

// ── Response models ──────────────────────────────────────────────────────────

/// Structured response from both /predict/text and /predict/audio.
class RafeeqPrediction {
  final String text;

  /// English intent key — possible values:
  /// emergency | prayer_time | medication | diet | reminders |
  /// quran | islamic_advice | locations | conversation | general
  final String intent;

  /// Human-readable Arabic label for the intent.
  final String intentAr;

  /// Detection method used by the server: 'arabert' or 'keyword_fallback'.
  final String method;

  /// Detected dialect — one of: 'najdi' | 'janoubi' | 'shamali' | 'sharqawi'.
  /// Null when the API signal was too weak to commit.
  final String? dialect;

  /// Posterior confidence for [dialect] (0.0 – 1.0).
  final double dialectConfidence;

  const RafeeqPrediction({
    required this.text,
    required this.intent,
    required this.intentAr,
    required this.method,
    this.dialect,
    this.dialectConfidence = 0.0,
  });

  factory RafeeqPrediction.fromJson(Map<String, dynamic> json) =>
      RafeeqPrediction(
        text:              json['text']               as String? ?? '',
        intent:            json['intent']             as String? ?? 'general',
        intentAr:          json['intent_ar']          as String? ?? '',
        method:            json['method']             as String? ?? 'unknown',
        dialect:           json['dialect']            as String?,
        dialectConfidence: (json['dialect_confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

// ── Client ───────────────────────────────────────────────────────────────────

class RafeeqAiApiClient {
  final Dio _dio;

  bool? _cachedHealthy;
  DateTime? _cachedAt;

  RafeeqAiApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _kBaseUrl,
              connectTimeout: const Duration(seconds: 2),
              sendTimeout:    const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 5),
              headers: {'Content-Type': 'application/json'},
            ));

  String get baseUrl => _kBaseUrl;

  /// Returns true if GET /health responded 200 recently.
  /// Result is cached for [_kHealthCacheTtl] to avoid pinging the server
  /// on every user utterance. Pass [force] to bypass the cache.
  Future<bool> isHealthy({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _cachedHealthy != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _kHealthCacheTtl) {
      return _cachedHealthy!;
    }

    bool healthy;
    try {
      final response = await _dio.get<dynamic>(
        '/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 2),
          sendTimeout:    const Duration(seconds: 2),
        ),
      );
      healthy = response.statusCode == 200;
    } catch (_) {
      healthy = false;
    }

    _cachedHealthy = healthy;
    _cachedAt = now;
    return healthy;
  }

  /// Invalidate the cached health result (e.g. after a failed call).
  void invalidateHealthCache() {
    _cachedHealthy = null;
    _cachedAt = null;
  }

  // ── /predict/text ──────────────────────────────────────────────────────────

  Future<RafeeqPrediction> predictText(String text) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/predict/text',
      data: {'text': text},
    );
    return RafeeqPrediction.fromJson(response.data!);
  }

  // ── /predict/audio ─────────────────────────────────────────────────────────

  Future<RafeeqPrediction> predictAudio(File audioFile) async {
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        audioFile.path,
        filename: audioFile.path.split(Platform.pathSeparator).last,
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/predict/audio',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return RafeeqPrediction.fromJson(response.data!);
  }
}

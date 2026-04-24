import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import 'system_tts_service.dart';
import 'tts_service.dart';

/// Google Cloud Text-to-Speech service using WaveNet Arabic voices.
///
/// When [AppConstants.googleTtsApiKey] is empty or the network call fails,
/// automatically falls back to [SystemTtsService] so the app still works
/// offline. Callers see no difference — they just get higher-quality audio
/// whenever the cloud is reachable.
///
/// Best Arabic voices used:
///   female → ar-XA-Wavenet-C  (default)
///   male   → ar-XA-Wavenet-B
class GoogleTtsService implements TtsService {
  final SystemTtsService _fallback;
  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 10),
  ));

  String _voiceName = 'ar-XA-Wavenet-C';
  double _speakingRate = 0.85;
  double _pitchSemitones = 0.0;
  VoidCallback? _completionHandler;

  GoogleTtsService(this._fallback) {
    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        _completionHandler?.call();
      }
    });
  }

  @override
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (AppConstants.googleTtsApiKey.isEmpty) {
      await _fallback.speak(trimmed);
      return;
    }

    try {
      await _player.stop();

      final response = await _dio.post(
        'https://texttospeech.googleapis.com/v1/text:synthesize',
        queryParameters: {'key': AppConstants.googleTtsApiKey},
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: {
          'input': {'text': trimmed},
          'voice': {
            'languageCode': 'ar-XA',
            'name': _voiceName,
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': _speakingRate,
            'pitch': _pitchSemitones,
          },
        },
      );

      final encoded = response.data['audioContent'] as String;
      final bytes = base64Decode(encoded);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rafeeq_tts.mp3');
      await file.writeAsBytes(bytes, flush: true);

      await _player.setAudioSource(AudioSource.file(file.path));
      await _player.play();
    } catch (e, st) {
      developer.log(
        'GoogleTtsService: cloud synthesis failed, using device TTS',
        name: 'GoogleTtsService',
        error: e,
        stackTrace: st,
      );
      await _fallback.speak(trimmed);
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _fallback.stop();
  }

  @override
  Future<void> setLanguage(String language) async {
    // Language is fixed to ar-XA for Cloud TTS; keep fallback in sync.
    await _fallback.setLanguage(language);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    // flutter_tts: 0.0–1.0 where 1.0 = normal speed.
    // Cloud TTS: 0.25–4.0 where 1.0 = normal.
    _speakingRate = (0.4 + rate * 0.7).clamp(0.25, 2.0);
    await _fallback.setSpeechRate(rate);
  }

  @override
  Future<void> setPitch(double pitch) async {
    // flutter_tts pitch: 0.0–2.0, 1.0 = normal.
    // SettingsCubit uses 0.85 for male, 1.35 for female.
    // Cloud TTS pitch: semitones (-20 to +20), 0.0 = normal.
    _pitchSemitones = ((pitch - 1.0) * 4.0).clamp(-8.0, 8.0);
    _voiceName = pitch >= 1.0 ? 'ar-XA-Wavenet-C' : 'ar-XA-Wavenet-B';
    await _fallback.setPitch(pitch);
  }

  @override
  void setCompletionHandler(VoidCallback handler) {
    _completionHandler = handler;
    _fallback.setCompletionHandler(handler);
  }
}

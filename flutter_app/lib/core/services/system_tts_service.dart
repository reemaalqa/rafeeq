import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_service.dart';

/// Device TTS wrapper — delegates to [FlutterTts] which uses whatever
/// engine is installed on the device (Google TTS, Samsung TTS, etc.).
/// Used as the offline fallback when Google Cloud TTS is unavailable.
class SystemTtsService implements TtsService {
  final FlutterTts _tts;
  SystemTtsService(this._tts);

  @override
  Future<void> speak(String text) async => _tts.speak(text);

  @override
  Future<void> stop() async => _tts.stop();

  @override
  Future<void> setLanguage(String language) async =>
      _tts.setLanguage(language);

  @override
  Future<void> setSpeechRate(double rate) async => _tts.setSpeechRate(rate);

  @override
  Future<void> setPitch(double pitch) async => _tts.setPitch(pitch);

  @override
  void setCompletionHandler(VoidCallback handler) =>
      _tts.setCompletionHandler(handler);
}

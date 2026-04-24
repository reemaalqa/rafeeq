import 'package:flutter/foundation.dart';

/// Unified TTS interface used by all cubits.
/// Two implementations:
///   - [GoogleTtsService]  — Google Cloud Neural voices (high quality Arabic)
///   - [SystemTtsService]  — device FlutterTts (fallback / offline)
abstract class TtsService {
  /// Speak [text]. Stops any current speech first.
  Future<void> speak(String text);

  /// Stop current speech immediately.
  Future<void> stop();

  /// Set BCP-47 language code, e.g. 'ar-SA'.
  Future<void> setLanguage(String language);

  /// Speech rate — same scale as flutter_tts (0.0 – 1.0, 1.0 = normal).
  Future<void> setSpeechRate(double rate);

  /// Pitch — same scale as flutter_tts (0.0 – 2.0, 1.0 = normal,
  /// < 1.0 = male/lower, > 1.0 = female/higher).
  Future<void> setPitch(double pitch);

  /// Called when the current utterance finishes playing.
  void setCompletionHandler(VoidCallback handler);
}

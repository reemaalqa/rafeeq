import 'package:equatable/equatable.dart';

enum IntentType {
  emergency,
  prayerTime,
  medication,
  diet,
  reminders,
  quran,
  islamicAdvice,
  locations,
  conversation,
  general,
  deviceControl,
}

class DetectedIntent extends Equatable {
  final IntentType type;
  final double confidence;
  final String matchedText;

  /// Optional structured parameters extracted from the voice command.
  /// Examples:
  ///   Reminder: {'title': 'الدواء', 'time': '15:00'}
  ///   Quran:    {'surah': 'الكهف'}
  final Map<String, String> extractedParams;

  const DetectedIntent({
    required this.type,
    required this.confidence,
    required this.matchedText,
    this.extractedParams = const {},
  });

  bool get isEmergency => type == IntentType.emergency;

  @override
  List<Object?> get props => [type, confidence, matchedText, extractedParams];
}

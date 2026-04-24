import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq/features/conversation/domain/services/voice_flow_manager.dart';

/// Mirrors ConversationCubit._normalizeForExtraction so the test feeds the
/// extractor the same shape of text the runtime does.
String _normalize(String text) {
  var s = text.trim().toLowerCase();
  s = s.replaceAll(
    RegExp(
      r'[ً-ٰٟؐ-ؚۖ-ۜ'
      r'۟-۪ۤۧۨ-ۭ]',
    ),
    '',
  );
  s = s.replaceAll('ـ', '');
  s = s
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  const digitMap = {
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
  };
  digitMap.forEach((k, v) => s = s.replaceAll(k, v));
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

void main() {
  final flow = VoiceFlowManager();

  String? parse(String input) => flow.extractSlotValue(
        SlotType.time,
        _normalize(input),
        input,
      );

  group('reminder time extraction (user-reported cases)', () {
    test('"بعد دقيقة واحدة" → +1m', () {
      expect(parse('بعد دقيقة واحدة'), '+1m');
    });
    test('"بعد ساعة" → +1h', () {
      expect(parse('بعد ساعة'), '+1h');
    });
    test('"بعد ساعة واحدة" → +1h', () {
      expect(parse('بعد ساعة واحدة'), '+1h');
    });
    test('"بعد 19 دقيقة" → +19m', () {
      expect(parse('بعد 19 دقيقة'), '+19m');
    });
    test('"10 دقيقة" → +10m', () {
      expect(parse('10 دقيقة'), '+10m');
    });
    test('"10 ساعة" → +10h', () {
      expect(parse('10 ساعة'), '+10h');
    });

    test('"بعد دقيقة" → +1m', () {
      expect(parse('بعد دقيقة'), '+1m');
    });
    test('"بعد خمس دقائق" → +5m', () {
      expect(parse('بعد خمس دقائق'), '+5m');
    });
    test('"بعد عشر دقائق" → +10m', () {
      expect(parse('بعد عشر دقائق'), '+10m');
    });
    test('"بعد ساعتين" → +2h', () {
      expect(parse('بعد ساعتين'), '+2h');
    });
    test('"نص ساعة" → +30m', () {
      expect(parse('نص ساعة'), '+30m');
    });
    test('"ربع ساعة" → +15m', () {
      expect(parse('ربع ساعة'), '+15m');
    });
    test('"الساعة 10" → 10:00', () {
      expect(parse('الساعة 10'), '10:00');
    });
    test('"الساعة 10 مساء" → 22:00', () {
      expect(parse('الساعة 10 مساء'), '22:00');
    });
    test('"الثالثة عصر" → 15:00', () {
      expect(parse('الثالثة عصر'), '15:00');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq/features/conversation/domain/entities/detected_intent.dart';
import 'package:rafeeq/features/conversation/domain/services/intent_detector.dart';
import 'package:rafeeq/features/conversation/domain/services/voice_flow_manager.dart';

void main() {
  final detector = IntentDetector();
  final flow = VoiceFlowManager();

  group('IntentDetector surah extraction (raw STT variants)', () {
    void expectSurah(String phrase, String expected) {
      final intent = detector.detect(phrase);
      expect(intent.type, IntentType.quran, reason: 'phrase: $phrase');
      expect(intent.extractedParams['surah'], expected, reason: 'phrase: $phrase');
    }

    test('canonical "شغل الفاتحة"', () => expectSurah('شغل الفاتحة', 'الفاتحة'));
    test('ه form "شغل الفاتحه"', () => expectSurah('شغل الفاتحه', 'الفاتحة'));
    test('no-al "شغل فاتحة"', () => expectSurah('شغل فاتحة', 'الفاتحة'));
    test('no-al ه form "شغل فاتحه"', () => expectSurah('شغل فاتحه', 'الفاتحة'));

    test('canonical "سورة البقرة"', () => expectSurah('سورة البقرة', 'البقرة'));
    test('ه form "سورة البقره"', () => expectSurah('سورة البقره', 'البقرة'));
    test('no-al "سورة بقرة"', () => expectSurah('سورة بقرة', 'البقرة'));

    test('non-ال surah "شغل يوسف"', () => expectSurah('شغل يوسف', 'يوسف'));
    test('non-ال surah "اقرا يس"', () => expectSurah('اقرا يس', 'يس'));
  });

  group('VoiceFlowManager slot extraction (prompted surah answer)', () {
    String? parse(String input) =>
        flow.extractSlotValue(SlotType.surahName, input, input);

    test('"الفاتحة"', () => expect(parse('الفاتحة'), 'الفاتحة'));
    test('"الفاتحه"', () => expect(parse('الفاتحه'), 'الفاتحة'));
    test('"فاتحه"', () => expect(parse('فاتحه'), 'الفاتحة'));
    test('"البقرة"', () => expect(parse('البقرة'), 'البقرة'));
    test('"البقره"', () => expect(parse('البقره'), 'البقرة'));
    test('"بقره"', () => expect(parse('بقره'), 'البقرة'));
    test('"يوسف"', () => expect(parse('يوسف'), 'يوسف'));
  });
}

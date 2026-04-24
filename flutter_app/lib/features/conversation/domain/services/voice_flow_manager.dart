import '../entities/detected_intent.dart';

/// Defines the multi-turn slot-filling dialogue flows.
/// Each intent has required slots that must be collected before execution.

enum SlotType { title, time, locationType, foodMeal, surahName, confirmAction }

class SlotDefinition {
  final SlotType type;
  final String key;
  final String promptArabic;
  final bool required;

  const SlotDefinition({
    required this.type,
    required this.key,
    required this.promptArabic,
    this.required = true,
  });
}

class VoiceFlow {
  final IntentType intent;
  final List<SlotDefinition> slots;
  final String introPrompt;

  const VoiceFlow({
    required this.intent,
    required this.slots,
    required this.introPrompt,
  });
}

class VoiceFlowManager {
  static const Map<IntentType, VoiceFlow> _flows = {
    // ── Reminders ──────────────────────────────────────────────────────────────
    IntentType.reminders: VoiceFlow(
      intent: IntentType.reminders,
      introPrompt: 'طيب، ابي اضبط لك تذكير.',
      slots: [
        SlotDefinition(
          type: SlotType.title,
          key: 'title',
          promptArabic: 'ايش اللي تبيني اذكرك فيه؟',
        ),
        SlotDefinition(
          type: SlotType.time,
          key: 'time',
          promptArabic: 'متى تبي التذكير؟ قول الساعة أو بعد كم دقيقة.',
        ),
      ],
    ),

    // ── Medication ─────────────────────────────────────────────────────────────
    IntentType.medication: VoiceFlow(
      intent: IntentType.medication,
      introPrompt: 'طيب، خلني اضبط لك تذكير الدواء.',
      slots: [
        SlotDefinition(
          type: SlotType.title,
          key: 'title',
          promptArabic: 'ايش اسم الدواء؟',
        ),
        SlotDefinition(
          type: SlotType.time,
          key: 'time',
          promptArabic: 'متى تبي تاخذه؟ قول الساعة أو بعد كم دقيقة.',
        ),
      ],
    ),

    // ── Diet / food ────────────────────────────────────────────────────────────
    IntentType.diet: VoiceFlow(
      intent: IntentType.diet,
      introPrompt: 'طيب، خلني اساعدك بالأكل.',
      slots: [
        SlotDefinition(
          type: SlotType.foodMeal,
          key: 'meal',
          promptArabic: 'تبي فطور، غداء، ولا عشاء؟',
        ),
      ],
    ),

    // ── Locations ──────────────────────────────────────────────────────────────
    IntentType.locations: VoiceFlow(
      intent: IntentType.locations,
      introPrompt: 'طيب، خلني ادور لك مكان قريب.',
      slots: [
        SlotDefinition(
          type: SlotType.locationType,
          key: 'place_type',
          promptArabic: 'ايش تدور؟ مسجد، صيدلية، مستشفى، ولا عيادة؟',
        ),
      ],
    ),

    // ── Quran ──────────────────────────────────────────────────────────────────
    IntentType.quran: VoiceFlow(
      intent: IntentType.quran,
      introPrompt: 'طيب، خلني اشغل لك قرآن.',
      slots: [
        SlotDefinition(
          type: SlotType.surahName,
          key: 'surah',
          promptArabic: 'أي سورة تبي تسمع؟',
        ),
      ],
    ),

    // ── Prayer times ──────────────────────────────────────────────────────────
    IntentType.prayerTime: VoiceFlow(
      intent: IntentType.prayerTime,
      introPrompt: '',
      slots: [], // No slots needed — execute immediately
    ),

    // ── Islamic advice ────────────────────────────────────────────────────────
    IntentType.islamicAdvice: VoiceFlow(
      intent: IntentType.islamicAdvice,
      introPrompt: '',
      slots: [], // No slots needed — execute immediately
    ),

    // ── Conversation ──────────────────────────────────────────────────────────
    IntentType.conversation: VoiceFlow(
      intent: IntentType.conversation,
      introPrompt: '',
      slots: [], // Free-form — no slots
    ),
  };

  /// Returns the flow for the given intent, or null if no flow is defined.
  VoiceFlow? getFlow(IntentType type) => _flows[type];

  /// Check if intent has required slots to collect.
  bool needsSlots(IntentType type) {
    final flow = _flows[type];
    return flow != null && flow.slots.isNotEmpty;
  }

  /// Get the next unfilled required slot given current collected data.
  SlotDefinition? getNextSlot(
    IntentType type,
    Map<String, String> collectedSlots,
  ) {
    final flow = _flows[type];
    if (flow == null) return null;
    for (final slot in flow.slots) {
      if (slot.required && !collectedSlots.containsKey(slot.key)) {
        return slot;
      }
    }
    return null;
  }

  /// Check if all required slots are filled.
  bool allSlotsFilled(IntentType type, Map<String, String> collectedSlots) {
    return getNextSlot(type, collectedSlots) == null;
  }

  /// Extract a slot value from user speech based on what slot we're asking for.
  String? extractSlotValue(SlotType slotType, String normalizedText, String rawText) {
    switch (slotType) {
      case SlotType.title:
        return _extractTitle(rawText);
      case SlotType.time:
        return _extractTime(normalizedText);
      case SlotType.locationType:
        return _extractLocationType(normalizedText);
      case SlotType.foodMeal:
        return _extractMealType(normalizedText);
      case SlotType.surahName:
        return _extractSurahName(normalizedText, rawText);
      case SlotType.confirmAction:
        return _extractConfirmation(normalizedText);
    }
  }

  String? _extractTitle(String rawText) {
    // The entire speech is the title when we're asking for it
    final cleaned = rawText
        .replaceAll(RegExp(r'(اسمه|اسمها|عنوانه|يعني|هو|هي)\s*'), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : null;
  }

  String? _extractTime(String text) {
    // Note: `text` has already been normalised by the cubit — ة→ه, ى→ي,
    // Arabic-Indic digits → ASCII, diacritics stripped. So the patterns
    // below use the normalised ("ه") forms.
    const timeUnitRegex = r'(دقيقه|دقائق|دقايق|دقيقتين|ساعه|ساعات|ساعتين)';

    // Arabic word numbers (singular spellings after normalisation).
    const arabicNumbers = <String, int>{
      'واحده': 1, 'وحده': 1, 'واحد': 1,
      'دقيقتين': 2, 'ساعتين': 2, 'ثنتين': 2, 'اثنتين': 2, 'اثنين': 2,
      'ثلاث': 3, 'ثلاثه': 3,
      'اربع': 4, 'اربعه': 4,
      'خمس': 5, 'خمسه': 5,
      'ست': 6, 'سته': 6,
      'سبع': 7, 'سبعه': 7,
      'ثمان': 8, 'ثمانيه': 8,
      'تسع': 9, 'تسعه': 9,
      'عشر': 10, 'عشره': 10,
      'خمسطعش': 15, 'خمسه عشر': 15,
      'عشرين': 20, 'عشرون': 20,
      'ثلاثين': 30, 'ثلاثون': 30,
    };

    String relative(int value, String unit) =>
        unit.startsWith('ساع') ? '+${value}h' : '+${value}m';

    // ── 1) "بعد 15 دقيقة" / "15 دقيقه" — number + unit, with or without "بعد".
    //     Handles "10 دقيقة", "10 ساعة", "بعد 19 دقيقة", etc.
    final numUnit = RegExp(r'(?:بعد\s+)?(\d+)\s*' + timeUnitRegex).firstMatch(text);
    if (numUnit != null) {
      return relative(int.parse(numUnit.group(1)!), numUnit.group(2)!);
    }

    // ── 2) "بعد خمس دقائق" / "بعد عشر دقائق" — word-number + unit.
    for (final e in arabicNumbers.entries) {
      // Skip the word "2" variants here — they collide with the "بعد ساعتين"
      // branch below. Those are handled as bare-unit-with-implicit-2.
      if (e.value == 2) continue;
      final p = RegExp(r'بعد\s+' + RegExp.escape(e.key) + r'\s*' + timeUnitRegex);
      final m = p.firstMatch(text);
      if (m != null) return relative(e.value, m.group(1)!);
    }

    // ── 3) "بعد ساعتين" / "بعد دقيقتين" (dual form = 2).
    if (RegExp(r'بعد\s+ساعتين').hasMatch(text)) return '+2h';
    if (RegExp(r'بعد\s+دقيقتين').hasMatch(text)) return '+2m';

    // ── 4) "بعد دقيقة واحدة" / "بعد ساعة واحدة" — unit followed by "one".
    final unitWahda = RegExp(r'بعد\s+' + timeUnitRegex + r'\s+(?:واحده|وحده|واحد)')
        .firstMatch(text);
    if (unitWahda != null) return relative(1, unitWahda.group(1)!);

    // ── 5) "بعد دقيقة" / "بعد ساعة" — bare unit defaults to 1.
    final bareBaad = RegExp(r'بعد\s+' + timeUnitRegex).firstMatch(text);
    if (bareBaad != null) return relative(1, bareBaad.group(1)!);

    // ── 6) "نص ساعة" / "ربع ساعة" — half and quarter.
    if (text.contains('نص ساعه')) return '+30m';
    if (text.contains('ربع ساعه')) return '+15m';

    // ── 7) Absolute time: "الساعة X" or just a digit hour.
    final absMatch = RegExp(
      r'(?:الساعه\s*)?(\d{1,2})(?::(\d{1,2}))?',
    ).firstMatch(text);
    if (absMatch != null) {
      int h = int.tryParse(absMatch.group(1)!) ?? 0;
      final minute = absMatch.group(2)?.padLeft(2, '0') ?? '00';
      if (text.contains('مساء') || text.contains('عصر') ||
          text.contains('مغرب') || text.contains('عشا') ||
          text.contains('ليل')) {
        if (h < 12) h += 12;
      } else if (text.contains('صباح') || text.contains('فجر')) {
        if (h == 12) h = 0;
      }
      return '${h.toString().padLeft(2, '0')}:$minute';
    }

    // ── 8) Word-based absolute hour: "ثلاثة", "الثالثة" etc.
    const wordHours = <String, int>{
      'الثالثه': 3, 'الرابعه': 4, 'الخامسه': 5, 'السادسه': 6,
      'السابعه': 7, 'الثامنه': 8, 'التاسعه': 9, 'العاشره': 10,
      'الحاديه عشر': 11, 'الثانيه عشر': 12,
      'ثلاثه': 3, 'اربعه': 4, 'خمسه': 5, 'سته': 6, 'سبعه': 7,
      'ثمانيه': 8, 'تسعه': 9, 'عشره': 10, 'احدعش': 11, 'اثنعش': 12,
    };
    for (final e in wordHours.entries) {
      if (text.contains(e.key)) {
        int h = e.value;
        if (text.contains('مساء') || text.contains('عصر') ||
            text.contains('مغرب') || text.contains('عشا')) {
          if (h < 12) h += 12;
        }
        return '${h.toString().padLeft(2, '0')}:00';
      }
    }

    return null;
  }

  String? _extractLocationType(String text) {
    if (text.contains('مسجد') || text.contains('جامع')) return 'mosque';
    if (text.contains('صيدلية') || text.contains('صيدليه') ||
        text.contains('صيدلي')) return 'pharmacy';
    // مستشفى normalises ى→ي, also accept truncated form مستشف
    if (text.contains('مستشفى') || text.contains('مستشفي') ||
        text.contains('مستشفا') || text.contains('مستشف')) return 'hospital';
    if (text.contains('عيادة') || text.contains('عياده') ||
        text.contains('عياد') ||
        text.contains('دكتور') || text.contains('طبيب')) return 'clinic';
    if (text.contains('مطعم') || text.contains('اكل')) return 'restaurant';
    return null;
  }

  String? _extractMealType(String text) {
    if (text.contains('فطور') || text.contains('فطار') ||
        text.contains('صباح')) return 'breakfast';
    if (text.contains('غداء') || text.contains('غدا') ||
        text.contains('ظهر')) return 'lunch';
    if (text.contains('عشاء') || text.contains('عشا') ||
        text.contains('ليل')) return 'dinner';
    if (text.contains('سناك') || text.contains('خفيف') ||
        text.contains('وجبه خفيفه') || text.contains('وجبة خفيفة')) {
      return 'snack';
    }
    return null;
  }

  static const _surahs = [
    'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة',
    'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
    'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر',
    'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
    'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان',
    'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
    'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
    'يس', 'ياسين', 'الصافات', 'ص', 'الزمر',
    'غافر', 'فصلت', 'الشورى', 'الزخرف', 'الدخان',
    'الجاثية', 'الأحقاف', 'محمد', 'الفتح', 'الحجرات',
    'ق', 'الذاريات', 'الطور', 'النجم', 'القمر',
    'الرحمن', 'الواقعة', 'الحديد', 'المجادلة', 'الحشر',
    'الممتحنة', 'الصف', 'الجمعة', 'المنافقون', 'التغابن',
    'الطلاق', 'التحريم', 'الملك', 'القلم', 'الحاقة',
    'المعارج', 'نوح', 'الجن', 'المزمل', 'المدثر',
    'القيامة', 'الإنسان', 'المرسلات', 'النبأ', 'النازعات',
    'عبس', 'التكوير', 'الانفطار', 'المطففين', 'الانشقاق',
    'البروج', 'الطارق', 'الأعلى', 'الغاشية', 'الفجر',
    'البلد', 'الشمس', 'الليل', 'الضحى', 'الشرح',
    'التين', 'العلق', 'القدر', 'البينة', 'الزلزلة',
    'العاديات', 'القارعة', 'التكاثر', 'العصر', 'الهمزة',
    'الفيل', 'قريش', 'الماعون', 'الكوثر', 'الكافرون',
    'النصر', 'المسد', 'الإخلاص', 'الفلق', 'الناس',
  ];

  String? _extractSurahName(String normalized, String rawText) {
    // Fold ة→ه, ى→ي, أ/إ/آ→ا, diacritics on both sides so names like
    // "الفاتحة" still match STT output of "الفاتحه" or "فاتحه".
    final looseInput = _looseFoldArabic('$rawText $normalized');

    for (final surah in _surahs) {
      final loose = _looseFoldArabic(surah);
      final looseNoAl = loose.startsWith('ال') ? loose.substring(2) : loose;
      if (_containsAsWord(looseInput, loose)) return surah;
      // ال-stripped version only matches if it's long enough to avoid false
      // positives (e.g. "ناس" stripped from "الناس" is 3 chars → OK; but
      // single-letter surahs like "ق" would over-match, so guard by length).
      if (looseNoAl.length >= 3 && _containsAsWord(looseInput, looseNoAl)) {
        return surah;
      }
    }
    return null;
  }

  static String _looseFoldArabic(String text) {
    var s = text.toLowerCase().trim();
    s = s.replaceAll(
      RegExp(r'[ً-ٰٟؐ-ؚ]'),
      '',
    );
    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ـ', '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _containsAsWord(String haystack, String needle) {
    if (needle.isEmpty) return false;
    return RegExp('(?:^|\\s)${RegExp.escape(needle)}(?:\\s|\$)')
        .hasMatch(haystack);
  }

  String? _extractConfirmation(String text) {
    if (text.contains('نعم') || text.contains('ايوه') ||
        text.contains('اي') || text.contains('اوكي') ||
        text.contains('تمام') || text.contains('اكيد') ||
        text.contains('صحيح') || text.contains('يلا')) {
      return 'yes';
    }
    if (text.contains('لا') || text.contains('الغي') ||
        text.contains('الغاء') || text.contains('خلاص') ||
        text.contains('وقف')) {
      return 'no';
    }
    return null;
  }
}

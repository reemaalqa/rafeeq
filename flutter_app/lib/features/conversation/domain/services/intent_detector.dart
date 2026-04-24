import '../entities/detected_intent.dart';

/// Keyword-based intent detector with full Saudi dialect support and
/// structured parameter extraction from natural-language commands.
///
/// Detection pipeline:
///   raw text → [_stripDiacritics] → [_normalizeSaudiDialect] → keyword match
///                                 → [_extractParams]
///
/// The dialect normalization step maps common Saudi/Gulf colloquial words to
/// their Modern Standard Arabic (MSA) equivalents so a single keyword list
/// covers both registers.
class IntentDetector {
  // ─── Keyword lists (MSA + Saudi dialect) ────────────────────────────────────

  static const Map<IntentType, List<String>> _keywords = {
    // ── Emergency ──────────────────────────────────────────────────────────────
    IntentType.emergency: [
      // MSA
      'مساعدة', 'نجدة', 'طوارئ', 'استغاثة', 'سقطت', 'وقعت', 'ألم',
      'حادث', 'اتصل بالإسعاف', 'احتاج مساعدة', 'اسعاف', 'إسعاف',
      // Saudi dialect
      'ساعدني', 'ساعدوني', 'الحقني', 'الحقوني', 'في احد', 'في ناس',
      'طحت', 'خبطت', 'تعبت', 'مريض', 'مريضة',
      'يلا ساعدني', 'محتاج مساعدة', 'وجع', 'وجعان',
      'اتصل', 'اتصلوا', 'الحق', 'ادري مريض',
    ],

    // ── Prayer times ───────────────────────────────────────────────────────────
    IntentType.prayerTime: [
      // MSA
      'صلاة', 'وقت الصلاة', 'أذان', 'مواقيت', 'أوقات الصلاة',
      'فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء',
      // Saudi dialect
      'صلي', 'اصلي', 'ابغى اصلي', 'وقت الصله', 'اذان',
      'الاذان', 'متى الصلاة', 'متى نصلي', 'الصلاة كم',
      'الفجر كم', 'الظهر كم', 'العصر كم', 'المغرب كم', 'العشاء كم',
      'وقت الفجر', 'وقت الظهر', 'وقت العصر', 'وقت المغرب', 'وقت العشاء',
      'ايش وقت الصلاة', 'وش وقت الصلاة', 'متى الاذان',
    ],

    // ── Medication ─────────────────────────────────────────────────────────────
    IntentType.medication: [
      // MSA
      'دواء', 'دوائي', 'أدوية', 'حبة', 'جرعة', 'علاج',
      // Saudi dialect
      'دواي', 'حبوب', 'حبوبي', 'حبه', 'حبتي',
      'دواء الضغط', 'دواء السكر', 'دواء القلب',
      'وقت الدواء', 'اخذ دواء', 'ابغى دواء', 'موعد الدواء',
      'ذكرني بالدواء', 'نسيت دوائي', 'حان وقت الدواء',
    ],

    // ── Diet / food ────────────────────────────────────────────────────────────
    IntentType.diet: [
      // MSA
      'أكل', 'طعام', 'وجبة', 'فطور', 'غداء', 'عشاء', 'سعرات',
      'نظام غذائي', 'وجبات', 'خطة غذاء', 'طعام صحي', 'حمية',
      // Saudi dialect
      'اكل', 'وش اكل', 'ايش اكل', 'جوعان', 'جوعانة', 'جوعانين',
      'فطار', 'غدا', 'عشا',
      'وش فيه', 'ايش فيه', 'وش للاكل',
      'ابغى اكل', 'ابي اكل', 'نفسي اكل',
      'اكل صحي', 'رجيم', 'تخسيس', 'السعرات',
    ],

    // ── Reminders ──────────────────────────────────────────────────────────────
    IntentType.reminders: [
      // MSA
      'تذكير', 'تذكيرات', 'ذكرني', 'أضف تذكير', 'موعد', 'مواعيد',
      'تذكرني', 'اضبط تذكير', 'إضافة تذكير', 'تنبيه', 'منبه',
      // Saudi dialect
      'ذكرني بـ', 'اضبط لي', 'اضبطلي', 'ضبطلي',
      'مو ناسيني', 'ما اتنسى', 'خلني اتذكر',
      'موعد الطبيب', 'موعد الدكتور', 'عندي موعد',
      'ابغى اتذكر', 'ابي تذكير', 'حط لي منبه', 'ضبطلي منبه',
      'ذكرني عند', 'ذكرني الساعة',
    ],

    // ── Quran ──────────────────────────────────────────────────────────────────
    IntentType.quran: [
      // MSA
      'قرآن', 'سورة', 'آية', 'تلاوة', 'اقرأ', 'سور',
      'الفاتحة', 'البقرة', 'ياسين', 'الكهف', 'الملك', 'الرحمن',
      // Saudi dialect
      'قران', 'سوره', 'ايه', 'آيه',
      'اسمع قرآن', 'اسمع قران', 'شغل قرآن', 'بغيت قرآن',
      'ابغى قرآن', 'ابي قرآن', 'سمعني قرآن',
      'اقرا علي', 'اقرأ لي', 'تشغيل قرآن',
      'فيني اسمع', 'بغيت اسمع',
    ],

    // ── Islamic advice ─────────────────────────────────────────────────────────
    IntentType.islamicAdvice: [
      // MSA
      'نصيحة', 'نصائح', 'ذكر', 'دعاء', 'حديث', 'حكمة', 'توجيه',
      'إرشاد ديني', 'موعظة', 'ذكر الله',
      // Saudi dialect
      'نصيحه', 'دعاوي', 'اسمع حديث', 'حديث نبوي',
      'كلمة اليوم', 'وش الدعاء', 'ايش الدعاء',
      'علمني', 'علمني دعاء', 'استغفر',
      'ابغى دعاء', 'ابي دعاء', 'قولي دعاء',
    ],

    // ── Locations ──────────────────────────────────────────────────────────────
    IntentType.locations: [
      // MSA
      'مسجد', 'مستشفى', 'صيدلية', 'عيادة', 'مكان قريب',
      'أقرب', 'أماكن', 'بحث عن', 'أين', 'خريطة',
      // Saudi dialect
      'وين', 'فين', 'وين اقرب', 'وين في',
      'دلني', 'دلني على', 'وين المسجد', 'وين الصيدلية',
      'وين المستشفى', 'وين العيادة',
      'اقرب مسجد', 'اقرب صيدلية', 'اقرب مستشفى',
      'ابغى روح', 'ابي روح', 'روح وين', 'وين اروح',
    ],

    // ── Conversation / entertainment ───────────────────────────────────────────
    IntentType.conversation: [
      // MSA
      'قصة', 'حكاية', 'نكتة', 'كلام', 'تحدث', 'تكلم',
      'سلي', 'ابدأ محادثة', 'اخبرني', 'حدثني',
      // Saudi dialect
      'قولي', 'قولي قصة', 'قولي نكته', 'حكيلي',
      'كلمني', 'حكاوي', 'سولف', 'سولفلي',
      'فيك تحكي', 'في قصة', 'نكته', 'نكتة',
      'بس تكلم', 'اتكلم معي', 'ترفيه', 'سامرني',
    ],

    // ── Device control ────────────────────────────────────────────────────────
    IntentType.deviceControl: [
      // Volume up
      'ارفع الصوت', 'رفع الصوت', 'زود الصوت', 'اعلى الصوت',
      'صوت اعلى', 'اكبر الصوت', 'كبر الصوت',
      // Volume down
      'اخفض الصوت', 'خفض الصوت', 'نزل الصوت', 'اوطي الصوت',
      'صوت اخفض', 'صغر الصوت', 'اصغر الصوت',
      // Mute
      'اكتم الصوت', 'كتم الصوت', 'صامت', 'بكم الصوت', 'سكوت الصوت',
      // Social apps
      'افتح واتساب', 'شغل واتساب', 'واتساب', 'وتساب',
      'افتح يوتيوب', 'شغل يوتيوب', 'يوتيوب',
      'افتح انستقرام', 'انستقرام', 'انستغرام',
      'افتح تيليجرام', 'تيليجرام', 'تلغرام',
      'افتح فيسبوك', 'فيسبوك',
      'افتح تيكتوك', 'تيكتوك',
      'افتح تويتر', 'تويتر', 'تويتير',
      // Alarm
      'منبه الجوال', 'منبه الموبايل', 'منبه الساعة',
      'اضبط المنبه', 'غير المنبه', 'بدل المنبه', 'حط منبه جديد',
      'اجعل المنبه', 'فتح الساعه', 'افتح الساعه',
    ],
  };

  // ─── Saudi dialect → MSA normalisation map ──────────────────────────────────
  static const Map<String, String> _dialectMap = {
    // Desire / want
    'ابغى': 'أريد',
    'ابغي': 'أريد',
    'ابي': 'أريد',
    'بغيت': 'أريد',
    'نفسي': 'أريد',
    // Question words
    'ايش': 'ماذا',
    'وش': 'ماذا',
    'إيش': 'ماذا',
    // Where
    'وين': 'أين',
    'فين': 'أين',
    // Now
    'الحين': 'الآن',
    'هلا': 'الآن',
    // Medication
    'حبوب': 'دواء',
    'حبوبي': 'دوائي',
    'حبه': 'حبة',
    'حبتي': 'دوائي',
    'دواي': 'دواء',
    // Food
    'جوعان': 'أكل',
    'جوعانة': 'أكل',
    'فطار': 'فطور',
    'غدا': 'غداء',
    'عشا': 'عشاء',
    // Fell / accident
    'طحت': 'سقطت',
    'خبطت': 'اصطدمت',
    // Pain / sick
    'وجعان': 'ألم',
    'وجع': 'ألم',
    'تعبت': 'مريض',
    // Guide me (locations)
    'دلني': 'اذهب إلى',
    // Conversation
    'سولف': 'تحدث',
    'سولفلي': 'حدثني',
    'حكيلي': 'اخبرني',
    'قولي': 'اخبرني',
    // Prayer
    'صليت': 'صليت',
    'اصلي': 'صلاة',
  };

  // ─── Arabic digit words ──────────────────────────────────────────────────────
  static const Map<String, String> _arabicNumbers = {
    'واحدة': '1', 'واحد': '1',
    'اثنتين': '2', 'اثنين': '2', 'ثنتين': '2',
    'ثلاثة': '3', 'ثلاثه': '3',
    'أربعة': '4', 'اربعه': '4', 'اربعة': '4',
    'خمسة': '5', 'خمسه': '5',
    'ستة': '6', 'سته': '6',
    'سبعة': '7', 'سبعه': '7',
    'ثمانية': '8', 'ثمانيه': '8',
    'تسعة': '9', 'تسعه': '9',
    'عشرة': '10', 'عشره': '10',
    'إحدى عشرة': '11', 'احدى عشرة': '11',
    'اثنا عشرة': '12', 'اثناعشرة': '12',
  };

  // ─── All 114 Quran surahs ────────────────────────────────────────────────────
  static const List<String> _surahs = [
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

  // ─── Public API ──────────────────────────────────────────────────────────────

  DetectedIntent detect(String rawText) {
    final normalized = _normalize(rawText);
    // Extra loose-fold (ة↔ه, ى↔ي, أإآ→ا) applied to BOTH sides of every
    // keyword comparison so STT variants match canonical spellings.
    final loose = _looseFoldArabic(normalized);

    bool containsKeyword(String kw) {
      final k = _looseFoldArabic(_normalize(kw));
      return loose.contains(k);
    }

    // Emergency: highest priority — any single keyword match triggers it
    for (final kw in _keywords[IntentType.emergency]!) {
      if (containsKeyword(kw)) {
        return DetectedIntent(
          type: IntentType.emergency,
          confidence: 1.0,
          matchedText: kw,
        );
      }
    }

    // Score all remaining intents
    IntentType? best;
    int bestCount = 0;
    String bestMatch = '';

    for (final entry in _keywords.entries) {
      if (entry.key == IntentType.emergency) continue;
      int count = 0;
      String firstMatch = '';
      for (final kw in entry.value) {
        if (containsKeyword(kw)) {
          count++;
          if (firstMatch.isEmpty) firstMatch = kw;
        }
      }
      if (count > bestCount) {
        bestCount = count;
        best = entry.key;
        bestMatch = firstMatch;
      }
    }

    // Fallback: if no intent scored but the utterance contains any of the
    // 114 surah names (canonical or ال-stripped), it's a Quran request.
    // This catches phrases like "شغل يوسف" or "اقرا يس" that don't contain
    // the word "قرآن" or "سورة".
    if (best == null || bestCount == 0) {
      final quranParams = _extractQuranParams(normalized, rawText);
      if (quranParams['surah'] != null) {
        return DetectedIntent(
          type: IntentType.quran,
          confidence: 0.6,
          matchedText: quranParams['surah']!,
          extractedParams: quranParams,
        );
      }
      return DetectedIntent(
        type: IntentType.general,
        confidence: 0.0,
        matchedText: rawText,
      );
    }

    final params = _extractParams(normalized, rawText, best);

    return DetectedIntent(
      type: best,
      confidence: (bestCount / _keywords[best]!.length).clamp(0.0, 1.0),
      matchedText: bestMatch,
      extractedParams: params,
    );
  }

  // ─── Parameter extraction ────────────────────────────────────────────────────

  Map<String, String> _extractParams(
    String normalized,
    String rawText,
    IntentType type,
  ) {
    switch (type) {
      case IntentType.reminders:
      case IntentType.medication:
        return _extractReminderParams(normalized, rawText);
      case IntentType.quran:
        return _extractQuranParams(normalized, rawText);
      case IntentType.locations:
        return _extractLocationParams(normalized, rawText);
      case IntentType.deviceControl:
        return _extractDeviceControlParams(normalized, rawText);
      default:
        return {};
    }
  }

  Map<String, String> _extractReminderParams(
    String normalized,
    String rawText,
  ) {
    final params = <String, String>{};

    // ── Extract title (what to remind) ─────────────────────────────────────────
    // Patterns: "ذكرني بـ X", "تذكرني بـ X", "اضبط لي تذكير X"
    final titlePatterns = [
      RegExp(r'ذكرني\s+ب[ـ]?\s*([^\s].+?)(?:\s+الساعة|\s+بعد|\s+في\s+الساعة|\s*$)'),
      RegExp(r'تذكرني\s+ب[ـ]?\s*([^\s].+?)(?:\s+الساعة|\s+بعد|\s+في\s+الساعة|\s*$)'),
      RegExp(r'تذكير\s+(?:عن|ل|بـ?)?\s*([^\s].+?)(?:\s+الساعة|\s+بعد|\s*$)'),
    ];
    for (final pattern in titlePatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final title = match.group(1)?.trim() ?? '';
        if (title.isNotEmpty) {
          params['title'] = title;
          break;
        }
      }
    }

    // ── Extract absolute time "الساعة X" ────────────────────────────────────────
    // Handles: "الساعة 3", "الساعة ثلاثة", "الساعة 3:30"
    String timeSource = normalized;
    // Replace Arabic word numbers with digits
    _arabicNumbers.forEach((word, digit) {
      timeSource = timeSource.replaceAll(word, digit);
    });

    final absTimePattern = RegExp(r'الساعة\s+(\d{1,2})(?::(\d{2}))?');
    final absMatch = absTimePattern.firstMatch(timeSource);
    if (absMatch != null) {
      final hour = absMatch.group(1)!.padLeft(2, '0');
      final minute = absMatch.group(2) ?? '00';
      params['time'] = '$hour:$minute';
    }

    // ── Extract relative time "بعد X ساعة/دقيقة" ────────────────────────────────
    final relPattern = RegExp(r'بعد\s+(\d+)\s+(ساعة|دقيقة|دقائق|ساعات)');
    final relMatch = relPattern.firstMatch(timeSource);
    if (relMatch != null) {
      final amount = relMatch.group(1)!;
      final unit = (relMatch.group(2) == 'ساعة' || relMatch.group(2) == 'ساعات')
          ? 'hour'
          : 'minute';
      params['relative_time'] = '+$amount $unit';
    }

    // ── Prayer-based timing ──────────────────────────────────────────────────────
    const prayerKeys = {
      'الفجر': 'fajr', 'الظهر': 'dhuhr', 'العصر': 'asr',
      'المغرب': 'maghrib', 'العشاء': 'isha',
    };
    prayerKeys.forEach((arabic, key) {
      if (normalized.contains(arabic)) params['prayer_anchor'] = key;
    });

    return params;
  }

  Map<String, String> _extractDeviceControlParams(
    String normalized,
    String rawText,
  ) {
    final params = <String, String>{};

    // ── Volume ────────────────────────────────────────────────────────────────
    if (normalized.contains('ارفع الصوت') ||
        normalized.contains('رفع الصوت') ||
        normalized.contains('زود الصوت') ||
        normalized.contains('اعلى الصوت') ||
        normalized.contains('صوت اعلى') ||
        normalized.contains('اكبر الصوت') ||
        normalized.contains('كبر الصوت')) {
      params['action'] = 'volume_up';
      return params;
    }
    if (normalized.contains('اخفض الصوت') ||
        normalized.contains('خفض الصوت') ||
        normalized.contains('نزل الصوت') ||
        normalized.contains('اوطي الصوت') ||
        normalized.contains('صوت اخفض') ||
        normalized.contains('صغر الصوت') ||
        normalized.contains('اصغر الصوت')) {
      params['action'] = 'volume_down';
      return params;
    }
    if (normalized.contains('اكتم') ||
        normalized.contains('كتم الصوت') ||
        normalized.contains('صامت') ||
        normalized.contains('بكم الصوت') ||
        normalized.contains('سكوت الصوت')) {
      params['action'] = 'mute';
      return params;
    }

    // ── App opening ───────────────────────────────────────────────────────────
    const appMap = {
      'واتساب': 'whatsapp',
      'وتساب': 'whatsapp',
      'يوتيوب': 'youtube',
      'انستقرام': 'instagram',
      'انستغرام': 'instagram',
      'تيليجرام': 'telegram',
      'تلغرام': 'telegram',
      'فيسبوك': 'facebook',
      'تيكتوك': 'tiktok',
      'تويتر': 'twitter',
      'تويتير': 'twitter',
    };
    for (final entry in appMap.entries) {
      if (normalized.contains(entry.key) || rawText.contains(entry.key)) {
        params['action'] = 'open_app';
        params['app_name'] = entry.value;
        return params;
      }
    }

    // ── Alarm ─────────────────────────────────────────────────────────────────
    if (normalized.contains('منبه') ||
        normalized.contains('منبيه') ||
        normalized.contains('الساعه') && normalized.contains('اضبط')) {
      params['action'] = 'set_alarm';

      // Extract time if present
      var timeSource = normalized;
      _arabicNumbers.forEach((word, digit) {
        timeSource = timeSource.replaceAll(word, digit);
      });
      final absTimePattern = RegExp(r'الساعه?\s+(\d{1,2})(?::(\d{2}))?');
      final match = absTimePattern.firstMatch(timeSource);
      if (match != null) {
        params['alarm_hour'] = match.group(1)!;
        params['alarm_minute'] = match.group(2) ?? '0';
      }
      return params;
    }

    return params;
  }

  Map<String, String> _extractQuranParams(String normalized, String rawText) {
    final params = <String, String>{};
    // Apply the same letter-variant folding to the input as we do to each
    // surah, so "الفاتحة" / "الفاتحه" / "فاتحه" / "فاتحة" all match the same
    // entry. STT output is inconsistent on ة vs ه and often drops the ال.
    final looseInput = _looseFoldArabic('$rawText $normalized');
    for (final surah in _surahs) {
      final loose = _looseFoldArabic(surah);
      final looseNoAl = loose.startsWith('ال') ? loose.substring(2) : loose;
      // Word-boundary match guards single-letter surahs (ق, ص) from matching
      // inside longer words like "قرآن". Everything else just needs to appear
      // as a whole word.
      if (_containsAsWord(looseInput, loose) ||
          (looseNoAl.length >= 3 && _containsAsWord(looseInput, looseNoAl))) {
        params['surah'] = surah;
        break;
      }
    }
    return params;
  }

  /// Folds Arabic letter variants so matching tolerates common STT spellings.
  static String _looseFoldArabic(String text) {
    var s = text.toLowerCase().trim();
    s = s.replaceAll(
      RegExp(r'[ً-ٰٟؐ-ؚ]'),
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

  Map<String, String> _extractLocationParams(String normalized, String rawText) {
    final params = <String, String>{};
    // Check rawText first (preserves original spelling like ى/ة),
    // then normalized (ى→ي, ة→ه after dialect normalization).
    final combined = '$rawText $normalized';
    if (combined.contains('مسجد') || combined.contains('جامع')) {
      params['place_type'] = 'mosque';
    } else if (combined.contains('صيدلية') || combined.contains('صيدليه') ||
               combined.contains('صيدلي')) {
      params['place_type'] = 'pharmacy';
    } else if (combined.contains('مستشفى') || combined.contains('مستشفي') ||
               combined.contains('مستشفا') || combined.contains('مستشف')) {
      params['place_type'] = 'hospital';
    } else if (combined.contains('عيادة') || combined.contains('عياده') ||
               combined.contains('عياد') ||
               combined.contains('دكتور') || combined.contains('طبيب')) {
      params['place_type'] = 'clinic';
    } else if (combined.contains('مطعم') || combined.contains('اكل')) {
      params['place_type'] = 'restaurant';
    }
    return params;
  }

  // ─── Internal helpers ────────────────────────────────────────────────────────

  String _normalize(String text) {
    final stripped = _stripDiacritics(text);
    final lower = stripped.toLowerCase().trim();
    return _normalizeSaudiDialect(lower);
  }

  String _stripDiacritics(String text) {
    return text.replaceAll(
      RegExp(
        r'[\u064B-\u065F'
        r'\u0670'
        r'\u0610-\u061A'
        r'\u06D6-\u06DC'
        r'\u06DF-\u06E4'
        r'\u06E7\u06E8'
        r'\u06EA-\u06ED]',
      ),
      '',
    );
  }

  String _normalizeSaudiDialect(String text) {
    var result = text;
    _dialectMap.forEach((dialect, msa) {
      result = result.replaceAll(dialect, msa);
    });
    return result;
  }
}

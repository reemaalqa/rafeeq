import '../../../reminders/domain/entities/reminder.dart';

class VoiceCommandParser {
  static const _triggerWords = [
    'ذكرني',
    'تذكرني',
    'تذكير',
    'اضبط تذكير',
    'ضبط تذكير',
    'سوي لي تذكير',
    'سو لي تذكير',
    'ابي تذكير',
    'ابغى تذكير',
    'ودي تذكير',
    'خلني اتذكر',
  ];

  ReminderParseResult? parseReminder(String rawText) {
    final normalized = _normalize(rawText);
    final hasTrigger = _triggerWords.any((w) => normalized.contains(_normalize(w)));
    if (!hasTrigger) {
      return null;
    }

    final now = DateTime.now();
    final relative = _parseRelativeDuration(normalized);
    DateTime? scheduledTime;
    if (relative != null) {
      scheduledTime = now.add(relative);
    } else {
      final timeInfo = _parseAbsoluteTime(normalized);
      if (timeInfo == null) {
        return const ReminderParseResult(hasTrigger: true, missingTime: true);
      }
      final date = _resolveDate(now, normalized);
      scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        timeInfo.hour,
        timeInfo.minute,
      );
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
    }

    final title = _extractTitle(rawText);
    final type = _inferType(normalized);

    return ReminderParseResult(
      hasTrigger: true,
      reminder: ParsedReminderInput(
        title: title.isEmpty ? 'تذكير' : title,
        scheduledTime: scheduledTime,
        type: type,
        repeat: RepeatInterval.none,
      ),
    );
  }

  Duration? _parseRelativeDuration(String text) {
    final match = RegExp(
      r'بعد\s+(\d+)\s+(دقيقة|دقائق|دقايق|ساعة|ساعات|ساعه)',
    ).firstMatch(text);
    if (match == null) return null;
    final value = int.tryParse(match.group(1) ?? '');
    if (value == null) return null;
    final unit = match.group(2) ?? '';
    if (unit.contains('ساعة') || unit.contains('ساعه') || unit.contains('ساعات')) {
      return Duration(hours: value);
    }
    return Duration(minutes: value);
  }

  _TimeInfo? _parseAbsoluteTime(String text) {
    final timeMatch = RegExp(
      r'(?:الساعة|عند|حوالي)?\s*(\d{1,2})(?::(\d{1,2}))?',
    ).firstMatch(text);
    if (timeMatch == null) return null;

    final rawHour = int.tryParse(timeMatch.group(1) ?? '');
    if (rawHour == null) return null;
    final rawMinute = int.tryParse(timeMatch.group(2) ?? '');
    int hour = rawHour;
    int minute = rawMinute ?? 0;

    if (rawMinute == null) {
      if (text.contains('الا ربع') || text.contains('إلا ربع')) {
        minute = 45;
        hour = (hour - 1) % 24;
      } else if (text.contains('ونص')) {
        minute = 30;
      } else if (text.contains('وربع')) {
        minute = 15;
      }
    }

    hour = _applyDayPeriod(hour, text);
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return _TimeInfo(hour: hour, minute: minute);
  }

  int _applyDayPeriod(int hour, String text) {
    final isMorning = text.contains('صباح') || text.contains('فجر');
    final isEvening = text.contains('مساء') ||
        text.contains('عصر') ||
        text.contains('مغرب') ||
        text.contains('عشا') ||
        text.contains('عشاء') ||
        text.contains('ليل');
    final isNoon = text.contains('ظهر');

    if (isMorning) {
      if (hour == 12) return 0;
      return hour;
    }
    if (isNoon) {
      if (hour < 12) return hour + 12;
      return hour;
    }
    if (isEvening) {
      if (hour < 12) return hour + 12;
      return hour;
    }
    return hour;
  }

  DateTime _resolveDate(DateTime now, String text) {
    if (text.contains('بكرة') || text.contains('بكره') || text.contains('غدا')) {
      return now.add(const Duration(days: 1));
    }
    if (text.contains('الليلة') || text.contains('الليل')) {
      return now;
    }
    return now;
  }

  ReminderType _inferType(String text) {
    if (text.contains('دواء') || text.contains('حبوب')) {
      return ReminderType.medication;
    }
    if (text.contains('صلاة') ||
        text.contains('اذان') ||
        text.contains('أذان') ||
        text.contains('فجر') ||
        text.contains('ظهر') ||
        text.contains('عصر') ||
        text.contains('مغرب') ||
        text.contains('عشاء')) {
      return ReminderType.prayer;
    }
    if (text.contains('موعد') || text.contains('دكتور') || text.contains('طبيب')) {
      return ReminderType.appointment;
    }
    if (text.contains('ماء') || text.contains('موية') || text.contains('اشرب')) {
      return ReminderType.hydration;
    }
    return ReminderType.custom;
  }

  String _extractTitle(String rawText) {
    var text = rawText;
    text = text.replaceAll(
      RegExp(r'(ذكرني|تذكرني|تذكير|اضبط تذكير|ضبط تذكير|سوي لي تذكير|سو لي تذكير|ابي تذكير|ابغى تذكير|ودي تذكير|خلني اتذكر)', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'(الساعة\s*[0-9٠-٩]{1,2}([:٫][0-9٠-٩]{1,2})?|بعد\s*[0-9٠-٩]+\s*(دقيقة|دقائق|دقايق|ساعة|ساعات|ساعه)|[0-9٠-٩]{1,2}[:٫][0-9٠-٩]{1,2})'),
      '',
    );
    text = text.replaceAll(
      RegExp(r'(بكرة|بكره|غدا|اليوم|الليلة|الليل|الصبح|الصباح|المساء|العصر|الظهر|الفجر|المغرب|العشاء)'),
      '',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  String _normalize(String text) {
    var s = text.trim().toLowerCase();
    s = _stripDiacritics(s);
    s = s.replaceAll('ـ', '');
    s = _normalizeArabicVariants(s);
    s = _normalizeDigits(s);
    s = s.replaceAll(RegExp(r'[^\p{L}\p{N}\s:]+', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  String _normalizeArabicVariants(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
  }

  String _normalizeDigits(String text) {
    const map = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };
    var result = text;
    map.forEach((k, v) => result = result.replaceAll(k, v));
    return result;
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
}

class ReminderParseResult {
  final bool hasTrigger;
  final bool missingTime;
  final ParsedReminderInput? reminder;

  const ReminderParseResult({
    required this.hasTrigger,
    this.missingTime = false,
    this.reminder,
  });
}

class ParsedReminderInput {
  final String title;
  final DateTime scheduledTime;
  final ReminderType type;
  final RepeatInterval repeat;

  const ParsedReminderInput({
    required this.title,
    required this.scheduledTime,
    required this.type,
    required this.repeat,
  });
}

class _TimeInfo {
  final int hour;
  final int minute;

  const _TimeInfo({required this.hour, required this.minute});
}

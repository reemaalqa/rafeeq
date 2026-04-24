import 'package:equatable/equatable.dart';

class PrayerTimes extends Equatable {
  final DateTime fajr;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime date;
  final String location;

  const PrayerTimes({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    required this.location,
  });

  /// Returns the key of the next prayer (matches ARB keys: fajr, dhuhr, asr, maghrib, isha).
  /// After Isha the key is 'fajr' (tomorrow).
  String get nextPrayerKey {
    final now = DateTime.now();
    if (now.isBefore(fajr)) return 'fajr';
    if (now.isBefore(dhuhr)) return 'dhuhr';
    if (now.isBefore(asr)) return 'asr';
    if (now.isBefore(maghrib)) return 'maghrib';
    if (now.isBefore(isha)) return 'isha';
    return 'fajr'; // after Isha → next is tomorrow's Fajr
  }

  /// Returns the actual DateTime of the next prayer.
  /// After Isha returns tomorrow's Fajr (fajr + 1 day) instead of today's past Fajr.
  DateTime get nextPrayerTime {
    final now = DateTime.now();
    if (now.isBefore(fajr)) return fajr;
    if (now.isBefore(dhuhr)) return dhuhr;
    if (now.isBefore(asr)) return asr;
    if (now.isBefore(maghrib)) return maghrib;
    if (now.isBefore(isha)) return isha;
    return fajr.add(const Duration(days: 1)); // tomorrow's Fajr
  }

  /// Arabic display name (used where l10n is not available, e.g. domain services).
  String get nextPrayerName {
    switch (nextPrayerKey) {
      case 'fajr': return 'الفجر';
      case 'dhuhr': return 'الظهر';
      case 'asr': return 'العصر';
      case 'maghrib': return 'المغرب';
      case 'isha': return 'العشاء';
      default: return 'الفجر';
    }
  }

  @override
  List<Object?> get props => [fajr, dhuhr, asr, maghrib, isha, date, location];
}

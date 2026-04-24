import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/surah.dart';
import '../../domain/entities/islamic_advice.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/repositories/islamic_repository.dart';
import '../datasources/islamic_local_datasource.dart';
import '../datasources/islamic_remote_datasource.dart';

class IslamicRepositoryImpl implements IslamicRepository {
  final IslamicLocalDatasource _local;
  final IslamicRemoteDataSource _remote;
  final SharedPreferences _prefs;

  const IslamicRepositoryImpl(this._local, this._remote, this._prefs);

  /// Quran data is loaded from local JSON asset — no backend needed.
  @override
  Future<Either<Failure, List<Surah>>> getSurahs() async {
    try {
      return Right(await _local.getSurahs());
    } catch (e) {
      return Left(CacheFailure('Failed to load Quran data: $e'));
    }
  }

  /// Try backend islamic_content first; fallback to static local list.
  @override
  Future<Either<Failure, List<IslamicAdvice>>> getAdviceList() async {
    try {
      final data = await _remote.getIslamicContent();
      if (data.isNotEmpty) {
        final advice = data
            .where((m) => m['body_ar'] != null || m['body_en'] != null)
            .map((m) => IslamicAdvice(
                  id: m['id'].toString(),
                  category: _mapCategory(m['content_type'] as String?),
                  arabicText: m['body_ar'] as String? ?? '',
                  transliteration: '',
                  englishText: m['body_en'] as String? ?? '',
                  source: 'Rafeeq',
                ))
            .toList();
        if (advice.isNotEmpty) return Right(advice);
      }
    } on NetworkException {
      // offline — fall through
    } catch (_) {
      // fall through
    }
    // Local static fallback
    try {
      return Right(_local.getAdviceList());
    } catch (e) {
      return Left(CacheFailure('Failed to load advice: $e'));
    }
  }

  AdviceCategory _mapCategory(String? type) {
    switch (type) {
      case 'dua':    return AdviceCategory.dua;
      case 'hadith': return AdviceCategory.hadith;
      default:       return AdviceCategory.dhikr;
    }
  }

  /// Accurate prayer times via astronomical calculation (Umm al-Qura method).
  /// Result is cached for the day; reverse-geocoded city name shown in UI.
  @override
  Future<Either<Failure, PrayerTimes>> getPrayerTimes({
    required double lat,
    required double lng,
  }) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';

      // Bump this string whenever the calculation method or adjustments change
      // so the old cache is automatically ignored.
      const _cacheVersion = 'v3-no-adj';

      // ── Cache check ───────────────────────────────────────────────────────
      final cachedDate    = _prefs.getString(StorageKeys.prayerTimesCacheDate);
      final cachedVersion = _prefs.getString('prayer_times_cache_version');
      final cachedJson    = _prefs.getString(StorageKeys.prayerTimesCache);
      final cachedLat     = _prefs.getDouble(StorageKeys.lastKnownLatitude);
      final cachedLng     = _prefs.getDouble(StorageKeys.lastKnownLongitude);

      final locationClose = cachedLat != null && cachedLng != null &&
          (cachedLat - lat).abs() < 0.05 && (cachedLng - lng).abs() < 0.05;

      if (cachedDate == todayStr &&
          cachedVersion == _cacheVersion &&
          cachedJson != null &&
          locationClose) {
        return Right(_fromJson(json.decode(cachedJson) as Map<String, dynamic>));
      }

      // ── Reverse geocode city name ─────────────────────────────────────────
      String cityName = '${lat.toStringAsFixed(2)}° ${lng.toStringAsFixed(2)}°';
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          cityName = p.locality?.isNotEmpty == true
              ? p.locality!
              : (p.administrativeArea ?? cityName);
        }
      } catch (_) {}

      // ── Calculate ─────────────────────────────────────────────────────────
      final times = _local.calculatePrayerTimes(
        lat: lat, lng: lng, date: today, location: cityName,
      );

      // ── Persist cache ─────────────────────────────────────────────────────
      await _prefs.setString(StorageKeys.prayerTimesCacheDate, todayStr);
      await _prefs.setString('prayer_times_cache_version', _cacheVersion);
      await _prefs.setString(StorageKeys.prayerTimesCache, json.encode(_toJson(times)));
      await _prefs.setDouble(StorageKeys.lastKnownLatitude, lat);
      await _prefs.setDouble(StorageKeys.lastKnownLongitude, lng);

      // ── Save to backend for history (best-effort) ─────────────────────────
      try {
        await _remote.savePrayerTimes({
          'prayer_date': todayStr,
          'fajr_time':    _fmt(times.fajr),
          'dhuhr_time':   _fmt(times.dhuhr),
          'asr_time':     _fmt(times.asr),
          'maghrib_time': _fmt(times.maghrib),
          'isha_time':    _fmt(times.isha),
          'location_latitude':  lat,
          'location_longitude': lng,
          'timezone': today.timeZoneName,
        });
      } catch (_) {}

      return Right(times);
    } catch (e) {
      return Left(CacheFailure('Failed to calculate prayer times: $e'));
    }
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00';

  Map<String, dynamic> _toJson(PrayerTimes t) => {
    'fajr':    t.fajr.millisecondsSinceEpoch,
    'dhuhr':   t.dhuhr.millisecondsSinceEpoch,
    'asr':     t.asr.millisecondsSinceEpoch,
    'maghrib': t.maghrib.millisecondsSinceEpoch,
    'isha':    t.isha.millisecondsSinceEpoch,
    'date':    t.date.millisecondsSinceEpoch,
    'location': t.location,
  };

  PrayerTimes _fromJson(Map<String, dynamic> m) => PrayerTimes(
    fajr:    DateTime.fromMillisecondsSinceEpoch(m['fajr'] as int),
    dhuhr:   DateTime.fromMillisecondsSinceEpoch(m['dhuhr'] as int),
    asr:     DateTime.fromMillisecondsSinceEpoch(m['asr'] as int),
    maghrib: DateTime.fromMillisecondsSinceEpoch(m['maghrib'] as int),
    isha:    DateTime.fromMillisecondsSinceEpoch(m['isha'] as int),
    date:    DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    location: m['location'] as String? ?? '',
  );
}

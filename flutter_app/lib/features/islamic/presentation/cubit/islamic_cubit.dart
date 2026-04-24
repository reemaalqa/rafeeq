import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/tts_service.dart';
import '../../domain/entities/surah.dart';
import '../../domain/usecases/get_surahs.dart';
import '../../domain/usecases/get_daily_advice.dart';
import '../../domain/usecases/calculate_prayer_times.dart';
import 'islamic_state.dart';

class IslamicCubit extends Cubit<IslamicState> {
  final GetSurahs _getSurahs;
  final GetDailyAdvice _getDailyAdvice;
  final CalculatePrayerTimes _calculatePrayerTimes;
  final TtsService _tts;
  final FlutterLocalNotificationsPlugin _notifications;

  /// Streams Quran recitation from everyayah.com (Sheikh Alafasy). Kept
  /// separate from [_tts] so TTS can still read Adhkar / advice in the
  /// device's Arabic voice while Quran audio uses an authentic reciter.
  final AudioPlayer _quranPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _quranPlayerSub;
  StreamSubscription<Duration>? _quranPositionSub;
  StreamSubscription<Duration?>? _quranDurationSub;

  /// Human-readable reciter label shown in the player UI.
  static const String reciterName = 'الشيخ مشاري العفاسي';

  /// Monotonically increasing id for each `setUrl()` call. Paired with
  /// [_lastCompletedGen] it ensures a single ProcessingState.completed
  /// transition advances the ayah only once.
  int _playbackGen = 0;
  int _lastCompletedGen = -1;

  IslamicCubit({
    required GetSurahs getSurahs,
    required GetDailyAdvice getDailyAdvice,
    required CalculatePrayerTimes calculatePrayerTimes,
    required TtsService tts,
    required FlutterLocalNotificationsPlugin notifications,
  })  : _getSurahs = getSurahs,
        _getDailyAdvice = getDailyAdvice,
        _calculatePrayerTimes = calculatePrayerTimes,
        _tts = tts,
        _notifications = notifications,
        super(const IslamicState()) {
    // IMPORTANT: no TTS completion handler here. Quran uses the audio
    // player exclusively; hooking the shared FlutterTts completion would
    // fight the reciter audio (causing double voices) whenever any TTS
    // utterance from another feature finished while we were playing.
    //
    // Auto-advance + buffering state come from the just_audio stream only.
    // `_lastCompletedGen` dedupes completion events — the player can emit
    // ProcessingState.completed repeatedly while we tear down / reload the
    // next ayah, which otherwise causes double-skips.
    _quranPlayerSub = _quranPlayer.playerStateStream.listen((ps) {
      if (isClosed) return;
      final buffering = ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering;
      if (buffering != state.isBuffering) {
        emit(state.copyWith(isBuffering: buffering));
      }
      if (ps.processingState == ProcessingState.completed &&
          state.isTtsPlaying &&
          _lastCompletedGen != _playbackGen) {
        _lastCompletedGen = _playbackGen;
        _onQuranAyahComplete();
      }
    });
    _quranPositionSub = _quranPlayer.positionStream.listen((pos) {
      if (!isClosed) emit(state.copyWith(audioPosition: pos));
    });
    _quranDurationSub = _quranPlayer.durationStream.listen((dur) {
      if (!isClosed && dur != null) emit(state.copyWith(audioDuration: dur));
    });
  }

  Future<void> loadSurahs() async {
    emit(state.copyWith(status: IslamicStatus.loading));
    final result = await _getSurahs();
    result.fold(
      (f) => emit(state.copyWith(status: IslamicStatus.error, errorMessage: f.message)),
      (surahs) => emit(state.copyWith(status: IslamicStatus.loaded, surahs: surahs)),
    );
  }

  Future<void> loadAdvice() async {
    final result = await _getDailyAdvice();
    result.fold(
      (f) => emit(state.copyWith(status: IslamicStatus.error, errorMessage: f.message)),
      (advice) {
        // Load full list from repository
        emit(state.copyWith(status: IslamicStatus.loaded));
      },
    );

    // Load full list for swiping
    final repoResult = await _getSurahs(); // use a separate call path if needed
    // For advice list, load directly
    final adviceResult = await _getDailyAdvice();
    adviceResult.fold((_) {}, (_) {});
  }

  Future<void> loadAdviceList() async {
    // Load all advice for swiping
    emit(state.copyWith(status: IslamicStatus.loading));
    // We compute daily advice from the full list
    final result = await _getDailyAdvice();
    result.fold(
      (f) => emit(state.copyWith(status: IslamicStatus.error, errorMessage: f.message)),
      (advice) {
        // Get the full advice list from datasource directly via use case chain
        final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
        emit(state.copyWith(status: IslamicStatus.loaded));
      },
    );
  }

  void selectSurah(Surah surah) {
    emit(state.copyWith(selectedSurah: surah, currentAyahIndex: 0, isTtsPlaying: false));
  }

  Future<void> playCurrentAyah() async {
    final surah = state.selectedSurah;
    if (surah == null || state.currentAyahIndex >= surah.ayahs.length) return;

    final ayah = surah.ayahs[state.currentAyahIndex];

    // Hard-stop any in-flight TTS (from the conversation flow or a
    // previous advice read) BEFORE starting the reciter. Without this,
    // Google TTS and the mp3 overlap for a couple of seconds.
    await _tts.stop();
    await _quranPlayer.stop();

    // everyayah.com URL pattern: SSSVVV.mp3 where SSS is the zero-padded
    // surah number (1-114) and VVV the zero-padded ayah number within
    // the surah. Sheikh Mishary Alafasy at 128 kbps - clear articulation
    // and reliable CDN availability from the Gulf.
    final sss = surah.number.toString().padLeft(3, '0');
    final vvv = ayah.number.toString().padLeft(3, '0');
    final url = 'https://everyayah.com/data/Alafasy_128kbps/$sss$vvv.mp3';

    // New playback generation - completion events from the previous
    // ayah are ignored via _lastCompletedGen.
    _playbackGen++;

    emit(state.copyWith(
      isTtsPlaying: true,
      isBuffering: true,
      audioPosition: Duration.zero,
    ));
    try {
      await _quranPlayer.setUrl(url);
      await _quranPlayer.setSpeed(state.ttsSpeed.clamp(0.7, 1.3));
      await _quranPlayer.play();
    } catch (_) {
      // Network/CDN unreachable - surface the error instead of silently
      // falling back to Google TTS (which caused double audio when the
      // reciter eventually caught up). User can retry from the player.
      emit(state.copyWith(
        isTtsPlaying: false,
        isBuffering: false,
        errorMessage: 'تعذر تشغيل التلاوة. تأكد من الاتصال بالإنترنت.',
      ));
    }
  }

  void pauseTts() {
    _tts.stop();
    _quranPlayer.stop();
    emit(state.copyWith(isTtsPlaying: false));
  }

  void nextAyah() {
    final surah = state.selectedSurah;
    if (surah == null) return;
    if (state.currentAyahIndex < surah.ayahs.length - 1) {
      emit(state.copyWith(
        currentAyahIndex: state.currentAyahIndex + 1,
        audioPosition: Duration.zero,
      ));
      if (state.isTtsPlaying) playCurrentAyah();
    }
  }

  void prevAyah() {
    if (state.currentAyahIndex > 0) {
      emit(state.copyWith(
        currentAyahIndex: state.currentAyahIndex - 1,
        audioPosition: Duration.zero,
      ));
      if (state.isTtsPlaying) playCurrentAyah();
    }
  }

  /// Jump playback to a specific ayah — used when the user taps an ayah
  /// card in the reader. Starts audio immediately.
  Future<void> playAyahAt(int index) async {
    final surah = state.selectedSurah;
    if (surah == null) return;
    if (index < 0 || index >= surah.ayahs.length) return;
    emit(state.copyWith(
      currentAyahIndex: index,
      audioPosition: Duration.zero,
    ));
    await playCurrentAyah();
  }

  /// Scrubs within the currently playing ayah.
  Future<void> seekTo(Duration position) async {
    await _quranPlayer.seek(position);
  }

  void cycleRepeatMode() {
    final next = switch (state.repeatMode) {
      RepeatMode.none => RepeatMode.singleAyah,
      RepeatMode.singleAyah => RepeatMode.surah,
      RepeatMode.surah => RepeatMode.none,
    };
    emit(state.copyWith(repeatMode: next));
  }

  void setTtsSpeed(double speed) {
    emit(state.copyWith(ttsSpeed: speed));
    _tts.setSpeechRate(speed);
    // Keep Quran playback in sync when the slider changes mid-recitation.
    _quranPlayer.setSpeed(speed.clamp(0.7, 1.3));
  }

  void _onTtsComplete() {
    nextAyah();
    if (state.isTtsPlaying) {
      playCurrentAyah();
    }
  }

  /// Invoked when the Quran reciter audio for the current ayah finishes.
  /// Behaviour depends on the user's repeat mode:
  ///   - singleAyah → replay the same ayah
  ///   - surah      → advance, wrap to the start when the surah ends
  ///   - none       → advance, stop at end of surah
  void _onQuranAyahComplete() {
    final surah = state.selectedSurah;
    if (surah == null) return;

    if (state.repeatMode == RepeatMode.singleAyah) {
      playCurrentAyah();
      return;
    }

    if (state.currentAyahIndex < surah.ayahs.length - 1) {
      emit(state.copyWith(
        currentAyahIndex: state.currentAyahIndex + 1,
        audioPosition: Duration.zero,
      ));
      playCurrentAyah();
      return;
    }

    // End of surah.
    if (state.repeatMode == RepeatMode.surah) {
      emit(state.copyWith(
        currentAyahIndex: 0,
        audioPosition: Duration.zero,
      ));
      playCurrentAyah();
    } else {
      emit(state.copyWith(isTtsPlaying: false, audioPosition: Duration.zero));
    }
  }

  void setAdviceIndex(int index) {
    emit(state.copyWith(currentAdviceIndex: index));
  }

  Future<void> speakAdvice(String text) async {
    await _tts.setLanguage('ar-SA');
    await _tts.setSpeechRate(state.ttsSpeed);
    await _tts.speak(text);
    emit(state.copyWith(isTtsPlaying: true));
  }

  Future<void> loadPrayerTimes({required double lat, required double lng}) async {
    final result = await _calculatePrayerTimes(lat: lat, lng: lng);
    result.fold(
      (f) => emit(state.copyWith(errorMessage: f.message)),
      (times) {
        emit(state.copyWith(prayerTimes: times));
        _syncPrayerNotifications(times.fajr, times.dhuhr, times.asr, times.maghrib, times.isha);
      },
    );
  }

  // Prayer notification IDs — fixed so they can be cancelled by ID
  static const _prayerIds = [2001, 2002, 2003, 2004, 2005];
  static const _prayerNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

  Future<void> _syncPrayerNotifications(
    DateTime fajr, DateTime dhuhr, DateTime asr, DateTime maghrib, DateTime isha,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(StorageKeys.prayerTimesEnabled) ?? true;

      // Always cancel existing prayer notifications first
      for (final id in _prayerIds) {
        await _notifications.cancel(id);
      }

      if (!enabled) return;

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_channel',
          'أوقات الصلاة',
          channelDescription: 'إشعارات أوقات الصلاة',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      );

      final prayers = [fajr, dhuhr, asr, maghrib, isha];
      final now = tz.TZDateTime.now(tz.local);

      for (int i = 0; i < prayers.length; i++) {
        final scheduledTz = tz.TZDateTime.from(prayers[i], tz.local);
        if (scheduledTz.isBefore(now)) continue; // skip past prayers
        await _notifications.zonedSchedule(
          _prayerIds[i],
          'حان وقت ${_prayerNames[i]}',
          'اللهم اجعلنا من المحافظين على الصلاة',
          scheduledTz,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // Notification scheduling is non-critical — fail silently
    }
  }

  @override
  Future<void> close() async {
    _tts.stop();
    await _quranPlayerSub?.cancel();
    await _quranPositionSub?.cancel();
    await _quranDurationSub?.cancel();
    await _quranPlayer.dispose();
    return super.close();
  }
}

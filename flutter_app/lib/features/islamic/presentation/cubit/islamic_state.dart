import 'package:equatable/equatable.dart';
import '../../domain/entities/surah.dart';
import '../../domain/entities/islamic_advice.dart';
import '../../domain/entities/prayer_times.dart';

enum IslamicStatus { initial, loading, loaded, error }

/// Quran playback repeat behaviour.
///   none        — stop at end of surah.
///   singleAyah  — loop the current ayah.
///   surah       — loop the whole surah from the start.
enum RepeatMode { none, singleAyah, surah }

class IslamicState extends Equatable {
  final List<Surah> surahs;
  final Surah? selectedSurah;
  final int currentAyahIndex;
  final bool isTtsPlaying;
  final bool isBuffering;
  final double ttsSpeed;
  final Duration audioPosition;
  final Duration audioDuration;
  final RepeatMode repeatMode;
  final List<IslamicAdvice> adviceList;
  final int currentAdviceIndex;
  final PrayerTimes? prayerTimes;
  final IslamicStatus status;
  final String? errorMessage;

  const IslamicState({
    this.surahs = const [],
    this.selectedSurah,
    this.currentAyahIndex = 0,
    this.isTtsPlaying = false,
    this.isBuffering = false,
    this.ttsSpeed = 1.0,
    this.audioPosition = Duration.zero,
    this.audioDuration = Duration.zero,
    this.repeatMode = RepeatMode.none,
    this.adviceList = const [],
    this.currentAdviceIndex = 0,
    this.prayerTimes,
    this.status = IslamicStatus.initial,
    this.errorMessage,
  });

  IslamicAdvice? get dailyAdvice {
    if (adviceList.isEmpty) return null;
    return adviceList[currentAdviceIndex % adviceList.length];
  }

  IslamicState copyWith({
    List<Surah>? surahs,
    Surah? selectedSurah,
    int? currentAyahIndex,
    bool? isTtsPlaying,
    bool? isBuffering,
    double? ttsSpeed,
    Duration? audioPosition,
    Duration? audioDuration,
    RepeatMode? repeatMode,
    List<IslamicAdvice>? adviceList,
    int? currentAdviceIndex,
    PrayerTimes? prayerTimes,
    IslamicStatus? status,
    String? errorMessage,
  }) {
    return IslamicState(
      surahs: surahs ?? this.surahs,
      selectedSurah: selectedSurah ?? this.selectedSurah,
      currentAyahIndex: currentAyahIndex ?? this.currentAyahIndex,
      isTtsPlaying: isTtsPlaying ?? this.isTtsPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      audioPosition: audioPosition ?? this.audioPosition,
      audioDuration: audioDuration ?? this.audioDuration,
      repeatMode: repeatMode ?? this.repeatMode,
      adviceList: adviceList ?? this.adviceList,
      currentAdviceIndex: currentAdviceIndex ?? this.currentAdviceIndex,
      prayerTimes: prayerTimes ?? this.prayerTimes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        surahs,
        selectedSurah,
        currentAyahIndex,
        isTtsPlaying,
        isBuffering,
        ttsSpeed,
        audioPosition,
        audioDuration,
        repeatMode,
        adviceList,
        currentAdviceIndex,
        prayerTimes,
        status,
        errorMessage,
      ];
}

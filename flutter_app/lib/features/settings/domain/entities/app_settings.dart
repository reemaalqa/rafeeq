import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Named scale for text display preference (elderly-optimised).
enum FontSize {
  normal,
  large,
  extraLarge,
}

/// Immutable domain entity representing all user-configurable application settings.
class AppSettings extends Equatable {
  final ThemeMode themeMode;
  final Locale locale;

  /// TTS voice gender: 'male' | 'female'
  final String voiceType;

  /// Speech rate multiplier, clamped to [0.5, 1.5].
  final double voiceSpeed;

  final FontSize fontSize;
  final bool remindersEnabled;
  final bool prayerTimesEnabled;
  final bool voiceFeedbackEnabled;
  final bool hapticFeedbackEnabled;

  const AppSettings({
    required this.themeMode,
    required this.locale,
    required this.voiceType,
    required this.voiceSpeed,
    required this.fontSize,
    required this.remindersEnabled,
    required this.prayerTimesEnabled,
    required this.voiceFeedbackEnabled,
    required this.hapticFeedbackEnabled,
  });

  /// Returns sensible defaults suitable for a first-launch experience.
  factory AppSettings.defaults() {
    return const AppSettings(
      themeMode: ThemeMode.light,
      locale: Locale('ar', ''),
      voiceType: 'female',
      voiceSpeed: 0.8,
      fontSize: FontSize.normal,
      remindersEnabled: true,
      prayerTimesEnabled: true,
      voiceFeedbackEnabled: true,
      hapticFeedbackEnabled: true,
    );
  }

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? voiceType,
    double? voiceSpeed,
    FontSize? fontSize,
    bool? remindersEnabled,
    bool? prayerTimesEnabled,
    bool? voiceFeedbackEnabled,
    bool? hapticFeedbackEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      voiceType: voiceType ?? this.voiceType,
      voiceSpeed: voiceSpeed ?? this.voiceSpeed,
      fontSize: fontSize ?? this.fontSize,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      prayerTimesEnabled: prayerTimesEnabled ?? this.prayerTimesEnabled,
      voiceFeedbackEnabled: voiceFeedbackEnabled ?? this.voiceFeedbackEnabled,
      hapticFeedbackEnabled: hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        locale,
        voiceType,
        voiceSpeed,
        fontSize,
        remindersEnabled,
        prayerTimesEnabled,
        voiceFeedbackEnabled,
        hapticFeedbackEnabled,
      ];
}

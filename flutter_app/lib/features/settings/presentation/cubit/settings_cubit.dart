import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/tts_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/get_settings.dart';
import '../../domain/usecases/update_settings.dart';
import 'settings_state.dart';

/// Manages loading, exposing, and updating application settings.
/// Acts as a lightweight bridge between the domain layer and the UI.
class SettingsCubit extends Cubit<SettingsState> {
  final GetSettings _getSettings;
  final UpdateSettings _updateSettings;
  final TtsService _tts;

  SettingsCubit({
    required GetSettings getSettings,
    required UpdateSettings updateSettings,
    required TtsService tts,
  })  : _getSettings = getSettings,
        _updateSettings = updateSettings,
        _tts = tts,
        super(const SettingsState());

  /// Loads persisted settings from local storage and applies TTS voice.
  Future<void> loadSettings() async {
    emit(state.copyWith(status: SettingsStatus.loading));
    final result = await _getSettings();
    result.fold(
      (failure) => emit(state.copyWith(status: SettingsStatus.error)),
      (settings) {
        emit(state.copyWith(status: SettingsStatus.loaded, settings: settings));
        _applyVoiceGender(settings.voiceType);
      },
    );
  }

  /// Updates the TTS voice type, applies it immediately, and persists the change.
  Future<void> updateVoiceType(String type) async {
    if (state.settings == null) return;
    _applyVoiceGender(type);
    final updated = state.settings!.copyWith(voiceType: type);
    await _persistAndEmit(updated);
  }

  /// Applies gender to the TTS service via pitch.
  /// male → lower pitch (0.85), female → higher pitch (1.35).
  void _applyVoiceGender(String voiceType) {
    final pitch = voiceType == 'female' ? 1.35 : 0.85;
    _tts.setPitch(pitch);
  }

  /// Toggles reminder notifications on or off.
  /// If settings haven't loaded yet, we seed with defaults so the user's
  /// tap isn't silently dropped (previous behaviour: `return` on null).
  Future<void> toggleReminders(bool enabled) async {
    final base = state.settings ?? AppSettings.defaults();
    final updated = base.copyWith(remindersEnabled: enabled);
    await _persistAndEmit(updated);
  }

  Future<void> togglePrayerTimes(bool enabled) async {
    final base = state.settings ?? AppSettings.defaults();
    final updated = base.copyWith(prayerTimesEnabled: enabled);
    await _persistAndEmit(updated);
  }

  Future<void> toggleVoiceFeedback(bool enabled) async {
    final base = state.settings ?? AppSettings.defaults();
    final updated = base.copyWith(voiceFeedbackEnabled: enabled);
    await _persistAndEmit(updated);
  }

  Future<void> toggleHapticFeedback(bool enabled) async {
    final base = state.settings ?? AppSettings.defaults();
    final updated = base.copyWith(hapticFeedbackEnabled: enabled);
    await _persistAndEmit(updated);
  }

  /// Updates the display font size.
  Future<void> updateFontSize(FontSize size) async {
    if (state.settings == null) return;
    final updated = state.settings!.copyWith(fontSize: size);
    await _persistAndEmit(updated);
  }

  /// Updates the UI theme mode.
  Future<void> updateThemeMode(ThemeMode mode) async {
    if (state.settings == null) return;
    final updated = state.settings!.copyWith(themeMode: mode);
    await _persistAndEmit(updated);
  }

  /// Updates the app locale.
  Future<void> updateLocale(Locale locale) async {
    if (state.settings == null) return;
    final updated = state.settings!.copyWith(locale: locale);
    await _persistAndEmit(updated);
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  Future<void> _persistAndEmit(AppSettings updated) async {
    await _updateSettings(updated);
    emit(state.copyWith(settings: updated));
  }
}

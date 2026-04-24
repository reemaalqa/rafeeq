import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/app_settings.dart';

/// Abstract contract for local settings persistence.
abstract class SettingsLocalDatasource {
  AppSettings getSettings();
  Future<void> saveSettings(AppSettings settings);
}

/// SharedPreferences-backed implementation.
/// Each field maps 1-to-1 with a [StorageKeys] constant — no magic strings.
class SettingsLocalDatasourceImpl implements SettingsLocalDatasource {
  final SharedPreferences _prefs;

  const SettingsLocalDatasourceImpl(this._prefs);

  @override
  AppSettings getSettings() {
    try {
      final themeModeStr = _prefs.getString(StorageKeys.themeMode) ?? 'light';
      final localeCode = _prefs.getString(StorageKeys.locale) ?? 'ar';
      final voiceType = _prefs.getString(StorageKeys.voiceType) ?? 'female';
      final voiceSpeed = _prefs.getDouble(StorageKeys.voiceSpeed) ?? 0.8;
      final fontSizeStr = _prefs.getString(StorageKeys.fontSize) ?? 'normal';
      final remindersEnabled = _prefs.getBool(StorageKeys.remindersEnabled) ?? true;
      final prayerTimesEnabled = _prefs.getBool(StorageKeys.prayerTimesEnabled) ?? true;
      final voiceFeedbackEnabled = _prefs.getBool(StorageKeys.voiceFeedbackEnabled) ?? true;
      final hapticFeedbackEnabled = _prefs.getBool(StorageKeys.hapticFeedbackEnabled) ?? true;

      return AppSettings(
        themeMode: _parseThemeMode(themeModeStr),
        locale: Locale(localeCode, ''),
        voiceType: voiceType,
        voiceSpeed: voiceSpeed.clamp(0.5, 1.5),
        fontSize: _parseFontSize(fontSizeStr),
        remindersEnabled: remindersEnabled,
        prayerTimesEnabled: prayerTimesEnabled,
        voiceFeedbackEnabled: voiceFeedbackEnabled,
        hapticFeedbackEnabled: hapticFeedbackEnabled,
      );
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    try {
      await Future.wait([
        _prefs.setString(StorageKeys.themeMode, _serializeThemeMode(settings.themeMode)),
        _prefs.setString(StorageKeys.locale, settings.locale.languageCode),
        _prefs.setString(StorageKeys.voiceType, settings.voiceType),
        _prefs.setDouble(StorageKeys.voiceSpeed, settings.voiceSpeed),
        _prefs.setString(StorageKeys.fontSize, _serializeFontSize(settings.fontSize)),
        _prefs.setBool(StorageKeys.remindersEnabled, settings.remindersEnabled),
        _prefs.setBool(StorageKeys.prayerTimesEnabled, settings.prayerTimesEnabled),
        _prefs.setBool(StorageKeys.voiceFeedbackEnabled, settings.voiceFeedbackEnabled),
        _prefs.setBool(StorageKeys.hapticFeedbackEnabled, settings.hapticFeedbackEnabled),
      ]);
    } catch (_) {
      throw CacheException(message: 'Failed to save settings');
    }
  }

  // ── Serialisation Helpers ─────────────────────────────────────────────────

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }

  FontSize _parseFontSize(String value) {
    switch (value) {
      case 'extraLarge':
        return FontSize.extraLarge;
      case 'large':
        return FontSize.large;
      default:
        return FontSize.normal;
    }
  }

  String _serializeFontSize(FontSize size) {
    switch (size) {
      case FontSize.extraLarge:
        return 'extraLarge';
      case FontSize.normal:
        return 'normal';
      case FontSize.large:
        return 'large';
    }
  }
}

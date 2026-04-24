import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';
import '../datasources/settings_remote_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDatasource _local;
  final SettingsRemoteDataSource _remote;

  const SettingsRepositoryImpl(this._local, this._remote);

  @override
  Future<Either<Failure, AppSettings>> getSettings() async {
    AppSettings settings;
    try {
      settings = _local.getSettings();
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (_) {
      settings = AppSettings.defaults();
    }

    // Enrich from backend user preferences (best-effort)
    try {
      final prefs = await _remote.getUserPreferences();
      final langCode  = prefs['language_code'] as String?;
      final voiceType = prefs['voice_type']    as String?;
      final theme     = prefs['theme']         as String?;

      settings = settings.copyWith(
        locale:    langCode  != null ? Locale(langCode)  : null,
        voiceType: voiceType,
        themeMode: theme == 'dark' ? ThemeMode.dark : null,
      );
    } catch (_) {
      // not critical — use local settings as-is
    }

    return Right(settings);
  }

  @override
  Future<Either<Failure, void>> saveSettings(AppSettings settings) async {
    // Always save device settings locally first
    try {
      await _local.saveSettings(settings);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (_) {
      return const Left(CacheFailure('Failed to save settings'));
    }

    // Sync to backend user preferences (best-effort)
    try {
      await _remote.updateUserPreferences({
        'voice_type':               settings.voiceType,
        'language_code':            settings.locale.languageCode,
        'theme':                    settings.themeMode == ThemeMode.dark ? 'dark' : 'light',
        'font_size':                _fontSizeToString(settings.fontSize),
        'enable_prayer_reminders':  settings.prayerTimesEnabled,
        'enable_voice_feedback':    settings.voiceFeedbackEnabled,
        'enable_haptic_feedback':   settings.hapticFeedbackEnabled,
      });
    } catch (_) {
      // best-effort — local save succeeded, report success
    }

    return const Right(null);
  }

  String _fontSizeToString(FontSize size) {
    switch (size) {
      case FontSize.normal:     return 'normal';
      case FontSize.large:      return 'large';
      case FontSize.extraLarge: return 'extra_large';
    }
  }
}

import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide RepeatInterval;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../constants/storage_keys.dart';
import '../../features/reminders/domain/entities/reminder.dart';

/// Centralised wrapper around flutter_local_notifications.
///
/// Uses a dedicated alarm channel (`alarms_v1`) that plays the device's
/// system alarm ringtone, wakes the screen via a full-screen intent, and
/// uses Importance.max so Android cannot suppress the alert.
class NotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin;

  NotificationScheduler(this._plugin);

  // ── Outcome constants ────────────────────────────────────────────────────
  static const int outcomeScheduledExact = 0;
  static const int outcomeScheduledInexact = 1;
  static const int outcomeDisabledInSettings = 2;
  static const int outcomeTimeInPast = 3;
  static const int outcomePermissionDenied = 4;
  static const int outcomeError = 5;

  // ── Channel IDs ──────────────────────────────────────────────────────────

  /// Primary alarm channel — uses the device alarm ringtone.
  /// Channel ID intentionally versioned so any existing channel (created
  /// without sound) is bypassed; Android ignores attempts to update a
  /// channel after first creation.
  static const String _alarmChannelId = 'alarms_v1';

  /// Prayer-time channel — lower priority, normal notification sound.
  static const String _prayerChannelId = 'prayer_channel';

  // ── Channel definitions (register once at app start) ────────────────────

  static const alarmChannel = AndroidNotificationChannel(
    _alarmChannelId,
    'منبهات رفيق',
    description: 'تنبيهات الأدوية والتذكيرات — تُشغَّل بصوت المنبه',
    importance: Importance.max,
    // Uses the device's default alarm ringtone (system URI — no extra file needed).
    sound: UriAndroidNotificationSound(
        'content://settings/system/alarm_alert'),
    enableVibration: true,
    enableLights: true,
    playSound: true,
  );

  static const prayerChannel = AndroidNotificationChannel(
    _prayerChannelId,
    'أوقات الصلاة',
    description: 'إشعارات أوقات الصلاة الخمسة',
    importance: Importance.high,
    playSound: true,
  );

  // ── Core scheduling ──────────────────────────────────────────────────────

  Future<int> scheduleReminder(Reminder reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(StorageKeys.remindersEnabled) ?? true;
      if (!enabled) {
        developer.log('skipping — reminders disabled in Settings',
            name: 'NotificationScheduler');
        return outcomeDisabledInSettings;
      }

      final scheduledTz =
          tz.TZDateTime.from(reminder.scheduledTime, tz.local);
      final nowTz = tz.TZDateTime.now(tz.local);

      if (scheduledTz.isBefore(nowTz) &&
          reminder.repeat == RepeatInterval.none) {
        developer.log(
          'skipping — time already in the past '
          '(scheduled=$scheduledTz, now=$nowTz)',
          name: 'NotificationScheduler',
        );
        return outcomeTimeInPast;
      }

      final DateTimeComponents? matchComponents;
      switch (reminder.repeat) {
        case RepeatInterval.daily:
          matchComponents = DateTimeComponents.time;
          break;
        case RepeatInterval.weekly:
          matchComponents = DateTimeComponents.dayOfWeekAndTime;
          break;
        case RepeatInterval.none:
        default:
          matchComponents = null;
          break;
      }

      // Prayer uses a softer channel; everything else uses the alarm channel.
      final bool isPrayer = reminder.type == ReminderType.prayer;
      final channelId = isPrayer ? _prayerChannelId : _alarmChannelId;
      final channelName = isPrayer ? 'أوقات الصلاة' : 'منبهات رفيق';

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        // Full-screen intent wakes the screen (works through DND on Android 10+).
        // Paired with USE_FULL_SCREEN_INTENT in the manifest.
        fullScreenIntent: !isPrayer,
        category: isPrayer
            ? AndroidNotificationCategory.reminder
            : AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        // Alarm channel uses the URI sound defined on the channel itself.
        // Passing it here too covers devices that read from the notification
        // object directly instead of from the channel settings.
        sound: isPrayer
            ? null
            : const UriAndroidNotificationSound(
                'content://settings/system/alarm_alert'),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      final body = reminder.description.isNotEmpty
          ? reminder.description
          : 'حان وقت تذكيرك';

      developer.log(
        'scheduling reminder id=${reminder.id} '
        'title="${reminder.title}" at $scheduledTz '
        '(repeat=${reminder.repeat}, type=${reminder.type})',
        name: 'NotificationScheduler',
      );

      // Try exact first; on Android 12+ without SCHEDULE_EXACT_ALARM the OS
      // throws — we catch and retry with inexact so the reminder still fires
      // (potentially a few minutes late) rather than being silently dropped.
      try {
        await _plugin.zonedSchedule(
          _notificationId(reminder.id),
          reminder.title,
          body,
          scheduledTz,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
          payload: 'reminder:${reminder.id}',
        );
        developer.log('scheduled EXACTLY', name: 'NotificationScheduler');
        return outcomeScheduledExact;
      } on PlatformException catch (e) {
        developer.log(
          'exact-alarm rejected (${e.code}) — retrying inexact',
          name: 'NotificationScheduler',
        );
        await _plugin.zonedSchedule(
          _notificationId(reminder.id),
          reminder.title,
          body,
          scheduledTz,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
          payload: 'reminder:${reminder.id}',
        );
        developer.log('scheduled INEXACTLY', name: 'NotificationScheduler');
        return outcomeScheduledInexact;
      }
    } on PlatformException catch (e, st) {
      developer.log(
        'PlatformException during schedule: ${e.code} / ${e.message}',
        name: 'NotificationScheduler',
        error: e,
        stackTrace: st,
      );
      return outcomePermissionDenied;
    } catch (e, st) {
      developer.log(
        'unexpected scheduling error: $e',
        name: 'NotificationScheduler',
        error: e,
        stackTrace: st,
      );
      return outcomeError;
    }
  }

  Future<void> cancelReminder(String reminderId) async {
    try {
      await _plugin.cancel(_notificationId(reminderId));
    } catch (_) {/* swallow */}
  }

  Future<void> rescheduleAll(Iterable<Reminder> reminders) async {
    for (final r in reminders) {
      await scheduleReminder(r);
    }
  }

  // ── Permission helpers ───────────────────────────────────────────────────

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  Future<NotificationDiagnosis> diagnose() async {
    bool notificationsEnabled = false;
    bool exactAlarmsAllowed = false;
    int pendingCount = 0;

    try {
      pendingCount = (await _plugin.pendingNotificationRequests()).length;
    } catch (_) {/* ignore */}

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      try {
        notificationsEnabled =
            (await android?.areNotificationsEnabled()) ?? false;
      } catch (_) {/* ignore */}
      try {
        exactAlarmsAllowed =
            (await android?.canScheduleExactNotifications()) ?? false;
      } catch (_) {/* ignore */}
    } else if (Platform.isIOS) {
      notificationsEnabled = true;
      exactAlarmsAllowed = true;
    }

    final prefs = await SharedPreferences.getInstance();
    final toggledOn = prefs.getBool(StorageKeys.remindersEnabled) ?? true;

    return NotificationDiagnosis(
      notificationsEnabled: notificationsEnabled,
      exactAlarmsAllowed: exactAlarmsAllowed,
      appTogglerOn: toggledOn,
      pendingCount: pendingCount,
    );
  }

  Future<bool> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final info = await PackageInfo.fromPlatform();
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data: 'package:${info.packageName}',
      );
      await intent.launch();
      return true;
    } catch (_) {
      try {
        final info = await PackageInfo.fromPlatform();
        await AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:${info.packageName}',
        ).launch();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<bool> openNotificationSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final info = await PackageInfo.fromPlatform();
      await AndroidIntent(
        action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        arguments: <String, dynamic>{
          'android.provider.extra.APP_PACKAGE': info.packageName,
        },
      ).launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> forceEnableReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.remindersEnabled, true);
    developer.log(
      'remindersEnabled forcibly set to true',
      name: 'NotificationScheduler',
    );
  }

  Future<bool> rawRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.remindersEnabled) ?? true;
  }

  Future<bool> openBatteryOptimisationSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      await const AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      ).launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> showTestNow({
    String title = 'اختبار التنبيهات',
    String body = 'التنبيهات تعمل ✓',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      'منبهات رفيق',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      sound: const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert'),
    );
    await _plugin.show(
      999999,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  static int _notificationId(String reminderId) =>
      reminderId.hashCode.abs() % 2147483647;
}

// ── Diagnosis snapshot ───────────────────────────────────────────────────────

class NotificationDiagnosis {
  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final bool appTogglerOn;
  final int pendingCount;

  const NotificationDiagnosis({
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.appTogglerOn,
    required this.pendingCount,
  });

  bool get allHealthy =>
      notificationsEnabled && exactAlarmsAllowed && appTogglerOn;
}

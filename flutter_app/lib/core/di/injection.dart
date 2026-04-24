import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../firebase/firebase_helpers.dart';
import '../services/alarm_service.dart';
import '../services/google_tts_service.dart';
import '../services/notification_scheduler.dart';
import '../services/system_tts_service.dart';
import '../services/tts_service.dart';

// ── Auth ──────────────────────────────────────────────────────────────────────
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/check_auth_status.dart';
import '../../features/auth/domain/usecases/logout_use_case.dart';
import '../../features/auth/domain/usecases/send_verification_code.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';

// ── Conversation ──────────────────────────────────────────────────────────────
import '../../features/conversation/data/datasources/conversation_remote_datasource.dart';
import '../../features/conversation/data/datasources/rafeeq_ai_api_client.dart';
import '../../features/conversation/domain/services/intent_detector.dart';
import '../../features/conversation/domain/services/voice_flow_manager.dart';
import '../../features/conversation/presentation/cubit/conversation_cubit.dart';

// ── Diet ──────────────────────────────────────────────────────────────────────
import '../../features/diet/data/datasources/diet_local_datasource.dart';
import '../../features/diet/data/datasources/diet_remote_datasource.dart';
import '../../features/diet/data/repositories/diet_repository_impl.dart';
import '../../features/diet/domain/repositories/diet_repository.dart';
import '../../features/diet/domain/usecases/calculate_bmi.dart';
import '../../features/diet/domain/usecases/get_diet_plan.dart';
import '../../features/diet/domain/usecases/get_food_preferences.dart';
import '../../features/diet/domain/usecases/update_food_preference.dart';
import '../../features/diet/presentation/cubit/diet_cubit.dart';

// ── Emergency ─────────────────────────────────────────────────────────────────
import '../../features/emergency/data/datasources/emergency_local_datasource.dart';
import '../../features/emergency/data/datasources/emergency_remote_datasource.dart';
import '../../features/emergency/data/repositories/emergency_repository_impl.dart';
import '../../features/emergency/domain/repositories/emergency_repository.dart';
import '../../features/emergency/domain/usecases/get_emergency_contacts.dart';
import '../../features/emergency/domain/usecases/add_emergency_contact.dart';
import '../../features/emergency/domain/usecases/delete_emergency_contact.dart';
import '../../features/emergency/domain/usecases/send_emergency_sms.dart';
import '../../features/emergency/domain/usecases/trigger_emergency_call.dart';
import '../../features/emergency/presentation/cubit/emergency_cubit.dart';

// ── Islamic ───────────────────────────────────────────────────────────────────
import '../../features/islamic/data/datasources/islamic_local_datasource.dart';
import '../../features/islamic/data/datasources/islamic_remote_datasource.dart';
import '../../features/islamic/data/repositories/islamic_repository_impl.dart';
import '../../features/islamic/domain/repositories/islamic_repository.dart';
import '../../features/islamic/domain/usecases/calculate_prayer_times.dart';
import '../../features/islamic/domain/usecases/get_advice_list.dart';
import '../../features/islamic/domain/usecases/get_daily_advice.dart';
import '../../features/islamic/domain/usecases/get_surahs.dart';
import '../../features/islamic/presentation/cubit/islamic_cubit.dart';

// ── Locations ─────────────────────────────────────────────────────────────────
import '../../features/locations/data/datasources/locations_local_datasource.dart';
import '../../features/locations/data/datasources/locations_remote_datasource.dart';
import '../../features/locations/data/repositories/locations_repository_impl.dart';
import '../../features/locations/domain/repositories/locations_repository.dart';
import '../../features/locations/domain/usecases/get_current_location.dart';
import '../../features/locations/domain/usecases/get_places_by_category.dart';
import '../../features/locations/domain/usecases/launch_directions.dart';
import '../../features/locations/presentation/cubit/locations_cubit.dart';

// ── Profile ───────────────────────────────────────────────────────────────────
import '../../features/profile/data/datasources/profile_local_datasource.dart';
import '../../features/profile/data/datasources/profile_remote_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/get_profile.dart';
import '../../features/profile/domain/usecases/save_profile.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';

// ── Reminders ─────────────────────────────────────────────────────────────────
import '../../features/reminders/data/datasources/reminder_local_datasource.dart';
import '../../features/reminders/data/datasources/reminder_remote_datasource.dart';
import '../../features/reminders/data/repositories/reminder_repository_impl.dart';
import '../../features/reminders/domain/repositories/reminder_repository.dart';
import '../../features/reminders/domain/usecases/add_reminder.dart';
import '../../features/reminders/domain/usecases/delete_reminder.dart';
import '../../features/reminders/domain/usecases/get_reminders.dart';
import '../../features/reminders/domain/usecases/snooze_reminder.dart';
import '../../features/reminders/presentation/cubit/reminder_cubit.dart';

// ── Settings ──────────────────────────────────────────────────────────────────
import '../../features/settings/data/datasources/settings_local_datasource.dart';
import '../../features/settings/data/datasources/settings_remote_datasource.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/get_settings.dart';
import '../../features/settings/domain/usecases/update_settings.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ============================================================================
  // 1. External Dependencies
  // ============================================================================

  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  // Firebase singletons
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<FirebaseHelpers>(
    () => FirebaseHelpers(firestore: sl(), auth: sl()),
  );

  // Timezone — must be initialised before scheduling any notifications.
  // We use the device's UTC offset to pick the closest IANA location from the
  // bundled database (no native plugin required).
  tz.initializeTimeZones();
  try {
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    // Walk the database and keep the first location whose current offset matches.
    // Prefer well-known Gulf/Middle-East locations when the offset is +180 min (UTC+3).
    const gulfPreferred = ['Asia/Riyadh', 'Asia/Kuwait', 'Asia/Qatar', 'Asia/Bahrain'];
    tz.Location? matched;
    if (offsetMinutes == 180) {
      // Fast path: device is already on UTC+3 — use Riyadh directly.
      matched = tz.getLocation('Asia/Riyadh');
    } else {
      for (final entry in tz.timeZoneDatabase.locations.entries) {
        final tzNow = tz.TZDateTime.now(entry.value);
        if (tzNow.timeZoneOffset.inMinutes == offsetMinutes) {
          matched = entry.value;
          if (gulfPreferred.contains(entry.key)) break; // good enough
        }
      }
    }
    tz.setLocalLocation(matched ?? tz.getLocation('Asia/Riyadh'));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh')); // safe fallback
  }

  // Notifications
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await notificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );

  // Pre-create the notification channels so Android's system settings
  // exposes per-channel toggles (users can still mute prayer reminders while
  // keeping medication alerts, for example). Channels are idempotent.
  if (Platform.isAndroid) {
    final androidImpl = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // POST_NOTIFICATIONS (Android 13+) — silently returns false if denied;
    // the user will be prompted in-context when they add their first reminder.
    await androidImpl?.requestNotificationsPermission();

    const channels = [
      // Alarm channel — system alarm ringtone + full-screen wake.
      // ID is versioned (alarms_v1) so it is always created fresh;
      // Android ignores property updates on an already-registered channel.
      NotificationScheduler.alarmChannel,
      // Prayer channel — softer, no alarm ringtone.
      NotificationScheduler.prayerChannel,
      AndroidNotificationChannel(
        'fcm_channel',
        'إشعارات رفيق',
        description: 'إشعارات الخادم من تطبيق رفيق',
        importance: Importance.high,
        playSound: true,
      ),
    ];
    for (final c in channels) {
      await androidImpl?.createNotificationChannel(c);
    }
  }
  sl.registerLazySingleton<FlutterLocalNotificationsPlugin>(() => notificationsPlugin);
  sl.registerLazySingleton<NotificationScheduler>(
    () => NotificationScheduler(sl<FlutterLocalNotificationsPlugin>()),
  );
  sl.registerLazySingleton<AlarmService>(
    () => AlarmService(
      local: sl<ReminderLocalDatasource>(),
      scheduler: sl<NotificationScheduler>(),
    ),
  );

  // ── Firebase Cloud Messaging ──────────────────────────────────────────────
  final messaging = FirebaseMessaging.instance;
  // Request permission (iOS prompts; Android 13+ handled above via POST_NOTIFICATIONS)
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  // Show FCM notifications as local banners when the app is in the foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await notificationsPlugin.show(
      message.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fcm_channel',
          'إشعارات رفيق',
          channelDescription: 'إشعارات الخادم من تطبيق رفيق',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
  });
  // Persist the FCM token in Firestore so the backend can target this device
  try {
    final fcmToken = await messaging.getToken();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (fcmToken != null && currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(
            {
              'fcmToken': fcmToken,
              'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    }
    // Refresh token when it rotates
    messaging.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
            {'fcmToken': newToken, 'fcmTokenUpdatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
    });
  } catch (_) {
    // Token persistence is non-critical — app works without it
  }
  sl.registerLazySingleton<FirebaseMessaging>(() => messaging);

  // ── Firebase Analytics ────────────────────────────────────────────────────
  final analytics = FirebaseAnalytics.instance;
  sl.registerLazySingleton<FirebaseAnalytics>(() => analytics);

  sl.registerLazySingleton<FlutterTts>(() => FlutterTts());
  sl.registerLazySingleton<SystemTtsService>(
    () => SystemTtsService(sl<FlutterTts>()),
  );
  sl.registerLazySingleton<TtsService>(
    () => GoogleTtsService(sl<SystemTtsService>()),
  );
  sl.registerLazySingleton<stt.SpeechToText>(() => stt.SpeechToText());

  // ============================================================================
  // 2. Core Services
  // ============================================================================

  sl.registerLazySingleton<IntentDetector>(() => IntentDetector());
  sl.registerLazySingleton<VoiceFlowManager>(() => VoiceFlowManager());
  sl.registerLazySingleton<RafeeqAiApiClient>(() => RafeeqAiApiClient());

  // ============================================================================
  // 3. Feature Datasources
  // ============================================================================

  // Auth — local for token cache, remote for API calls
  sl.registerLazySingleton<AuthLocalDatasource>(
    () => AuthLocalDatasourceImpl(secureStorage: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(storage: sl(), prefs: sl(), notifications: sl(), auth: sl(), firestore: sl()),
  );

  // Emergency
  sl.registerLazySingleton<EmergencyLocalDatasource>(() => EmergencyLocalDatasourceImpl(sl()));
  sl.registerLazySingleton<EmergencyRemoteDataSource>(
    () => EmergencyRemoteDataSourceImpl(fb: sl()),
  );

  // Reminders
  sl.registerLazySingleton<ReminderLocalDatasource>(() => ReminderLocalDatasourceImpl(sl()));
  sl.registerLazySingleton<ReminderRemoteDataSource>(
    () => ReminderRemoteDataSourceImpl(fb: sl()),
  );

  // Profile
  sl.registerLazySingleton<ProfileLocalDatasource>(() => ProfileLocalDatasourceImpl(sl()));
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(fb: sl()),
  );

  // Islamic
  sl.registerLazySingleton<IslamicLocalDatasource>(() => IslamicLocalDatasourceImpl());
  sl.registerLazySingleton<IslamicRemoteDataSource>(
    () => IslamicRemoteDataSourceImpl(fb: sl()),
  );

  // Diet
  sl.registerLazySingleton<DietLocalDatasource>(() => DietLocalDatasourceImpl(sl()));
  sl.registerLazySingleton<DietRemoteDataSource>(
    () => DietRemoteDataSourceImpl(fb: sl()),
  );

  // Settings
  sl.registerLazySingleton<SettingsLocalDatasource>(() => SettingsLocalDatasourceImpl(sl()));
  sl.registerLazySingleton<SettingsRemoteDataSource>(
    () => SettingsRemoteDataSourceImpl(fb: sl()),
  );

  // Locations
  sl.registerLazySingleton<LocationsLocalDatasource>(() => const LocationsLocalDatasourceImpl());
  sl.registerLazySingleton<LocationsRemoteDataSource>(
    () => LocationsRemoteDataSourceImpl(fb: sl()),
  );

  // Conversation
  sl.registerLazySingleton<ConversationRemoteDataSource>(
    () => ConversationRemoteDataSourceImpl(fb: sl()),
  );

  // ============================================================================
  // 4. Feature Repositories
  // ============================================================================

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remote: sl(), local: sl(), storage: sl()),
  );

  sl.registerLazySingleton<EmergencyRepository>(
    () => EmergencyRepositoryImpl(sl(), sl(), sl()),
  );

  sl.registerLazySingleton<ReminderRepository>(
    () => ReminderRepositoryImpl(sl(), sl()),
  );

  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl(), sl(), sl()),
  );

  sl.registerLazySingleton<IslamicRepository>(
    () => IslamicRepositoryImpl(sl(), sl(), sl()),
  );

  sl.registerLazySingleton<DietRepository>(
    () => DietRepositoryImpl(sl(), sl()),
  );

  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(sl(), sl()),
  );

  sl.registerLazySingleton<LocationsRepository>(
    () => LocationsRepositoryImpl(sl(), sl()),
  );

  // ============================================================================
  // 5. Feature Use Cases
  // ============================================================================

  sl.registerFactory(() => SendVerificationCode(sl()));
  sl.registerFactory(() => VerifyOtp(sl()));
  sl.registerFactory(() => LogoutUseCase(sl()));
  sl.registerFactory(() => CheckAuthStatus(sl()));

  sl.registerFactory(() => GetEmergencyContacts(sl()));
  sl.registerFactory(() => AddEmergencyContact(sl()));
  sl.registerFactory(() => DeleteEmergencyContact(sl()));
  sl.registerFactory(() => TriggerEmergencyCall(sl()));
  sl.registerFactory(() => SendEmergencySms(sl()));

  sl.registerFactory(() => GetReminders(sl()));
  sl.registerFactory(() => AddReminder(sl()));
  sl.registerFactory(() => DeleteReminder(sl()));
  sl.registerFactory(() => SnoozeReminder(sl()));

  sl.registerFactory(() => GetProfile(sl()));
  sl.registerFactory(() => SaveProfile(sl()));

  sl.registerFactory(() => GetSurahs(sl()));
  sl.registerFactory(() => GetDailyAdvice(sl()));
  sl.registerFactory(() => GetAdviceList(sl()));
  sl.registerFactory(() => CalculatePrayerTimes(sl()));

  sl.registerFactory(() => CalculateBmi(sl()));
  sl.registerFactory(() => GetDietPlan(sl()));
  sl.registerFactory(() => GetFoodPreferences(sl()));
  sl.registerFactory(() => UpdateFoodPreference(sl()));

  sl.registerFactory(() => GetSettings(sl()));
  sl.registerFactory(() => UpdateSettings(sl()));

  sl.registerFactory(() => GetPlacesByCategory(sl()));
  sl.registerFactory(() => GetCurrentLocation(sl()));
  sl.registerFactory(() => const LaunchDirections());

  // ============================================================================
  // 6. Feature Cubits
  // ============================================================================

  sl.registerFactory(
    () => AuthCubit(sendCode: sl(), verifyOtp: sl(), logout: sl(), checkAuth: sl()),
  );

  sl.registerFactory(
    () => EmergencyCubit(getContacts: sl(), addContact: sl(), deleteContact: sl(), triggerCall: sl(), sendSms: sl(), tts: sl<TtsService>()),
  );

  sl.registerFactory(
    () => ReminderCubit(
      alarmService: sl(),
      deleteReminder: sl(),
    ),
  );

  sl.registerFactory(
    () => ProfileCubit(getProfile: sl(), saveProfile: sl(), addContact: sl(), deleteContact: sl()),
  );

  sl.registerFactory(
    () => IslamicCubit(getSurahs: sl(), getDailyAdvice: sl(), calculatePrayerTimes: sl(), tts: sl<TtsService>(), notifications: sl()),
  );

  sl.registerFactory(
    () => DietCubit(
      calculateBmi: sl(),
      getDietPlan: sl(),
      getPreferences: sl(),
      updatePreference: sl(),
    ),
  );

  sl.registerFactory(
    () => ConversationCubit(
      intentDetector: sl(),
      rafeeqApi: sl(),
      tts: sl<TtsService>(),
      speech: sl(),
      flowManager: sl(),
      remoteDs: sl(),
      calculatePrayerTimes: sl(),
      getDailyAdvice: sl(),
      getSurahs: sl(),
      getDietPlan: sl(),
      getPlaces: sl(),
      getCurrentLocation: sl(),
    ),
  );

  sl.registerFactory(
    () => SettingsCubit(getSettings: sl(), updateSettings: sl(), tts: sl<TtsService>()),
  );

  sl.registerFactory(
    () => LocationsCubit(getPlaces: sl(), getCurrentLocation: sl(), launchDirections: sl()),
  );

  // ============================================================================
  // 7. Apply persisted voice gender to TTS at startup
  // ============================================================================
  final voiceType = sharedPreferences.getString('voice_type') ?? 'female';
  final startupPitch = voiceType == 'female' ? 1.35 : 0.85;
  // Configure both the cloud service and the device fallback.
  await sl<TtsService>().setPitch(startupPitch);

  // ============================================================================
  // 8. Select best available Arabic voice on the device (used as fallback when
  //    the Google Cloud TTS service is offline or no API key is configured).
  // ============================================================================
  await _initArabicTts(sl<FlutterTts>());
}

/// Configures [tts] to use the highest-quality Arabic voice available on the
/// device without any cloud dependency.
///
/// On Android, Google TTS ships enhanced neural Arabic voices whose compact
/// names follow the pattern `ar-sa-x-<variant>-<quality>`. We probe the list
/// returned by [FlutterTts.getVoices] and rank candidates by quality heuristics
/// — preferring neural/network voices, Saudi locale, and female variants that
/// test better with elderly listeners in user feedback.
Future<void> _initArabicTts(FlutterTts tts) async {
  // Point Android to the Google TTS engine which has the best Arabic support.
  // Google TTS ships high-quality neural Arabic voices on all modern Android
  // devices — if it's missing we fall back to whatever engine is default.
  if (Platform.isAndroid) {
    try {
      await tts.setEngine('com.google.android.tts');
    } catch (_) {
      // Device may not have Google TTS installed — keep the default engine.
    }
  }

  await tts.setLanguage('ar-SA');
  // Slightly slower than default for elderly listeners but not slow enough
  // to sound unnatural. Users can still override via the settings slider.
  await tts.setSpeechRate(0.45);
  await tts.setVolume(1.0);

  // Ranked voice IDs — highest quality first. We look for exact matches, then
  // fall back to scored heuristic matching so the app still picks a decent
  // voice on devices that expose different voice IDs (Samsung/Huawei OEM TTS).
  const preferredVoices = [
    // Google neural (network) — studio-quality Saudi female.
    'ar-xa-x-arz-network',
    'ar-sa-x-sfr-network',
    'ar-sa-x-arb-network',
    // Google neural (local) — same quality offline.
    'ar-sa-x-sfr-local',
    'ar-sa-x-arb-local',
    // Legacy Google TTS compact voices.
    'ar-sa-x-sfr-f00-network',
    'ar-sa-x-sfr-f00-local',
  ];

  try {
    final dynamic raw = await tts.getVoices;
    if (raw == null) return;

    final voices = (raw as List).cast<Map<dynamic, dynamic>>();

    // Keep only Arabic voices so we never accidentally pick an English voice
    // on devices with limited Arabic support.
    final arabicVoices = voices.where((v) {
      final locale = (v['locale'] as String? ?? '').toLowerCase();
      return locale.startsWith('ar');
    }).toList();

    if (arabicVoices.isEmpty) return;

    // 1) Try explicit preferred voices in order.
    for (final preferred in preferredVoices) {
      final match = arabicVoices.where(
        (v) => (v['name'] as String? ?? '').toLowerCase() == preferred,
      );
      if (match.isNotEmpty) {
        final name = match.first['name'] as String;
        final locale = match.first['locale'] as String? ?? 'ar-SA';
        await tts.setVoice({'name': name, 'locale': locale});
        return;
      }
    }

    // 2) Heuristic scoring — give points for Saudi locale, neural quality,
    //    female gender, and network variants. Pick the highest scorer.
    int score(Map<dynamic, dynamic> v) {
      final name = (v['name'] as String? ?? '').toLowerCase();
      final locale = (v['locale'] as String? ?? '').toLowerCase();
      var s = 0;
      if (locale == 'ar-sa') s += 20;
      else if (locale.startsWith('ar-')) s += 10;
      if (name.contains('network')) s += 12; // neural = highest quality
      if (name.contains('wavenet')) s += 12;
      if (name.contains('neural')) s += 12;
      if (name.contains('local')) s += 6;    // offline neural
      if (name.contains('-f')) s += 3;       // female variants
      if (name.contains('enhanced')) s += 5;
      return s;
    }
    arabicVoices.sort((a, b) => score(b).compareTo(score(a)));
    final best = arabicVoices.first;
    final bestName = best['name'] as String? ?? '';
    final bestLocale = best['locale'] as String? ?? 'ar-SA';
    if (bestName.isNotEmpty) {
      await tts.setVoice({'name': bestName, 'locale': bestLocale});
    }
  } catch (_) {
    // Voice enumeration failed — language-only setting is sufficient fallback.
  }
}

/// Central registry for all SharedPreferences and SecureStorage keys.
/// Never use raw string literals in datasources — always reference this class.
abstract class StorageKeys {
  StorageKeys._();

  // ── Auth ────────────────────────────────────────────────────────────────────
  static const String authToken = 'auth_token';       // kept for legacy reads
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String isLoggedIn = 'is_logged_in';

  // ── User Profile ─────────────────────────────────────────────────────────────
  static const String userProfile = 'user_profile';
  static const String userName = 'user_name';
  static const String userAge = 'user_age';
  static const String userSex = 'user_sex';
  static const String userHeightCm = 'user_height_cm';
  static const String userWeightKg = 'user_weight_kg';
  static const String userPreferredLanguage = 'user_preferred_language';
  static const String userVoiceType = 'user_voice_type';
  static const String userAllergies = 'user_allergies';

  // ── Emergency ────────────────────────────────────────────────────────────────
  static const String emergencyContacts = 'emergency_contacts';

  // ── Reminders ────────────────────────────────────────────────────────────────
  static const String reminders = 'reminders';

  // ── Diet ─────────────────────────────────────────────────────────────────────
  static const String foodPreferences = 'food_preferences';
  static const String dislikedFoods = 'disliked_foods';

  // ── AI Response Preferences (from 3-question onboarding) ───────────────────
  static const String aiReplyLength = 'ai_reply_length';           // short|long
  static const String aiExplanationStyle = 'ai_explanation_style'; // simple|detailed
  static const String aiWantsExamples = 'ai_wants_examples';       // bool
  static const String aiDialect = 'ai_dialect';                    // najdi|janoubi|shamali|sharqawi
  static const String preferencesOnboarded = 'preferences_onboarded';

  // ── Settings ─────────────────────────────────────────────────────────────────
  static const String themeMode = 'theme_mode';
  static const String locale = 'locale';
  static const String voiceType = 'voice_type';
  static const String voiceSpeed = 'voice_speed';
  static const String fontSize = 'font_size';
  static const String remindersEnabled = 'reminders_enabled';
  static const String prayerTimesEnabled = 'prayer_times_enabled';
  static const String voiceFeedbackEnabled = 'voice_feedback_enabled';
  static const String hapticFeedbackEnabled = 'haptic_feedback_enabled';

  // ── Onboarding ───────────────────────────────────────────────────────────────
  static const String hasSeenOnboarding = 'has_seen_onboarding';

  // ── Islamic advice voice rotation ────────────────────────────────────────
  /// Rolling index into the advice catalog — advances by 1 every time the
  /// voice assistant answers a "نصيحة" request so the user doesn't hear the
  /// same hadith/dua/ayah repeatedly.
  static const String adviceVoiceCursor = 'advice_voice_cursor';

  // ── Diet plan voice rotation ─────────────────────────────────────────────
  /// Rolling index into the meal catalog — advances each time the voice
  /// assistant answers an "أكل" request so consecutive queries return
  /// different breakfast/lunch/dinner options instead of the same meal.
  static const String dietVoiceCursor = 'diet_voice_cursor';

  // ── Prayer Times Cache ───────────────────────────────────────────────────────
  static const String prayerTimesCache = 'prayer_times_cache';
  static const String prayerTimesCacheDate = 'prayer_times_cache_date';
  static const String lastKnownLatitude = 'last_known_latitude';
  static const String lastKnownLongitude = 'last_known_longitude';
}

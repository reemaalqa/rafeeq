class ApiConstants {
  ApiConstants._();

  // Base
  static const String apiVersion = '/api/v1';

  // Auth Endpoints
  static const String sendVerificationCode = '$apiVersion/auth/send-code';
  static const String verifyCode = '$apiVersion/auth/verify-code';
  static const String logout = '$apiVersion/auth/logout';
  static const String refreshToken = '$apiVersion/auth/refresh';

  // User Endpoints
  static const String userProfile = '$apiVersion/users/profile';
  static const String updateProfile = '$apiVersion/users/profile';
  static const String userPreferences = '$apiVersion/users/preferences';
  static const String updatePreferences = '$apiVersion/users/preferences';

  // Health Endpoints
  static const String medicalConditions = '$apiVersion/health/conditions';
  static const String userConditions = '$apiVersion/health/user-conditions';
  static const String allergies = '$apiVersion/health/allergies';
  static const String userAllergies = '$apiVersion/health/user-allergies';

  // Emergency Endpoints
  static const String emergencyContacts = '$apiVersion/emergency/contacts';
  static const String triggerEmergency = '$apiVersion/emergency/trigger';
  static const String emergencyEvents = '$apiVersion/emergency/events';

  // Reminders Endpoints
  static const String reminders = '$apiVersion/reminders';
  static const String reminderCategories = '$apiVersion/reminders/categories';
  static const String medicationReminders = '$apiVersion/reminders/medications';
  static const String appointmentReminders = '$apiVersion/reminders/appointments';
  static const String reminderLogs = '$apiVersion/reminders/logs';

  // Conversation Sessions / Messages (sub-paths)
  static const String conversationSessionEnd = '$apiVersion/conversations/sessions'; // + /{id}/end

  // Diet Endpoints
  static const String foodItems = '$apiVersion/diet/foods';
  static const String dietPlans = '$apiVersion/diet/plans';
  static const String mealPlans = '$apiVersion/diet/meals';
  static const String dietSuggestions = '$apiVersion/diet/suggestions';
  static const String foodPreferences = '$apiVersion/diet/preferences';

  // Islamic Endpoints
  static const String prayerTimes = '$apiVersion/islamic/prayer-times';
  static const String quranRecitations = '$apiVersion/islamic/quran';
  static const String islamicContent = '$apiVersion/islamic/content';

  // Location Endpoints
  static const String savedLocations = '$apiVersion/locations';
  static const String nearbyPlaces = '$apiVersion/locations/nearby';

  // Conversation Endpoints
  static const String conversationSessions = '$apiVersion/conversations/sessions';
  static const String conversationMessages = '$apiVersion/conversations/messages';
  static const String voiceCommand = '$apiVersion/conversations/voice-command';

  // System Endpoints
  static const String translations = '$apiVersion/system/translations';
  static const String configs = '$apiVersion/system/configs';
  static const String appVersion = '$apiVersion/system/version';
}

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Rafeeq';
  static const String appVersion = '1.0.0';

  // API Configuration
  // Development: use 'http://10.0.2.2:8000' for Android emulator,
  //              use 'http://localhost:8000' for iOS simulator / web
  // Production:  use 'https://api.rafeeq.app'
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://192.168.1.107:8000',
  );
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyLanguage = 'language';
  static const String keyTheme = 'theme';
  static const String keyVoiceType = 'voice_type';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Gemini AI
  // Replace with your key from aistudio.google.com, or pass via
  // --dart-define=GEMINI_API_KEY=your_key
  static const String geminiApiKey = String.fromEnvironment(
    'AIzaSyDJIQNfiZ_XWWGrzVBtmzEg20EHMIfD_Mo',
    defaultValue: 'AIzaSyDJIQNfiZ_XWWGrzVBtmzEg20EHMIfD_Mo',
  );

  // Google Cloud Text-to-Speech
  // Enable "Cloud Text-to-Speech API" in the GCP console, generate an API key,
  // then pass it at build time: --dart-define=GOOGLE_TTS_API_KEY=your_key
  // When empty the app falls back to the device's built-in TTS engine.
  static const String googleTtsApiKey = String.fromEnvironment(
    'GOOGLE_TTS_API_KEY',
    defaultValue: '',
  );

  // Voice
  static const String wakeWord = 'rafeeq';
  static const Duration voiceTimeout = Duration(seconds: 5);
  static const Duration silenceThreshold = Duration(seconds: 2);

  // Emergency
  static const List<String> emergencyPhrases = [
    'مساعدة',
    'طوارئ',
    'سقطت',
    'ألم',
    'لا أستطيع التنفس',
    'نجدة',
    'استغاثة',
    'وقعت',
  ];

  // Reminders
  static const int defaultSnoozeMinutes = 10;
  static const int maxRemindersPerDay = 20;

  // Location
  static const double defaultLocationAccuracy = 100.0;
  static const Duration locationTimeout = Duration(seconds: 10);

  // UI
  static const double minTouchTarget = 48.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration debounceDelay = Duration(milliseconds: 500);

  // Accessibility
  static const double minFontSize = 16.0;
  static const double maxFontSize = 32.0;
  static const double minContrastRatio = 4.5;
}

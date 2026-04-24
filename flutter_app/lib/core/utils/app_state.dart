import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_keys.dart';

/// Text scale options for the app. "small" keeps the theme's default sizes,
/// "large" bumps everything ~35% for users who want bigger text.
enum AppFontSize { small, large }

class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  /// Always Arabic — language toggle removed.
  final Locale locale = const Locale('ar', '');
  bool _isLoggedIn = false;
  String _userName = '';
  String _userAge = '';
  double? _heightCm;
  double? _weightKg;
  bool _hasSeenOnboarding = false;
  AppFontSize _fontSize = AppFontSize.large;

  ThemeMode get themeMode => _themeMode;
  bool get isLoggedIn => _isLoggedIn;
  String get userName => _userName;
  String get userAge => _userAge;
  double? get heightCm => _heightCm;
  double? get weightKg => _weightKg;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  AppFontSize get fontSize => _fontSize;
  double get textScaleFactor => _fontSize == AppFontSize.small ? 1.0 : 1.35;

  AppState() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(StorageKeys.themeMode) ?? 'light';
    _themeMode = themeModeString == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _isLoggedIn = prefs.getBool(StorageKeys.isLoggedIn) ?? false;
    _userName = prefs.getString(StorageKeys.userName) ?? '';
    _userAge = prefs.getString(StorageKeys.userAge) ?? '';
    _heightCm = prefs.getDouble(StorageKeys.userHeightCm);
    _weightKg = prefs.getDouble(StorageKeys.userWeightKg);
    _hasSeenOnboarding = prefs.getBool(StorageKeys.hasSeenOnboarding) ?? false;
    final fontSizeStr = prefs.getString('fontSize') ?? 'large';
    _fontSize = fontSizeStr == 'small' ? AppFontSize.small : AppFontSize.large;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.themeMode, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setFontSize(AppFontSize size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontSize', size == AppFontSize.small ? 'small' : 'large');
  }

  Future<void> saveUserProfile({
    required String name,
    required String age,
    double? heightCm,
    double? weightKg,
  }) async {
    _isLoggedIn = true;
    _userName = name;
    _userAge = age;
    _heightCm = heightCm ?? _heightCm;
    _weightKg = weightKg ?? _weightKg;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.isLoggedIn, true);
    await prefs.setString(StorageKeys.userName, name);
    await prefs.setString(StorageKeys.userAge, age);
    if (_heightCm != null) await prefs.setDouble(StorageKeys.userHeightCm, _heightCm!);
    if (_weightKg != null) await prefs.setDouble(StorageKeys.userWeightKg, _weightKg!);
  }

  Future<void> markOnboardingSeen() async {
    _hasSeenOnboarding = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.hasSeenOnboarding, true);
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _userName = '';
    _userAge = '';
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.isLoggedIn, false);
    await prefs.remove(StorageKeys.userName);
    await prefs.remove(StorageKeys.userAge);
  }

  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }
}

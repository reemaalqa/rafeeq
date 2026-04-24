import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../../auth/domain/entities/auth_user.dart';

/// Abstract contract for local auth persistence operations.
abstract class AuthLocalDatasource {
  /// Persists [token] in secure storage.
  Future<void> storeToken(String token);

  /// Retrieves the stored token, or null if absent.
  Future<String?> getToken();

  /// Removes the stored token from secure storage.
  Future<void> clearToken();

  /// Persists the logged-in flag in SharedPreferences.
  Future<void> setLoggedIn(bool value);

  /// Reads the logged-in flag from SharedPreferences.
  Future<bool> isLoggedIn();

  /// Mock: saves [email] as a pending verification entry.
  Future<void> sendCode(String email);

  /// Mock: accepts any 6-digit code, stores a derived token,
  /// sets isLoggedIn = true, and returns the authenticated user.
  Future<AuthUser> verifyOtp(String email, String code);
}

/// SharedPreferences + FlutterSecureStorage backed implementation.
/// All network I/O is mocked — suitable for offline-first development.
class AuthLocalDatasourceImpl implements AuthLocalDatasource {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  const AuthLocalDatasourceImpl({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  })  : _secureStorage = secureStorage,
        _prefs = prefs;

  @override
  Future<void> storeToken(String token) async {
    try {
      await _secureStorage.write(key: StorageKeys.authToken, value: token);
    } catch (_) {
      throw CacheException(message: 'Failed to store auth token');
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: StorageKeys.authToken);
    } catch (_) {
      throw CacheException(message: 'Failed to read auth token');
    }
  }

  @override
  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: StorageKeys.authToken);
    } catch (_) {
      throw CacheException(message: 'Failed to clear auth token');
    }
  }

  @override
  Future<void> setLoggedIn(bool value) async {
    try {
      await _prefs.setBool(StorageKeys.isLoggedIn, value);
    } catch (_) {
      throw CacheException(message: 'Failed to persist login state');
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      return _prefs.getBool(StorageKeys.isLoggedIn) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> sendCode(String email) async {
    // Mock: in production this would call a backend endpoint.
    // For now we simply record that a code was requested for this email.
    try {
      await _prefs.setString('pending_verification_email', email);
    } catch (_) {
      throw CacheException(message: 'Failed to register verification request');
    }
  }

  @override
  Future<AuthUser> verifyOtp(String email, String code) async {
    // Mock: any 6-digit numeric code is accepted.
    final isValidFormat = RegExp(r'^\d{6}$').hasMatch(code);
    if (!isValidFormat) {
      throw AuthenticationException(message: 'Verification code must be 6 digits');
    }

    final token = 'mock_token_$email';
    await storeToken(token);
    await setLoggedIn(true);

    return AuthUser(email: email, token: token);
  }
}

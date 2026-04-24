import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/auth_user.dart';

/// SharedPreferences keys used only by this datasource.
const _kOtpCode    = 'otp_code';
const _kOtpExpiry  = 'otp_expiry_ms';
const _kOtpEmail   = 'otp_email';

/// OTP validity window in minutes.
const _kOtpTtlMinutes = 5;

/// Spark-plan friendly auth datasource.
///
/// `sendCode()` generates a cryptographically random 6-digit OTP, stores it
/// locally with a 5-minute expiry, and delivers it to the user as an on-device
/// notification — no email, no Cloud Functions, no Blaze plan required.
///
/// `verifyOtp()` checks the entered code against the stored OTP and rejects
/// codes that have expired or don't match.
///
/// To switch to real email OTP later, replace only `sendCode()` and
/// `verifyOtp()` with a Cloud Functions custom-token flow.
abstract class AuthRemoteDataSource {
  Future<void> sendCode(String email);
  Future<AuthUser> verifyOtp(String email, String code);
  Future<void> logout(String refreshToken);
  Future<AuthUser> refreshSession(String refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FlutterSecureStorage _storage;
  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _notifications;

  AuthRemoteDataSourceImpl({
    required FlutterSecureStorage storage,
    required SharedPreferences prefs,
    required FlutterLocalNotificationsPlugin notifications,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage,
        _prefs = prefs,
        _notifications = notifications;

  // ── OTP generation & notification ─────────────────────────────────────────

  @override
  Future<void> sendCode(String email) async {
    // Generate a 6-digit OTP using a cryptographically seeded random source.
    final otp = (Random.secure().nextInt(900000) + 100000).toString();
    final expiryMs = DateTime.now()
        .add(const Duration(minutes: _kOtpTtlMinutes))
        .millisecondsSinceEpoch;

    // Persist so verifyOtp can check it.
    await _prefs.setString(_kOtpCode, otp);
    await _prefs.setInt(_kOtpExpiry, expiryMs);
    await _prefs.setString(_kOtpEmail, email);

    // Deliver the OTP as an on-device notification.
    const androidDetails = AndroidNotificationDetails(
      'otp_channel',
      'رمز التحقق',
      channelDescription: 'رمز التحقق لتسجيل الدخول في رفيق',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      // Show the code in the notification body even on the lock screen.
      visibility: NotificationVisibility.public,
      // Keep the notification until the user dismisses it.
      autoCancel: false,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notifications.show(
      9999, // fixed id so a second "send" replaces the previous notification
      'رفيق — رمز التحقق',
      'رمز الدخول الخاص بك: $otp  (صالح لمدة $_kOtpTtlMinutes دقائق)',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  @override
  Future<AuthUser> verifyOtp(String email, String code) async {
    // ── Format check ────────────────────────────────────────────────────────
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const AuthenticationException(
        message: 'رمز التحقق يجب أن يكون 6 أرقام',
      );
    }

    // ── Retrieve stored OTP ─────────────────────────────────────────────────
    final storedCode  = _prefs.getString(_kOtpCode);
    final storedEmail = _prefs.getString(_kOtpEmail);
    final expiryMs    = _prefs.getInt(_kOtpExpiry) ?? 0;

    // Guard: no code was ever sent
    if (storedCode == null) {
      throw const AuthenticationException(
        message: 'لم يتم طلب رمز التحقق. أرسل الرمز أولاً.',
      );
    }

    // Guard: code sent to a different email
    if (storedEmail != email) {
      throw const AuthenticationException(
        message: 'البريد الإلكتروني لا يطابق طلب الرمز.',
      );
    }

    // Guard: expired
    if (DateTime.now().millisecondsSinceEpoch > expiryMs) {
      await _clearOtp();
      throw const AuthenticationException(
        message: 'انتهت صلاحية رمز التحقق. اطلب رمزاً جديداً.',
      );
    }

    // Guard: wrong code
    if (code != storedCode) {
      throw const AuthenticationException(
        message: 'رمز التحقق غير صحيح.',
      );
    }

    // ── OTP correct — sign in anonymously & stamp the user doc ──────────────
    try {
      final cred = _auth.currentUser != null
          ? UserCredentialShim(_auth.currentUser!)
          : await _auth.signInAnonymously();
      final user = cred.user;
      if (user == null) {
        throw const AuthenticationException(message: 'فشل تسجيل الدخول');
      }

      await _firestore.collection('users').doc(user.uid).set(
        {
          'email': email,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'preferencesOnboarded': FieldValue.increment(0),
        },
        SetOptions(merge: true),
      );
      final snap = await _firestore.collection('users').doc(user.uid).get();
      if (snap.data()?['preferencesOnboarded'] is! bool) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set({'preferencesOnboarded': false}, SetOptions(merge: true));
      }

      final idToken = await user.getIdToken() ?? '';
      await _storage.write(key: StorageKeys.accessToken, value: idToken);
      await _storage.write(key: StorageKeys.authToken, value: idToken);
      await _prefs.setBool(StorageKeys.isLoggedIn, true);

      // Clear OTP + dismiss the notification — no longer needed.
      await _clearOtp();

      return AuthUser(email: email, token: idToken);
    } on FirebaseAuthException catch (e) {
      throw AuthenticationException(message: e.message ?? 'فشل تسجيل الدخول');
    } on AuthenticationException {
      rethrow;
    } catch (_) {
      throw const AuthenticationException(message: 'فشل التحقق من الرمز');
    }
  }

  /// Removes the stored OTP and dismisses the notification.
  Future<void> _clearOtp() async {
    await _prefs.remove(_kOtpCode);
    await _prefs.remove(_kOtpExpiry);
    await _prefs.remove(_kOtpEmail);
    await _notifications.cancel(9999);
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Best-effort
    }
  }

  @override
  Future<AuthUser> refreshSession(String refreshToken) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthenticationException(message: 'No active session');
    }
    final idToken = await user.getIdToken(true) ?? '';
    await _storage.write(key: StorageKeys.accessToken, value: idToken);
    await _storage.write(key: StorageKeys.authToken, value: idToken);
    return AuthUser(email: user.email ?? '', token: idToken);
  }
}

/// Tiny adapter so the existing-user branch can return a [UserCredential]-like
/// object without touching the rest of the function body.
class UserCredentialShim implements UserCredential {
  @override
  final User user;
  UserCredentialShim(this.user);
  @override
  AdditionalUserInfo? get additionalUserInfo => null;
  @override
  AuthCredential? get credential => null;
}

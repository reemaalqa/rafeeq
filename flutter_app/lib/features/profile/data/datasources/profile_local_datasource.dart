import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_profile_model.dart';

abstract class ProfileLocalDatasource {
  Future<UserProfileModel?> getProfile();
  Future<void> saveProfile(UserProfileModel profile);
}

class ProfileLocalDatasourceImpl implements ProfileLocalDatasource {
  final SharedPreferences _prefs;
  const ProfileLocalDatasourceImpl(this._prefs);

  @override
  Future<UserProfileModel?> getProfile() async {
    try {
      final s = _prefs.getString(StorageKeys.userProfile);
      if (s == null || s.isEmpty) return null;
      return UserProfileModel.fromJsonString(s);
    } catch (_) {
      throw CacheException(message: 'Failed to load profile');
    }
  }

  @override
  Future<void> saveProfile(UserProfileModel profile) async {
    try {
      await _prefs.setString(StorageKeys.userProfile, profile.toJsonString());
  
      await _prefs.setString(
        StorageKeys.userAllergies,
        json.encode(profile.allergies.map((a) => a.name).toList()),
      );
  
      // Also write individual keys for AppState backward compat
      await _prefs.setString(StorageKeys.userName, profile.name);
      await _prefs.setString(StorageKeys.userAge, profile.age);
  
      if (profile.heightCm != null) {
        await _prefs.setDouble(StorageKeys.userHeightCm, profile.heightCm!);
      } else {
        await _prefs.remove(StorageKeys.userHeightCm);
      }
  
      if (profile.weightKg != null) {
        await _prefs.setDouble(StorageKeys.userWeightKg, profile.weightKg!);
      } else {
        await _prefs.remove(StorageKeys.userWeightKg);
      }
    } catch (_) {
      throw CacheException(message: 'Failed to save profile');
    }
  }

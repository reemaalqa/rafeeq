import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../models/emergency_contact_model.dart';

abstract class EmergencyLocalDatasource {
  Future<List<EmergencyContactModel>> getEmergencyContacts();
  Future<void> saveEmergencyContacts(List<EmergencyContactModel> contacts);
}

class EmergencyLocalDatasourceImpl implements EmergencyLocalDatasource {
  final SharedPreferences _prefs;

  const EmergencyLocalDatasourceImpl(this._prefs);

  @override
  Future<List<EmergencyContactModel>> getEmergencyContacts() async {
    try {
      final jsonString = _prefs.getString(StorageKeys.emergencyContacts);
      if (jsonString == null || jsonString.isEmpty) return [];
      return EmergencyContactModel.listFromJsonString(jsonString);
    } catch (_) {
      throw const CacheException(message: 'Failed to load emergency contacts');
    }
  }

  @override
  Future<void> saveEmergencyContacts(
      List<EmergencyContactModel> contacts) async {
    try {
      await _prefs.setString(
        StorageKeys.emergencyContacts,
        EmergencyContactModel.listToJsonString(contacts),
      );
    } catch (_) {
      throw const CacheException(message: 'Failed to save emergency contacts');
    }
  }
}

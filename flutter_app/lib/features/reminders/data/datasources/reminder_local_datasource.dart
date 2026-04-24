import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../models/reminder_model.dart';

abstract class ReminderLocalDatasource {
  Future<List<ReminderModel>> getReminders();
  Future<void> saveReminders(List<ReminderModel> reminders);
}

class ReminderLocalDatasourceImpl implements ReminderLocalDatasource {
  final SharedPreferences _prefs;
  const ReminderLocalDatasourceImpl(this._prefs);

  @override
  Future<List<ReminderModel>> getReminders() async {
    try {
      final s = _prefs.getString(StorageKeys.reminders);
      if (s == null || s.isEmpty) return [];
      return ReminderModel.listFromJsonString(s);
    } catch (_) {
      throw CacheException(message: 'Failed to load reminders');
    }
  }

  @override
  Future<void> saveReminders(List<ReminderModel> reminders) async {
    try {
      await _prefs.setString(StorageKeys.reminders, ReminderModel.listToJsonString(reminders));
    } catch (_) {
      throw CacheException(message: 'Failed to save reminders');
    }
  }
}

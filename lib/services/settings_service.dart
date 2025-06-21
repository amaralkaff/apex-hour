import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';

class SettingsService {
  static const String _settingsKey = 'user_settings';
  static const String _firstLaunchKey = 'first_launch';
  
  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();
  SettingsService._();

  SharedPreferences? _prefs;
  UserSettings? _cachedSettings;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<UserSettings> getSettings() async {
    await initialize();
    
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }

    final settingsJson = _prefs!.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(settingsJson);
        _cachedSettings = UserSettings.fromJson(json);
        return _cachedSettings!;
      } catch (e) {
        // If there's an error parsing, return default settings
        _cachedSettings = const UserSettings();
        return _cachedSettings!;
      }
    }

    // Return default settings if none exist
    _cachedSettings = const UserSettings();
    return _cachedSettings!;
  }

  Future<void> saveSettings(UserSettings settings) async {
    await initialize();
    
    _cachedSettings = settings;
    final settingsJson = jsonEncode(settings.toJson());
    await _prefs!.setString(_settingsKey, settingsJson);
  }

  Future<bool> isFirstLaunch() async {
    await initialize();
    return !(_prefs!.getBool(_firstLaunchKey) ?? false);
  }

  Future<void> setFirstLaunchComplete() async {
    await initialize();
    await _prefs!.setBool(_firstLaunchKey, true);
  }

  Future<void> resetSettings() async {
    await initialize();
    await _prefs!.remove(_settingsKey);
    _cachedSettings = null;
  }

  // Utility methods for common settings operations
  Future<void> updateWorkHours({
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) async {
    final currentSettings = await getSettings();
    final updatedSettings = currentSettings.copyWith(
      workdayStartHour: startHour,
      workdayStartMinute: startMinute,
      workdayEndHour: endHour,
      workdayEndMinute: endMinute,
    );
    await saveSettings(updatedSettings);
  }

  Future<void> updateApexHourDuration(int minutes) async {
    final currentSettings = await getSettings();
    final updatedSettings = currentSettings.copyWith(
      apexHourDurationMinutes: minutes,
    );
    await saveSettings(updatedSettings);
  }

  Future<void> updateNotificationSettings({
    bool? enabled,
    int? minutesBefore,
  }) async {
    final currentSettings = await getSettings();
    final updatedSettings = currentSettings.copyWith(
      notificationsEnabled: enabled,
      notificationMinutesBefore: minutesBefore,
    );
    await saveSettings(updatedSettings);
  }

  Future<void> toggleHardStop() async {
    final currentSettings = await getSettings();
    final updatedSettings = currentSettings.copyWith(
      hardStopEnabled: !currentSettings.hardStopEnabled,
    );
    await saveSettings(updatedSettings);
  }
}
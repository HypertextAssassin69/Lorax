import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rescue_link/models/device.dart';
import 'package:rescue_link/models/emergency_event.dart';

class StorageService {
  static const String _devicesKey = 'devices';
  static const String _emergencyKey = 'emergency_history';
  static const String _settingsKey = 'settings';
  static const String _themeModeKey = 'theme_mode';
  static const String _alertPrefsKey = 'alert_preferences';

  Future<void> saveDevices(List<Device> devices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = devices.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_devicesKey, jsonList);
    } catch (_) {}
  }

  Future<List<Device>> loadDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_devicesKey) ?? [];
      return jsonList.map((e) => Device.fromJson(jsonDecode(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEmergencyHistory(List<EmergencyEvent> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = events.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_emergencyKey, jsonList);
    } catch (_) {}
  }

  Future<List<EmergencyEvent>> loadEmergencyHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_emergencyKey) ?? [];
      return jsonList.map((e) => EmergencyEvent.fromJson(jsonDecode(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settings));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_settingsKey);
      if (jsonStr != null) {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAlertPreferences({
    required double sirenVolume,
    required bool vibration,
    required bool soundAlerts,
    required String priority,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _alertPrefsKey,
      jsonEncode({
        'sirenVolume': sirenVolume,
        'vibration': vibration,
        'soundAlerts': soundAlerts,
        'priority': priority,
      }),
    );
  }

  Future<Map<String, dynamic>> loadAlertPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_alertPrefsKey);
      if (str != null) {
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'sirenVolume': 1.0,
      'vibration': true,
      'soundAlerts': true,
      'priority': 'Critical',
    };
  }

  Future<void> saveThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeModeKey, isDark);
  }

  Future<bool> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeModeKey) ?? true;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

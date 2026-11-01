import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';
import 'package:rescue_link/services/storage/storage_service.dart';

class SettingsState {
  final bool isDarkMode;
  final ConnectionMode connectionMode;
  final double sirenVolume;
  final bool vibrationEnabled;
  final bool soundAlertsEnabled;
  final String alertPriority;
  final bool loaded;

  const SettingsState({
    this.isDarkMode = true,
    this.connectionMode = ConnectionMode.bluetooth,
    this.sirenVolume = 1.0,
    this.vibrationEnabled = true,
    this.soundAlertsEnabled = true,
    this.alertPriority = 'Critical',
    this.loaded = false,
  });

  SettingsState copyWith({
    bool? isDarkMode,
    ConnectionMode? connectionMode,
    double? sirenVolume,
    bool? vibrationEnabled,
    bool? soundAlertsEnabled,
    String? alertPriority,
    bool? loaded,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      connectionMode: connectionMode ?? this.connectionMode,
      sirenVolume: sirenVolume ?? this.sirenVolume,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundAlertsEnabled: soundAlertsEnabled ?? this.soundAlertsEnabled,
      alertPriority: alertPriority ?? this.alertPriority,
      loaded: loaded ?? this.loaded,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._storage) : super(const SettingsState());

  final StorageService _storage;

  Future<void> load() async {
    final isDark = await _storage.loadThemeMode();
    final stored = await _storage.loadSettings();
    final alertPrefs = await _storage.loadAlertPreferences();
    final modeStr = stored['connectionMode'] as String?;

    ConnectionMode mode = ConnectionMode.bluetooth;
    if (modeStr != null) {
      mode = ConnectionMode.values.firstWhere(
        (e) => e.name == modeStr || e.toString() == modeStr,
        orElse: () => ConnectionMode.bluetooth,
      );
    }

    state = SettingsState(
      isDarkMode: true,
      connectionMode: mode,
      sirenVolume: (alertPrefs['sirenVolume'] as num?)?.toDouble() ?? 1.0,
      vibrationEnabled: alertPrefs['vibration'] as bool? ?? true,
      soundAlertsEnabled: alertPrefs['soundAlerts'] as bool? ?? true,
      alertPriority: alertPrefs['priority'] as String? ?? 'Critical',
      loaded: true,
    );
  }

  Future<void> toggleDarkMode() async {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
    await _persist();
  }

  Future<void> setConnectionMode(ConnectionMode mode) async {
    state = state.copyWith(connectionMode: mode);
    await _persist();
  }

  Future<void> updateAlertPreferences({
    double? sirenVolume,
    bool? vibrationEnabled,
    bool? soundAlertsEnabled,
    String? alertPriority,
  }) async {
    state = state.copyWith(
      sirenVolume: sirenVolume ?? state.sirenVolume,
      vibrationEnabled: vibrationEnabled ?? state.vibrationEnabled,
      soundAlertsEnabled: soundAlertsEnabled ?? state.soundAlertsEnabled,
      alertPriority: alertPriority ?? state.alertPriority,
    );
    await _storage.saveAlertPreferences(
      sirenVolume: state.sirenVolume,
      vibration: state.vibrationEnabled,
      soundAlerts: state.soundAlertsEnabled,
      priority: state.alertPriority,
    );
  }

  Future<void> _persist() async {
    await _storage.saveThemeMode(state.isDarkMode);
    await _storage.saveSettings({
      'connectionMode': state.connectionMode.name,
    });
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage);
});

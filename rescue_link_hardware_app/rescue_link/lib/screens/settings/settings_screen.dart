import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';
import 'package:rescue_link/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showAlertPreferencesDialog(BuildContext context, WidgetRef ref, SettingsState settings) {
    double vol = settings.sirenVolume;
    bool vib = settings.vibrationEnabled;
    bool sound = settings.soundAlertsEnabled;
    String priority = settings.alertPriority;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: AppTheme.secondaryColor),
              SizedBox(width: 8),
              Text('Alert Preferences'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SAR Siren Volume', style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: vol,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${(vol * 100).toInt()}%',
                  onChanged: (v) => setState(() => vol = v),
                ),
                SwitchListTile(
                  title: const Text('Sound Alerts'),
                  subtitle: const Text('Play acoustic siren on incoming SOS'),
                  value: sound,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => sound = v),
                ),
                SwitchListTile(
                  title: const Text('Haptic Vibration'),
                  subtitle: const Text('Vibrate on emergency alert packet'),
                  value: vib,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => vib = v),
                ),
                const SizedBox(height: 8),
                const Text('Alert Priority Threshold', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: priority,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Critical', child: Text('Critical (SOS & Crashes Only)')),
                    DropdownMenuItem(value: 'High', child: Text('High & Critical')),
                    DropdownMenuItem(value: 'All', child: Text('All Alerts')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => priority = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await ref.read(settingsProvider.notifier).updateAlertPreferences(
                  sirenVolume: vol,
                  soundAlertsEnabled: sound,
                  vibrationEnabled: vib,
                  alertPriority: priority,
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alert preferences saved')),
                  );
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBluetoothStatusDialog(BuildContext context, WidgetRef ref) {
    final bleService = ref.read(meshtasticBleServiceProvider);
    final isConn = ref.read(meshtasticConnectionStateProvider);
    final name = ref.read(meshtasticDeviceNameProvider) ?? 'Meshtastic Node';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth, color: AppTheme.secondaryColor),
            SizedBox(width: 8),
            Text('Bluetooth Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('State: ${isConn ? "CONNECTED" : "DISCONNECTED"}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isConn ? AppTheme.safeColor : AppTheme.offlineColor,
                )),
            const SizedBox(height: 6),
            Text('Active Peripheral: $name'),
            const SizedBox(height: 6),
            const Text('Fixed Passkey: 123456'),
            const SizedBox(height: 6),
            const Text('Service UUID: 6ba1b218-15a8-461f-9fa8-5dcae273eafd'),
          ],
        ),
        actions: [
          if (isConn)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.emergencyRed),
              onPressed: () {
                Navigator.pop(ctx);
                bleService.disconnect();
              },
              child: const Text('DISCONNECT'),
            )
          else
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                bleService.connect();
              },
              child: const Text('CONNECT (123456)'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isBle = ref.watch(meshtasticConnectionStateProvider);
    final bleName = ref.watch(meshtasticDeviceNameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildHeader(context, 'APPEARANCE'),
          SwitchListTile(
            title: const Text('Dark Theme'),
            subtitle: const Text('Enable dark mode for the application'),
            value: settings.isDarkMode,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).toggleDarkMode();
            },
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),

          _buildHeader(context, 'NOTIFICATIONS & ALERTS'),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Alert Preferences'),
            subtitle: Text('Siren: ${(settings.sirenVolume * 100).toInt()}% • Vibration: ${settings.vibrationEnabled ? "ON" : "OFF"} • Priority: ${settings.alertPriority}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAlertPreferencesDialog(context, ref, settings),
          ),
          const Divider(),

          _buildHeader(context, 'HARDWARE & BLUETOOTH'),
          ListTile(
            leading: Icon(Icons.bluetooth, color: isBle ? AppTheme.safeColor : null),
            title: const Text('Bluetooth Gateway'),
            subtitle: Text(isBle ? 'Connected to ${bleName ?? "Node"} (PIN: 123456)' : 'Disconnected • Tap to configure'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBluetoothStatusDialog(context, ref),
          ),
          const Divider(),

          _buildHeader(context, 'HARDWARE NODE SPECIFICATIONS'),
          const ListTile(
            leading: Icon(Icons.memory),
            title: Text('XIAO ESP32-C6 SAR Node'),
            subtitle: Text('LoRa SX1262 868MHz • u-blox NEO-6M GPS • MPU6050 IMU • 3V Piezo Siren on GPIO 0'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

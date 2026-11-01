import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/core/utils/formatters.dart';
import 'package:rescue_link/models/device.dart';
import 'package:rescue_link/providers/device_provider.dart';
import 'package:rescue_link/providers/emergency_provider.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';
import 'package:rescue_link/providers/network_provider.dart';
import 'package:rescue_link/widgets/sos_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDevice = ref.watch(activeDeviceProvider);
    final allDevices = ref.watch(devicesProvider).valueOrNull ?? [];
    final emergencies = ref.watch(emergencyEventsProvider).valueOrNull ?? [];
    final bluetoothStatus = ref.watch(bluetoothStatusProvider);
    final nodes = ref.watch(networkNodesProvider).valueOrNull ?? [];

    final activeEmergency =
        emergencies.where((e) => !e.acknowledged).firstOrNull;
    final isBluetoothConnected = bluetoothStatus.isConnected;
    final onlineNodeCount =
        nodes.where((n) => n.status == DeviceStatus.active).length;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Active emergency banner
                    if (activeEmergency != null) ...[
                      _buildEmergencyBanner(context, activeEmergency),
                      const SizedBox(height: 12),
                    ],

                    if (activeDevice == null) ...[
                      // Empty state when no node is connected
                      _buildNoNodeConnectedCard(context, ref),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Rider selector + Safety status row
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildRiderCard(
                                  context, ref, activeDevice, allDevices),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _buildSafetyCard(
                                  context, activeDevice.safetyStatus),
                            ),
                          ],
                        )
                      else ...[
                        _buildRiderCard(context, ref, activeDevice, allDevices),
                        const SizedBox(height: 12),
                        _buildSafetyCard(context, activeDevice.safetyStatus),
                      ],

                      const SizedBox(height: 16),

                      // Connection status
                      _buildConnectionRow(context, isBluetoothConnected,
                          onlineNodeCount, activeDevice),

                      const SizedBox(height: 20),

                      // Telemetry
                      _buildSectionLabel(context, 'TELEMETRY'),
                      const SizedBox(height: 8),
                      _buildTelemetryRow(context, activeDevice, isWide),

                      const SizedBox(height: 24),
                    ],

                    // SOS button
                    _buildSosButton(context, ref, activeDevice?.id ?? 'ESP32-C6'),
                    const SizedBox(height: 12),
                    _buildSarSirenButton(context, ref),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoNodeConnectedCard(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sensors_off,
                    color: AppTheme.secondaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No Meshtastic Node Connected',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target nodes: Meshtastic_9448, Meshtastic_aee8, Meshtastic_af88',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Connect your Seeed Studio XIAO ESP32-C6 node over Bluetooth LE (PIN: 123456) or USB to receive live telemetry from the NEO-6M GPS, trigger the acoustic SAR siren, and relay mesh alerts.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.bluetooth_searching, size: 20),
                  label: const Text(
                    'PAIR NODE (BLE)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  onPressed: () {
                    ref.read(meshtasticBleServiceProvider).connect();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.usb, size: 20),
                  label: const Text(
                    'USB SERIAL',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onPressed: () {
                    ref.read(hardwareSerialServiceProvider).connect();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _buildEmergencyBanner(BuildContext context, dynamic event) {
    final typeName = Formatters.formatEmergencyType(event.type);
    final rider = event.riderName ?? event.deviceId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.emergencyRed,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE EMERGENCY — $typeName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Rider: $rider \u2022 ${Formatters.formatTimeAgo(event.timestamp)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.emergencyRed,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => context.go('/emergency'),
            child: const Text('VIEW',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderCard(BuildContext context, WidgetRef ref,
      Device activeDevice, List<Device> allDevices) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(context, 'ACTIVE NODE'),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.memory,
                    size: 26, color: AppTheme.secondaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeDevice.riderName ?? activeDevice.id,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'ID: ${activeDevice.id} \u2022 FW: ${activeDevice.firmwareVersion}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              if (allDevices.length > 1)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: 'Switch Node',
                  onSelected: (id) {
                    ref.read(activeDeviceIdProvider.notifier).state = id;
                  },
                  itemBuilder: (_) => allDevices
                      .map((d) => PopupMenuItem(
                            value: d.id,
                            child: Text(d.riderName ?? d.id),
                          ))
                      .toList(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard(BuildContext context, SafetyStatus status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case SafetyStatus.safe:
        bg = AppTheme.safeColor.withValues(alpha: 0.12);
        fg = AppTheme.safeColor;
        label = 'SAFE';
        icon = Icons.check_circle;
        break;
      case SafetyStatus.sosActive:
        bg = AppTheme.emergencyRed.withValues(alpha: 0.15);
        fg = AppTheme.emergencyRed;
        label = 'SOS ACTIVE';
        icon = Icons.warning_rounded;
        break;
      case SafetyStatus.crashDetected:
        bg = AppTheme.emergencyRed.withValues(alpha: 0.15);
        fg = AppTheme.emergencyRed;
        label = 'CRASH DETECTED';
        icon = Icons.car_crash;
        break;
      case SafetyStatus.offline:
        bg = AppTheme.offlineColor.withValues(alpha: 0.12);
        fg = AppTheme.offlineColor;
        label = 'OFFLINE';
        icon = Icons.cloud_off;
        break;
      case SafetyStatus.unknown:
        bg = AppTheme.offlineColor.withValues(alpha: 0.12);
        fg = AppTheme.offlineColor;
        label = 'UNKNOWN';
        icon = Icons.help_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(context, 'SAFETY STATUS'),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(icon, color: fg, size: 28),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionRow(BuildContext context, bool isBt, int nodeCount,
      Device activeDevice) {
    return Row(
      children: [
        Expanded(
          child: _ConnectionChip(
            icon: Icons.bluetooth,
            label: isBt ? 'BLUETOOTH LINK' : 'BT OFFLINE',
            detail: isBt ? 'Connected (PIN 123456)' : 'Disconnected',
            isOk: isBt,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ConnectionChip(
            icon: Icons.hub,
            label: 'LORA MESH',
            detail: nodeCount > 0 ? '$nodeCount Active Node(s)' : 'Direct Link',
            isOk: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ConnectionChip(
            icon: Icons.gps_fixed,
            label: 'NEO-6M GPS',
            detail: activeDevice.location?.satellites != null
                ? '${activeDevice.location!.satellites} Sats Fix'
                : 'Searching Sats',
            isOk: activeDevice.location?.fixStatus == GpsFixStatus.fix3D ||
                activeDevice.location?.fixStatus == GpsFixStatus.fix2D,
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryRow(
      BuildContext context, Device device, bool isWide) {
    final batteryStr = '${device.batteryLevel}%';
    final rssiStr = device.rssi != null ? '${device.rssi} dBm' : 'N/A';
    final snrStr = device.snr != null ? '${device.snr!.toStringAsFixed(1)} dB' : 'N/A';
    final locStr = device.location != null
        ? '${device.location!.latitude.toStringAsFixed(4)}, ${device.location!.longitude.toStringAsFixed(4)}'
        : 'Acquiring GPS...';
    final satsStr = device.location?.satellites.toString() ?? '0';

    Color? batteryColor;
    if (device.batteryLevel < 20) {
      batteryColor = AppTheme.warningColor;
    }

    final items = [
      _TeleDatum('BATTERY', batteryStr, Icons.battery_charging_full,
          color: batteryColor),
      _TeleDatum('RSSI', rssiStr, Icons.wifi),
      _TeleDatum('SNR', snrStr, Icons.show_chart),
      _TeleDatum('MESH HOPS', '${device.hopCount} Hops', Icons.route),
      _TeleDatum('SATELLITES', satsStr, Icons.satellite_alt),
      _TeleDatum('COORDINATES', locStr, Icons.location_on),
    ];

    if (isWide) {
      return Row(
        children: items
            .map((item) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _TelemetryTile(
                      label: item.label,
                      value: item.value,
                      icon: item.icon,
                      color: item.color,
                    ),
                  ),
                ))
            .toList(),
      );
    } else {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.2,
        children: items
            .map((item) => _TelemetryTile(
                  label: item.label,
                  value: item.value,
                  icon: item.icon,
                  color: item.color,
                ))
            .toList(),
      );
    }
  }

  Widget _buildSosButton(BuildContext context, WidgetRef ref, String deviceId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SosButton(
        holdDuration: const Duration(milliseconds: 1400),
        onPressed: () => _confirmSos(context, ref, deviceId),
      ),
    );
  }

  Widget _buildSarSirenButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.warningColor,
          foregroundColor: Colors.black87,
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.campaign, size: 24, color: Colors.black),
        label: const Text(
          'TRIGGER SAR SIREN / BUZZER (GPIO 0)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: Colors.black,
          ),
        ),
        onPressed: () async {
          await ref.read(meshtasticBleServiceProvider).triggerAcousticSiren();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '🔊 Acoustic Siren Triggered on Node (GPIO 0 / D0 Buzzer Active)!'),
                backgroundColor: AppTheme.warningColor,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmSos(BuildContext context, WidgetRef ref, String deviceId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.emergencyRed),
            SizedBox(width: 8),
            Text('Confirm SOS Broadcast'),
          ],
        ),
        content: const Text(
          'This will transmit an emergency SOS packet across the LoRa mesh network to all nearby rescue nodes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emergencyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(meshtasticBleServiceProvider)
                  .broadcastEmergencySos();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        '🚨 EMERGENCY SOS BROADCASTED TO LORA MESH (PortNum: TEXT_MESSAGE_APP)!'),
                    backgroundColor: AppTheme.emergencyRed,
                  ),
                );
                context.go('/emergency');
              }
            },
            child: const Text('TRIGGER SOS'),
          ),
        ],
      ),
    );
  }
}

// --- Private helper widgets ---

class _ConnectionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool isOk;

  const _ConnectionChip({
    required this.icon,
    required this.label,
    required this.detail,
    required this.isOk,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOk ? AppTheme.safeColor : AppTheme.offlineColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeleDatum {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _TeleDatum(this.label, this.value, this.icon, {this.color});
}

class _TelemetryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _TelemetryTile({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c =
        color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.25),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/core/utils/formatters.dart';
import 'package:rescue_link/models/device.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';
import 'package:rescue_link/providers/device_provider.dart';
import 'package:rescue_link/services/meshtastic_ble_service.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  bool _isScanning = false;

  final List<Map<String, String>> _targetNodes = const [
    {'name': 'Meshtastic_af88', 'mac': '10:BD:A3:97:AF:8A', 'desc': 'Active Nearby Node (Seeed ESP32-C6)'},
    {'name': 'Meshtastic_9448', 'mac': 'Node ID: 0xa3999448', 'desc': 'LoRa SAR Node 1 (868 MHz)'},
    {'name': 'Meshtastic_aee8', 'mac': 'Node ID: 0xa399aee8', 'desc': 'LoRa SAR Node 2 (868 MHz)'},
  ];

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider).valueOrNull ?? [];
    final bleService = ref.watch(meshtasticBleServiceProvider);
    final isBleConnected = ref.watch(meshtasticConnectionStateProvider);
    final connectedName = ref.watch(meshtasticDeviceNameProvider) ?? 'Meshtastic Node';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Card
            _buildHardwareStatusCard(context, bleService, isBleConnected, connectedName),
            const SizedBox(height: 16),

            // Brave Notice on Web
            if (kIsWeb)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Browser Pairing Notice (Brave / Chrome / Edge)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tapping "PAIR" opens your browser\'s native Bluetooth popup at the top-left of the window. Select Meshtastic_af88 and enter PIN 123456.\n\n⚠️ NOTE FOR BRAVE USERS: Brave Browser blocks Web Bluetooth by default. If no browser prompt appears, open http://localhost:8080 in Google Chrome or Microsoft Edge.',
                            style: TextStyle(fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Target Nodes Quick Pair
            Text(
              'TARGET HARDWARE NODES',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),

            ..._targetNodes.map(
              (node) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: node['name'] == 'Meshtastic_af88'
                        ? AppTheme.secondaryColor.withValues(alpha: 0.5)
                        : Colors.grey.withValues(alpha: 0.2),
                    width: node['name'] == 'Meshtastic_af88' ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.memory,
                    color: node['name'] == 'Meshtastic_af88' ? AppTheme.secondaryColor : Colors.grey,
                  ),
                  title: Text(node['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text('${node['mac']} • ${node['desc']}', style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: node['name'] == 'Meshtastic_af88' ? AppTheme.safeColor : AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () async {
                      await bleService.connect(node['name']);
                    },
                    child: const Text('PAIR (123456)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Active / Heard Mesh Nodes
            Text(
              'HEARD MESH NODES (${devices.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),

            if (devices.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.cell_tower, size: 48, color: AppTheme.secondaryColor.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'No Mesh Peers Connected Yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pair with Meshtastic_af88 above to start streaming live coordinates from NEO-6M GPS and receiving LoRa mesh packets.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...devices.map((d) => _DeviceCard(device: d)),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareStatusCard(BuildContext context, MeshtasticBleService bleService,
      bool isBleConnected, String connectedName) {
    final isUsbConnected = ref.watch(hardwareConnectionStateProvider);
    final serialService = ref.watch(hardwareSerialServiceProvider);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isBleConnected || isUsbConnected ? AppTheme.emeraldGreen : AppTheme.cyberCyan).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBleConnected
                    ? Icons.bluetooth_connected
                    : (isUsbConnected ? Icons.usb : Icons.bluetooth_searching),
                color: (isBleConnected || isUsbConnected) ? AppTheme.emeraldGreen : AppTheme.cyberCyan,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBleConnected
                          ? connectedName
                          : (isUsbConnected ? 'USB-C Serial Gateway' : 'Gateway Disconnected'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    Text(
                      isBleConnected
                          ? 'Service UUID: 6ba1b218... • PIN: 123456 • 868MHz LoRa'
                          : (isUsbConnected
                              ? '115200 baud direct hardware stream connected'
                              : 'Ready to pair via Bluetooth LE or USB Serial'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ((isBleConnected || isUsbConnected) ? AppTheme.emeraldGreen : AppTheme.offlineSlate)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: ((isBleConnected || isUsbConnected) ? AppTheme.emeraldGreen : AppTheme.offlineSlate)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  (isBleConnected || isUsbConnected) ? 'CONNECTED' : 'STANDBY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: (isBleConnected || isUsbConnected) ? AppTheme.emeraldGreen : AppTheme.offlineSlate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // BLE Connect/Disconnect Toggle
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBleConnected ? AppTheme.crimsonRed : AppTheme.cyberCyan,
                  foregroundColor: isBleConnected ? Colors.white : AppTheme.obsidianBg,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: isBleConnected
                    ? const Icon(Icons.bluetooth_disabled, size: 18)
                    : (_isScanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.bluetooth_searching, size: 18)),
                label: Text(
                  isBleConnected
                      ? 'DISCONNECT BLE'
                      : (_isScanning ? 'OPENING SCANNER...' : 'PAIR WITH BLE (PIN: 123456)'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: _isScanning
                    ? null
                    : () async {
                        if (isBleConnected) {
                          await bleService.disconnect();
                        } else {
                          setState(() => _isScanning = true);
                          await bleService.connect();
                          await Future.delayed(const Duration(seconds: 3));
                          if (mounted) setState(() => _isScanning = false);
                        }
                      },
              ),

              // USB WebSerial Toggle
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isUsbConnected ? AppTheme.crimsonRed : AppTheme.emeraldGreen,
                  side: BorderSide(
                    color: isUsbConnected ? AppTheme.crimsonRed : AppTheme.emeraldGreen,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: Icon(isUsbConnected ? Icons.usb_off : Icons.usb, size: 18),
                label: Text(
                  isUsbConnected ? 'DISCONNECT USB' : 'CONNECT VIA USB SERIAL',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: () async {
                  if (isUsbConnected) {
                    await serialService.disconnect();
                  } else {
                    await serialService.connect();
                  }
                },
              ),

              if (isBleConnected || isUsbConnected)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tacticalAmber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text('TEST SAR SIREN (BUZZER)', style: TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () async {
                    await bleService.triggerAcousticSiren();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔊 Test Siren Triggered on Node (GPIO 0 Buzzer)!'),
                          backgroundColor: AppTheme.tacticalAmber,
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
  }
}

class _DeviceCard extends ConsumerWidget {
  final Device device;

  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = device.status == DeviceStatus.active;
    final isSelected = ref.watch(activeDeviceIdProvider) == device.id;

    Color statusColor;
    String safetyLabel;
    if (!isOnline) {
      statusColor = AppTheme.offlineColor;
      safetyLabel = 'OFFLINE';
    } else if (device.safetyStatus == SafetyStatus.sosActive) {
      statusColor = AppTheme.emergencyRed;
      safetyLabel = 'SOS';
    } else if (device.safetyStatus == SafetyStatus.crashDetected) {
      statusColor = AppTheme.emergencyRed;
      safetyLabel = 'CRASH';
    } else if (device.batteryLevel < 20) {
      statusColor = AppTheme.warningColor;
      safetyLabel = 'LOW BAT';
    } else {
      statusColor = AppTheme.safeColor;
      safetyLabel = 'SAFE';
    }

    final batteryStr = '${device.batteryLevel}%';
    final rssiStr = device.rssi != null ? '${device.rssi} dBm' : 'N/A';
    final snrStr = device.snr != null ? '${device.snr!.toStringAsFixed(1)} dB' : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ref.read(activeDeviceIdProvider.notifier).state = device.id;
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.memory, size: 22, color: AppTheme.secondaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.id,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        if (device.riderName != null && device.riderName!.isNotEmpty)
                          Text(
                            device.riderName!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: statusColor),
                        const SizedBox(width: 5),
                        Text(
                          safetyLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Stat('Battery', batteryStr, device.batteryLevel < 20 ? AppTheme.tacticalAmber : AppTheme.emeraldGreen),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'RSSI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildRssiBars(device.rssi),
                        ],
                      ),
                      Text(
                        rssiStr,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  _Stat('SNR', snrStr, AppTheme.cyberCyan),
                  const SizedBox(width: 16),
                  _Stat('Last Seen', Formatters.formatTimeAgo(device.lastSeen), null),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildRssiBars(int? rssi) {
    final val = rssi ?? -100;
    int activeBars = 1;
    Color barColor = AppTheme.crimsonRed;
    if (val >= -65) {
      activeBars = 4;
      barColor = AppTheme.emeraldGreen;
    } else if (val >= -75) {
      activeBars = 3;
      barColor = AppTheme.cyberCyan;
    } else if (val >= -85) {
      activeBars = 2;
      barColor = AppTheme.tacticalAmber;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final barHeight = 4.0 + (index * 3.0);
        final isFilled = index < activeBars;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.0),
          width: 3.0,
          height: barHeight,
          decoration: BoxDecoration(
            color: isFilled ? barColor : AppTheme.slateBorder,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

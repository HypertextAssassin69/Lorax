import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/models/device.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';
import 'package:rescue_link/providers/device_provider.dart';
import 'package:rescue_link/providers/emergency_provider.dart';
import 'package:rescue_link/services/meshtastic_ble_service.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  bool _isInit = false;
  StreamSubscription<GpsPositionData>? _gpsSub;
  StreamSubscription<SosAlertData>? _sosSub;
  LatLng? _liveHardwareGps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindMeshtasticStreams();
    });
  }

  void _bindMeshtasticStreams() {
    final bleService = ref.read(meshtasticBleServiceProvider);

    // 1. Bind onGpsReceived: update live map coordinates from NEO-6M GPS
    _gpsSub = bleService.onGpsReceived.listen((gps) {
      if (!mounted) return;
      setState(() {
        _liveHardwareGps = LatLng(gps.latitude, gps.longitude);
      });
      if (_isInit) {
        _mapController.move(_liveHardwareGps!, 16.0);
      }
    });

    // 2. Bind onSosAlert: display immediate emergency alert banner / dialog
    _sosSub = bleService.onSosAlert.listen((sos) {
      if (!mounted) return;
      _showSosAlertDialog(sos);
    });
  }

  void _showSosAlertDialog(SosAlertData sos) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.primaryNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.emergencyRed, width: 2),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning, color: AppTheme.emergencyRed, size: 28),
              SizedBox(width: 10),
              Text(
                'EMERGENCY SOS ALERT',
                style: TextStyle(
                  color: AppTheme.emergencyRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tactile emergency button pressed on node: ${sos.nodeId}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                sos.message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              if (sos.latitude != null && sos.longitude != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.emergencyRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.emergencyRed, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${sos.latitude!.toStringAsFixed(5)}, ${sos.longitude!.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.warningColor,
                side: const BorderSide(color: AppTheme.warningColor),
              ),
              icon: const Icon(Icons.campaign, size: 20),
              label: const Text('SOUND SAR SIREN'),
              onPressed: () async {
                await ref.read(meshtasticBleServiceProvider).triggerAcousticSiren();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('SAR Siren (GPIO 0 Piezo Buzzer) triggered!'),
                      backgroundColor: AppTheme.warningColor,
                    ),
                  );
                }
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emergencyRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('DISMISS'),
            ),
          ],
        );
      },
    );
  }

  void _centerOnDevice(Device device) {
    if (device.location != null && _isInit) {
      _mapController.move(
        LatLng(device.location!.latitude, device.location!.longitude),
        15.5,
      );
    }
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _sosSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider).valueOrNull ?? [];
    final emergencies = ref.watch(emergencyEventsProvider).valueOrNull ?? [];
    final activeId = ref.watch(activeDeviceIdProvider);
    final isBleConnected = ref.watch(meshtasticConnectionStateProvider);
    final bleDeviceName = ref.watch(meshtasticDeviceNameProvider) ?? 'Meshtastic_af88';

    LatLng initialCenter = const LatLng(31.7640, 76.9860);
    Device? activeDevice;

    if (devices.isNotEmpty) {
      activeDevice = devices.where((d) => d.id == activeId).firstOrNull ?? devices.first;
      if (activeDevice.location != null) {
        initialCenter = LatLng(activeDevice.location!.latitude, activeDevice.location!.longitude);
      }
    }

    if (_liveHardwareGps != null) {
      initialCenter = _liveHardwareGps!;
    }

    final activeEmergency = emergencies.where((e) => !e.acknowledged).firstOrNull;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15.0,
              onMapReady: () {
                _isInit = true;
                if (activeDevice != null) _centerOnDevice(activeDevice);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rescuelink.rescue_link',
              ),
              MarkerLayer(
                markers: [
                  ...devices.where((d) => d.location != null).map((device) {
                    final isSelected = device.id == activeId;
                    final hasEmergency = emergencies.any(
                      (e) => e.deviceId == device.id && !e.acknowledged,
                    );

                    IconData iconData = Icons.two_wheeler;
                    Color markerColor = AppTheme.secondaryColor;

                    if (hasEmergency) {
                      markerColor = AppTheme.emergencyRed;
                      iconData = Icons.warning;
                    } else if (device.status == DeviceStatus.offline) {
                      markerColor = AppTheme.offlineColor;
                    } else if (device.safetyStatus == SafetyStatus.safe) {
                      markerColor = AppTheme.safeColor;
                    }

                    return Marker(
                      point: LatLng(device.location!.latitude, device.location!.longitude),
                      width: isSelected ? 52 : 38,
                      height: isSelected ? 52 : 38,
                      child: GestureDetector(
                        onTap: () {
                          ref.read(activeDeviceIdProvider.notifier).state = device.id;
                          _centerOnDevice(device);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: markerColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                            boxShadow: [
                              BoxShadow(
                                color: markerColor.withValues(alpha: 0.45),
                                blurRadius: 8,
                                spreadRadius: isSelected ? 3 : 1,
                              ),
                            ],
                          ),
                          child: Icon(iconData, color: Colors.white, size: isSelected ? 24 : 18),
                        ),
                      ),
                    );
                  }),

                  // Hardware live GPS pin marker if available
                  if (_liveHardwareGps != null)
                    Marker(
                      point: _liveHardwareGps!,
                      width: 54,
                      height: 54,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondaryColor.withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.gps_fixed, color: Colors.white, size: 26),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Floating device info card (Top Left)
          if (activeDevice != null)
            Positioned(
              top: 14,
              left: 14,
              child: _FloatingDeviceCard(
                device: activeDevice,
                onCenter: () => _centerOnDevice(activeDevice!),
              ),
            ),

          // Node connection badge / button (Top Right)
          Positioned(
            top: 14,
            right: 14,
            child: InkWell(
              onTap: () {
                ref.read(meshtasticBleServiceProvider).connect();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isBleConnected ? AppTheme.safeColor : AppTheme.secondaryColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBleConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                      size: 18,
                      color: isBleConnected ? AppTheme.safeColor : AppTheme.secondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isBleConnected ? bleDeviceName : 'SCAN BLE NODES',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isBleConnected ? AppTheme.safeColor : AppTheme.secondaryColor,
                          ),
                        ),
                        Text(
                          isBleConnected ? 'PIN: 123456 • 868MHz' : 'Tap to Pair ESP32-C6',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Active Emergency Banner (if any)
          if (activeEmergency != null)
            Positioned(
              top: 80,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.emergencyRed,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emergencyRed.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                            'EMERGENCY SOS: ${activeEmergency.deviceId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            activeEmergency.riderName ?? 'Victim distress beacon active!',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.emergencyRed,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.campaign, size: 20),
                      label: const Text('SIREN', style: TextStyle(fontWeight: FontWeight.w900)),
                      onPressed: () async {
                        await ref.read(meshtasticBleServiceProvider).triggerAcousticSiren();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('SAR Siren Triggered on ESP32-C6 Node!'),
                              backgroundColor: AppTheme.warningColor,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Live Map Recenter / Locate Button (Bottom Right)
          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'recenter_gps_fab',
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: AppTheme.secondaryColor,
              tooltip: 'Snap Camera to NEO-6M GPS',
              onPressed: () {
                if (_liveHardwareGps != null) {
                  _mapController.move(_liveHardwareGps!, 16.5);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📍 Centered on live NEO-6M GPS coordinates'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else if (activeDevice?.location != null) {
                  final loc = LatLng(
                    activeDevice!.location!.latitude,
                    activeDevice.location!.longitude,
                  );
                  _mapController.move(loc, 16.5);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Acquiring NEO-6M GPS satellites fix...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // Prominent "SOUND SAR SIREN" Button (Bottom Center/Right)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.warningColor.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningColor,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.campaign, size: 28, color: Colors.black),
                    label: const Text(
                      'SOUND SAR SIREN (BUZZER)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Colors.black,
                      ),
                    ),
                    onPressed: () async {
                      await ref.read(meshtasticBleServiceProvider).triggerAcousticSiren();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.volume_up, color: Colors.black),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'EXTERNAL_NOTIFICATION_APP (PortNum 72) sent -> GPIO 0 Buzzer active!',
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: AppTheme.warningColor,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingDeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onCenter;

  const _FloatingDeviceCard({required this.device, required this.onCenter});

  @override
  Widget build(BuildContext context) {
    final isOnline = device.status == DeviceStatus.active;
    final statusColor = isOnline ? AppTheme.safeColor : AppTheme.offlineColor;
    final riderStr = device.riderName != null && device.riderName!.isNotEmpty
        ? device.riderName!
        : device.id;
    final batteryStr = '${device.batteryLevel}%';
    final rssiStr = device.rssi != null ? '${device.rssi} dBm' : 'N/A';

    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(riderStr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    Text(device.id, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.my_location),
                  onPressed: onCenter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MapStat(Icons.battery_5_bar, batteryStr),
              const SizedBox(width: 12),
              _MapStat(Icons.signal_cellular_alt, rssiStr),
              const SizedBox(width: 12),
              _MapStat(Icons.route, '${device.hopCount} hops'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapStat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _MapStat(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
      ],
    );
  }
}

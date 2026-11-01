import 'dart:async';
import 'package:rescue_link/services/meshtastic/meshtastic_ble_stub.dart'
    if (dart.library.io) 'package:rescue_link/services/meshtastic/meshtastic_ble_native.dart'
    if (dart.library.html) 'package:rescue_link/services/meshtastic/meshtastic_ble_web_impl.dart' as impl;

export 'package:rescue_link/services/meshtastic/meshtastic_constants.dart';

/// Bluetooth connection state enum matching standard BLE states
enum BluetoothConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting;

  bool get isConnected => this == BluetoothConnectionState.connected;
}

/// Discovered physical Meshtastic hardware node during BLE scan
class DiscoveredNode {
  final String id;
  final String name;
  final int rssi;

  const DiscoveredNode({
    required this.id,
    required this.name,
    required this.rssi,
  });

  @override
  String toString() => 'DiscoveredNode(id: $id, name: $name, rssi: $rssi dBm)';
}

/// GPS Position telemetry extracted from Meshtastic NEO-6M GPS module
class GpsPositionData {
  final double latitude;
  final double longitude;
  final double altitude;
  final int satellites;
  final DateTime timestamp;

  const GpsPositionData({
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    this.satellites = 0,
    required this.timestamp,
  });

  @override
  String toString() =>
      'GpsPositionData(lat: $latitude, lng: $longitude, alt: ${altitude}m, sats: $satellites)';
}

/// Emergency SOS Alert triggered from the tactile push button (Active LOW) or SOS message
class SosAlertData {
  final String nodeId;
  final String message;
  final DateTime timestamp;
  final bool isEmergency;
  final double? latitude;
  final double? longitude;

  const SosAlertData({
    required this.nodeId,
    required this.message,
    required this.timestamp,
    this.isEmergency = true,
    this.latitude,
    this.longitude,
  });

  @override
  String toString() =>
      'SosAlertData(node: $nodeId, msg: "$message", time: $timestamp)';
}

/// Main interface for Search-and-Rescue (SAR) Meshtastic BLE communication
abstract class MeshtasticBleService {
  factory MeshtasticBleService() => impl.createMeshtasticBleService();

  /// Reactive stream of decoded GPS position fixes from the hardware NEO-6M module
  Stream<GpsPositionData> get onGpsReceived;

  /// Reactive stream triggered on physical tactile button SOS or emergency broadcast
  Stream<SosAlertData> get onSosAlert;

  /// Reactive connection state stream
  Stream<BluetoothConnectionState> get connectionState;

  /// Stream of discovered physical nodes during active scan
  Stream<List<DiscoveredNode>> get discoveredNodes;

  /// Currently discovered physical nodes list
  List<DiscoveredNode> get currentDiscoveredNodes;

  /// Whether currently connected to a Meshtastic hardware node
  bool get isConnected;

  /// Connected node BLE advertising name (e.g. "Meshtastic_af88", "Meshtastic_9448")
  String? get connectedDeviceName;

  /// Start BLE scanning filtered for Service UUID 6ba1b218-15a8-461f-9fa8-5dcae273eafd
  /// and advertising names matching Meshtastic_*
  Future<void> startScan();

  /// Stop current BLE scan
  Future<void> stopScan();

  /// Connect and automatically pair with passkey "123456"
  Future<void> connect([String? deviceId]);

  /// Disconnect from the current BLE node
  Future<void> disconnect();

  /// Transmit external notification packet to fire GPIO 0 on the ESP32-C6,
  /// sounding the 3V piezo buzzer on the lost victim's node.
  Future<void> triggerAcousticSiren();

  /// Backward-compatible alias for triggerAcousticSiren
  Future<void> triggerSarSiren();

  /// Transmit an immediate high-priority emergency SOS text packet across the LoRa mesh network
  Future<void> broadcastEmergencySos();

  /// Send arbitrary text message out over the LoRa mesh network via ToRadio
  Future<void> sendBroadcastMessage(String text);

  void dispose();
}

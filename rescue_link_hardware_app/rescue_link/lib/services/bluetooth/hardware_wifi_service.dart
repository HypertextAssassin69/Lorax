import 'dart:async';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/models/packet.dart';
import 'package:rescue_link/models/bluetooth_status.dart';
import 'package:rescue_link/services/bluetooth/bluetooth_service.dart';

class WifiBluetoothService implements BluetoothService {
  @override
  Stream<Packet> get packetStream => throw UnimplementedError('Requires ESP32 hardware integration');

  @override
  Stream<BluetoothStatus> get statusStream => throw UnimplementedError('Requires ESP32 hardware integration');

  @override
  bool get isConnected => false;

  @override
  BluetoothStatus get currentStatus => const BluetoothStatus(
    isConnected: false,
    mode: ConnectionMode.wifi,
    signalStrength: 0,
    lastHeartbeat: null,
    bluetoothId: 'WIFI-GATEWAY-PENDING',
  );

  @override
  Future<void> connect() {
    // TODO: Implement TCP/UDP socket connection to ESP32 AP
    throw UnimplementedError('Requires ESP32 hardware integration');
  }

  @override
  Future<void> disconnect() {
    throw UnimplementedError('Requires ESP32 hardware integration');
  }

  @override
  Future<bool> sendPacket(Packet packet) {
    // TODO: Implement socket write
    throw UnimplementedError('Requires ESP32 hardware integration');
  }

  @override
  void dispose() {
    // TODO: Clean up socket resources
  }
}

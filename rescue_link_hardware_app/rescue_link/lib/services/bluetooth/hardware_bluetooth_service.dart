import 'dart:async';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/models/bluetooth_status.dart';
import 'package:rescue_link/models/packet.dart';
import 'package:rescue_link/services/bluetooth/bluetooth_service.dart';
import 'package:rescue_link/services/meshtastic_ble_service.dart';

/// Real Hardware Bluetooth Service implementation
/// Bridges BluetoothService calls directly to the physical Meshtastic BLE driver.
class HardwareBluetoothService implements BluetoothService {
  HardwareBluetoothService(this._bleService) {
    _statusSubscription = _bleService.connectionState.listen((state) {
      final isConn = state.isConnected;
      final status = BluetoothStatus(
        isConnected: isConn,
        mode: ConnectionMode.bluetooth,
        signalStrength: isConn ? -65 : 0,
        lastHeartbeat: isConn ? DateTime.now() : null,
        bluetoothId: _bleService.connectedDeviceName ?? 'Meshtastic Node',
      );
      _statusController.add(status);
    });

    _sosSubscription = _bleService.onSosAlert.listen((sos) {
      final packet = Packet(
        packetId: sos.timestamp.millisecondsSinceEpoch.toString(),
        deviceId: sos.nodeId,
        type: PacketType.sos,
        timestamp: sos.timestamp,
        latitude: sos.latitude,
        longitude: sos.longitude,
        hopCount: 0,
        ttl: 3,
        priority: PacketPriority.critical,
        state: PacketState.delivered,
        source: sos.nodeId,
        destination: 'BROADCAST',
        route: [sos.nodeId],
        safetyStatus: SafetyStatus.sosActive,
        payload: {
          'message': sos.message,
          'lat': sos.latitude ?? 0.0,
          'lng': sos.longitude ?? 0.0,
        },
      );
      _packetController.add(packet);
    });
  }

  final MeshtasticBleService _bleService;
  final StreamController<Packet> _packetController =
      StreamController<Packet>.broadcast();
  final StreamController<BluetoothStatus> _statusController =
      StreamController<BluetoothStatus>.broadcast();

  StreamSubscription? _statusSubscription;
  StreamSubscription? _sosSubscription;

  @override
  Stream<Packet> get packetStream => _packetController.stream;

  @override
  Stream<BluetoothStatus> get statusStream => _statusController.stream;

  @override
  bool get isConnected => _bleService.isConnected;

  @override
  BluetoothStatus get currentStatus => BluetoothStatus(
        isConnected: _bleService.isConnected,
        mode: ConnectionMode.bluetooth,
        signalStrength: _bleService.isConnected ? -65 : 0,
        lastHeartbeat: _bleService.isConnected ? DateTime.now() : null,
        bluetoothId: _bleService.connectedDeviceName ?? 'Meshtastic Node',
      );

  @override
  Future<void> connect([String? deviceId]) async {
    await _bleService.connect(deviceId);
  }

  @override
  Future<void> disconnect() async {
    await _bleService.disconnect();
  }

  @override
  Future<bool> sendPacket(Packet packet) async {
    try {
      if (packet.type == PacketType.sos || packet.type == PacketType.crash) {
        await _bleService.broadcastEmergencySos();
      } else {
        await _bleService.sendBroadcastMessage(packet.payload.toString());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _sosSubscription?.cancel();
    _packetController.close();
    _statusController.close();
  }
}

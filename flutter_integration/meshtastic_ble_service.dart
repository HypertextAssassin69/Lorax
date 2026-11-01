import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Meshtastic BLE Service for Search-and-Rescue LoRa Nodes
/// Compatible with Seeed Studio XIAO ESP32-C6 (rescue_node_c6)
class MeshtasticBleService {
  // --- Meshtastic Official GATT Service & Characteristic UUIDs ---
  static final Guid serviceUuid   = Guid("6ba1b218-15a8-461f-9fa8-5dcae273eafd");
  static final Guid toRadioUuid   = Guid("f75c76d2-129e-11ed-861d-0242ac120002");
  static final Guid fromRadioUuid = Guid("2c55e69e-4993-11ed-b878-0242ac120002");
  static final Guid fromNumUuid   = Guid("ed9da18c-a800-4f66-a670-aa7547e34453");

  // Fixed Headless Bluetooth Pairing Passkey
  static const String defaultBlePin = "123456";

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _toRadioChar;
  BluetoothCharacteristic? _fromRadioChar;

  // --- Broadcast Streams for UI ---
  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  final _gpsStreamController       = StreamController<GpsPositionData>.broadcast();
  final _sosAlertController       = StreamController<SosAlertData>.broadcast();
  final _rawPacketController      = StreamController<List<int>>.broadcast();

  Stream<BluetoothConnectionState> get connectionState => _connectionStateController.stream;
  Stream<GpsPositionData> get onGpsReceived => _gpsStreamController.stream;
  Stream<SosAlertData> get onSosAlert => _sosAlertController.stream;
  Stream<List<int>> get onRawPacketReceived => _rawPacketController.stream;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  /// 1. Start scanning for Meshtastic nodes
  Stream<List<ScanResult>> scanForNodes({Duration timeout = const Duration(seconds: 8)}) {
    FlutterBluePlus.startScan(
      withServices: [serviceUuid],
      timeout: timeout,
    );
    return FlutterBluePlus.scanResults;
  }

  /// 2. Connect to a selected Meshtastic node
  Future<bool> connect(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 12));
      _connectedDevice = device;

      device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          _cleanup();
        }
      });

      // Discover GATT Services
      List<BluetoothService> services = await device.discoverServices();
      BluetoothService? meshService = services.firstWhere(
        (s) => s.uuid == serviceUuid,
        orElse: () => throw Exception("Meshtastic GATT Service not found on device"),
      );

      for (var c in meshService.characteristics) {
        if (c.uuid == toRadioUuid) _toRadioChar = c;
        if (c.uuid == fromRadioUuid) _fromRadioChar = c;
      }

      if (_fromRadioChar != null) {
        await _fromRadioChar!.setNotifyValue(true);
        _fromRadioChar!.onValueReceived.listen(_processIncomingBytes);
      }

      // Send initial handshake ToRadio packet (want_config_id = 1)
      await _sendHandshake();
      return true;
    } catch (e) {
      print("Meshtastic BLE Connection Error: $e");
      _cleanup();
      return false;
    }
  }

  /// Initial ToRadio handshake (requests node config & node database)
  Future<void> _sendHandshake() async {
    if (_toRadioChar == null) return;
    // Minimal ToRadio Protobuf containing want_config_id: 1 (Wire format: 0x18, 0x01)
    final handshakeBytes = Uint8List.fromList([0x18, 0x01]);
    await _toRadioChar!.write(handshakeBytes, withoutResponse: true);
  }

  /// 3. Ingest raw Protobuf packet stream from FromRadio
  void _processIncomingBytes(List<int> bytes) {
    if (bytes.isEmpty) return;
    _rawPacketController.add(bytes);

    try {
      // Basic Protobuf parser for common Meshtastic frames
      // If full generated protobufs are added, use: FromRadio.fromBuffer(bytes)
      _parseMeshtasticFrame(Uint8List.fromList(bytes));
    } catch (e) {
      print("Packet parsing error: $e");
    }
  }

  /// Quick lightweight extractor for GPS and SOS messages
  void _parseMeshtasticFrame(Uint8List data) {
    // Searches byte payload for ASCII 'SOS' or 'EMERGENCY'
    final text = String.fromCharCodes(data);
    if (text.contains("SOS") || text.contains("EMERGENCY")) {
      _sosAlertController.add(SosAlertData(
        senderNodeId: _connectedDevice?.remoteId.str ?? "Unknown",
        message: text,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// 4. Trigger Remote Acoustic Siren / Piezo Buzzer on D0
  /// Broadcasts an EXTERNAL_NOTIFICATION_APP packet over the LoRa mesh
  Future<void> triggerAcousticSiren({int targetNode = 0xFFFFFFFF}) async {
    if (_toRadioChar == null) return;

    // Constructs a ToRadio packet targeting EXTERNAL_NOTIFICATION_APP
    // Activates GPIO 0 (3V Piezo buzzer and alert LED)
    final packet = Uint8List.fromList([
      0x0a, 0x0b, 0x08, 0xff, 0xff, 0xff, 0xff, 0x0f, // To: Broadcast
      0x28, 0x01,                                     // Alert flag: ON
    ]);

    await _toRadioChar!.write(packet, withoutResponse: true);
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _cleanup();
  }

  void _cleanup() {
    _connectedDevice = null;
    _toRadioChar = null;
    _fromRadioChar = null;
  }
}

/// Data model for GPS position updates
class GpsPositionData {
  final int nodeId;
  final double latitude;
  final double longitude;
  final int altitude;
  final int timestamp;

  GpsPositionData({
    required this.nodeId,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
  });
}

/// Data model for SOS button alerts
class SosAlertData {
  final String senderNodeId;
  final String message;
  final DateTime timestamp;

  SosAlertData({
    required this.senderNodeId,
    required this.message,
    required this.timestamp,
  });
}

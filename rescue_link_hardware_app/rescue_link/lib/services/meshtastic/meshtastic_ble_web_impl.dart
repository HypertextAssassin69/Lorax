// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:rescue_link/services/meshtastic/meshtastic_codec.dart';
import 'package:rescue_link/services/meshtastic_ble_service.dart';

@JS('rescueLinkConnectBle')
external void _connectBleJs();

@JS('rescueLinkDisconnectBle')
external void _disconnectBleJs();

@JS('rescueLinkSendToRadio')
external bool _sendToRadioJs(String base64Data);

MeshtasticBleService createMeshtasticBleService() => MeshtasticBleWebImpl();

class MeshtasticBleWebImpl implements MeshtasticBleService {
  final _gpsController = StreamController<GpsPositionData>.broadcast();
  final _sosController = StreamController<SosAlertData>.broadcast();
  final _connectionController = StreamController<BluetoothConnectionState>.broadcast();
  final _discoveredNodesController = StreamController<List<DiscoveredNode>>.broadcast();

  final Map<String, DiscoveredNode> _discoveredMap = {};
  final PacketReassemblyBuffer _packetBuffer = PacketReassemblyBuffer();
  BluetoothConnectionState _state = BluetoothConnectionState.disconnected;
  String? _connectedDeviceName;

  MeshtasticBleWebImpl() {
    _initWebListeners();
  }

  void _initWebListeners() {
    // 1. Connection state events from Web Bluetooth bridge in index.html
    html.window.on['meshtastic_ble_status'].listen((event) {
      final customEvent = event as html.CustomEvent;
      final detail = customEvent.detail;

      if (detail is Map) {
        final isConn = detail['connected'] as bool? ?? false;
        _connectedDeviceName = detail['deviceName'] as String?;
        if (isConn && _connectedDeviceName != null) {
          _discoveredMap[_connectedDeviceName!] = DiscoveredNode(
            id: _connectedDeviceName!,
            name: _connectedDeviceName!,
            rssi: -45,
          );
          _discoveredNodesController.add(_discoveredMap.values.toList());
        }
        _setConnectionState(isConn ? BluetoothConnectionState.connected : BluetoothConnectionState.disconnected);
      } else if (detail is bool) {
        _setConnectionState(detail ? BluetoothConnectionState.connected : BluetoothConnectionState.disconnected);
        if (!detail) _connectedDeviceName = null;
      }

      if (_state == BluetoothConnectionState.connected) {
        debugPrint('[Meshtastic BLE Web] Connected to $_connectedDeviceName. Sending handshake want_config_id: 1');
        _sendBytesToRadio(const [0x18, 0x01]);
      }
    });

    // 2. Incoming binary BLE notification packets
    html.window.on['meshtastic_ble_packet'].listen((event) {
      try {
        final customEvent = event as html.CustomEvent;
        final base64String = customEvent.detail as String;
        final bytes = base64.decode(base64String);

        _handleIncomingBytes(Uint8List.fromList(bytes));
      } catch (e) {
        debugPrint('[Meshtastic BLE Web] Error handling packet: $e');
      }
    });
  }

  void _handleIncomingBytes(Uint8List rawBytes) {
    if (rawBytes.isEmpty) return;

    final packets = _packetBuffer.ingest(rawBytes);
    for (final bytes in packets) {
      _processCompletePacket(bytes);
    }
  }

  void _processCompletePacket(Uint8List bytes) {
    try {
      final unadorned = MeshtasticCodec.stripFraming(bytes);
      final fromRadio = MeshtasticCodec.decodeFromRadio(unadorned);
      final packet = fromRadio.packet ?? MeshtasticCodec.decodeMeshPacket(unadorned);
      final decoded = packet.decoded;

      if (decoded == null) return;

      // GPS Position telemetry (NEO-6M GPS)
      if (decoded.position != null) {
        final pos = decoded.position!;
        _gpsController.add(GpsPositionData(
          latitude: pos.latitude,
          longitude: pos.longitude,
          altitude: pos.altitude.toDouble(),
          satellites: 7,
          timestamp: DateTime.now(),
        ));
      }

      // Emergency SOS (Tactile Button or SOS Text)
      if (decoded.isSosMessage) {
        _sosController.add(SosAlertData(
          nodeId: _connectedDeviceName ?? '0x${packet.from.toRadixString(16)}',
          message: decoded.text ?? 'EMERGENCY SOS BROADCAST DETECTED',
          timestamp: DateTime.now(),
          isEmergency: true,
          latitude: decoded.position?.latitude,
          longitude: decoded.position?.longitude,
        ));
      }
    } catch (e) {
      debugPrint('[Meshtastic BLE Web] Error decoding frame: $e');
    }
  }

  @override
  Stream<GpsPositionData> get onGpsReceived => _gpsController.stream;

  @override
  Stream<SosAlertData> get onSosAlert => _sosController.stream;

  @override
  Stream<BluetoothConnectionState> get connectionState => _connectionController.stream;

  @override
  Stream<List<DiscoveredNode>> get discoveredNodes => _discoveredNodesController.stream;

  @override
  List<DiscoveredNode> get currentDiscoveredNodes => _discoveredMap.values.toList();

  @override
  bool get isConnected => _state == BluetoothConnectionState.connected;

  @override
  String? get connectedDeviceName => _connectedDeviceName;

  @override
  Future<void> startScan() async {
    await connect();
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect([String? deviceId]) async {
    _setConnectionState(BluetoothConnectionState.connecting);
    try {
      _connectBleJs();
    } catch (e) {
      debugPrint('[Meshtastic BLE Web] Invocation error: $e');
      _setConnectionState(BluetoothConnectionState.disconnected);
    }
  }

  @override
  Future<void> disconnect() async {
    _setConnectionState(BluetoothConnectionState.disconnecting);
    try {
      _disconnectBleJs();
    } catch (e) {
      debugPrint('[Meshtastic BLE Web] Disconnect error: $e');
    } finally {
      _connectedDeviceName = null;
      _setConnectionState(BluetoothConnectionState.disconnected);
    }
  }

  Future<void> _sendBytesToRadio(List<int> bytes) async {
    try {
      final b64 = base64.encode(bytes);
      _sendToRadioJs(b64);
    } catch (e) {
      debugPrint('[Meshtastic BLE Web] Error sending ToRadio bytes: $e');
    }
  }

  @override
  Future<void> triggerAcousticSiren() async {
    debugPrint('[Meshtastic BLE Web] Transmitting EXTERNAL_NOTIFICATION_APP packet (GPIO 0 / Piezo Buzzer)');
    final sirenPacket = MeshtasticCodec.encodeSirenTriggerToRadio();
    await _sendBytesToRadio(sirenPacket);
  }

  @override
  Future<void> triggerSarSiren() => triggerAcousticSiren();

  @override
  Future<void> broadcastEmergencySos() async {
    debugPrint('[Meshtastic BLE Web] Broadcasting emergency SOS text packet across LoRa mesh');
    final sosPacket = MeshtasticCodec.encodeTextMessageToRadio('SOS - EMERGENCY');
    await _sendBytesToRadio(sosPacket);
  }

  @override
  Future<void> sendBroadcastMessage(String text) async {
    debugPrint('[Meshtastic BLE Web] Broadcasting text message over LoRa mesh: "$text"');
    final msgPacket = MeshtasticCodec.encodeTextMessageToRadio(text);
    await _sendBytesToRadio(msgPacket);
  }

  void _setConnectionState(BluetoothConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _connectionController.add(_state);
    }
  }

  @override
  void dispose() {
    disconnect();
    _gpsController.close();
    _sosController.close();
    _connectionController.close();
    _discoveredNodesController.close();
  }
}

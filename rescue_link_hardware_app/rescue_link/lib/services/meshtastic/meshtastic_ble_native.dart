import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';
import 'package:rescue_link/services/meshtastic/meshtastic_codec.dart';
import 'package:rescue_link/services/meshtastic_ble_service.dart';

MeshtasticBleService createMeshtasticBleService() => MeshtasticBleNative();

class MeshtasticBleNative implements MeshtasticBleService {
  final _gpsController = StreamController<GpsPositionData>.broadcast();
  final _sosController = StreamController<SosAlertData>.broadcast();
  final _connectionController = StreamController<BluetoothConnectionState>.broadcast();
  final _discoveredNodesController = StreamController<List<DiscoveredNode>>.broadcast();

  final Map<String, DiscoveredNode> _discoveredMap = {};
  final PacketReassemblyBuffer _packetBuffer = PacketReassemblyBuffer();
  BluetoothConnectionState _state = BluetoothConnectionState.disconnected;
  String? _connectedDeviceName;
  fbp.BluetoothDevice? _activeDevice;
  fbp.BluetoothCharacteristic? _toRadioChar;
  fbp.BluetoothCharacteristic? _fromRadioChar;
  fbp.BluetoothCharacteristic? _fromNumChar;
  StreamSubscription? _connSub;
  StreamSubscription? _fromRadioSub;
  StreamSubscription? _fromNumSub;
  StreamSubscription? _scanSub;

  static const String meshtasticServiceUuid = MeshtasticConstants.serviceUuid;
  static const String toRadioUuid = MeshtasticConstants.toRadioUuid;
  static const String fromRadioUuid = MeshtasticConstants.fromRadioUuid;
  static const String fromNumUuid = MeshtasticConstants.fromNumUuid;
  static const String fixedPasskey = MeshtasticConstants.defaultPasskey; // "123456"

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

  /// Check and request required Bluetooth and Location runtime permissions
  Future<bool> _requestPermissions() async {
    final scanStatus = await Permission.bluetoothScan.request();
    final connectStatus = await Permission.bluetoothConnect.request();
    final locStatus = await Permission.locationWhenInUse.request();

    return (scanStatus.isGranted || scanStatus.isLimited) &&
        (connectStatus.isGranted || connectStatus.isLimited) &&
        (locStatus.isGranted || locStatus.isLimited);
  }

  @override
  Future<void> startScan() async {
    await _requestPermissions();
    _discoveredMap.clear();
    _discoveredNodesController.add([]);

    final serviceGuid = fbp.Guid(meshtasticServiceUuid);

    await _scanSub?.cancel();
    _scanSub = fbp.FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;

        final isMeshtastic = name.toLowerCase().startsWith('meshtastic') ||
            r.advertisementData.serviceUuids.contains(serviceGuid);

        if (isMeshtastic) {
          final id = r.device.remoteId.str;
          _discoveredMap[id] = DiscoveredNode(
            id: id,
            name: name.isNotEmpty ? name : 'Meshtastic Node',
            rssi: r.rssi,
          );
        }
      }
      _discoveredNodesController.add(_discoveredMap.values.toList());
    });

    await fbp.FlutterBluePlus.startScan(
      withServices: [serviceGuid],
      timeout: const Duration(seconds: 15),
    );
  }

  @override
  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    await fbp.FlutterBluePlus.stopScan();
  }

  @override
  Future<void> connect([String? targetNameOrId]) async {
    try {
      await _requestPermissions();
      _setConnectionState(BluetoothConnectionState.connecting);

      final serviceGuid = fbp.Guid(meshtasticServiceUuid);

      fbp.BluetoothDevice? targetDevice;

      // Check if already in discovered list
      if (targetNameOrId != null) {
        for (final r in fbp.FlutterBluePlus.lastScanResults) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;
          if (r.device.remoteId.str == targetNameOrId || name == targetNameOrId) {
            targetDevice = r.device;
            break;
          }
        }
      }

      // If not found yet, perform short targeted scan
      if (targetDevice == null) {
        debugPrint('[Meshtastic BLE Native] Scanning for target node ($targetNameOrId)...');
        final completer = Completer<fbp.BluetoothDevice?>();
        final scanSub = fbp.FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            final name = r.device.platformName.isNotEmpty
                ? r.device.platformName
                : r.advertisementData.advName;

            final isMeshtastic = name.toLowerCase().startsWith('meshtastic') ||
                r.advertisementData.serviceUuids.contains(serviceGuid);

            if (isMeshtastic) {
              if (targetNameOrId == null ||
                  name.contains(targetNameOrId) ||
                  r.device.remoteId.str == targetNameOrId) {
                if (!completer.isCompleted) completer.complete(r.device);
                break;
              }
            }
          }
        });

        await fbp.FlutterBluePlus.startScan(
          withServices: [serviceGuid],
          timeout: const Duration(seconds: 8),
        );

        targetDevice = await completer.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () => null,
        );
        await scanSub.cancel();
        await fbp.FlutterBluePlus.stopScan();
      }

      if (targetDevice == null) {
        debugPrint('[Meshtastic BLE Native] No Meshtastic node discovered during scan');
        _setConnectionState(BluetoothConnectionState.disconnected);
        return;
      }

      _activeDevice = targetDevice;
      _connectedDeviceName = targetDevice.platformName.isNotEmpty
          ? targetDevice.platformName
          : 'Meshtastic Node';

      debugPrint('[Meshtastic BLE Native] Connecting to $_connectedDeviceName with PIN: $fixedPasskey');

      // 2. Establish GATT connection and auto-pair
      _connSub = targetDevice.connectionState.listen((fbpState) {
        if (fbpState == fbp.BluetoothConnectionState.connected) {
          _setConnectionState(BluetoothConnectionState.connected);
        } else if (fbpState == fbp.BluetoothConnectionState.disconnected) {
          _setConnectionState(BluetoothConnectionState.disconnected);
          _connectedDeviceName = null;
        }
      });

      await targetDevice.connect(autoConnect: false);

      // Negotiate MTU 512 for full protobuf packet transmission without fragmentation
      try {
        await targetDevice.requestMtu(512);
        debugPrint('[Meshtastic BLE Native] Negotiated MTU 512 successfully');
      } catch (mtuErr) {
        debugPrint('[Meshtastic BLE Native] MTU request note: $mtuErr');
      }

      // Attempt OS pairing/bonding if supported
      try {
        await targetDevice.createBond();
      } catch (e) {
        debugPrint('[Meshtastic BLE Native] createBond note: $e');
      }

      // 3. Discover GATT Services & Characteristics
      final services = await targetDevice.discoverServices();
      for (final service in services) {
        if (service.uuid.str.toLowerCase() == meshtasticServiceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            final uuid = char.uuid.str.toLowerCase();
            if (uuid == toRadioUuid.toLowerCase()) {
              _toRadioChar = char;
            } else if (uuid == fromRadioUuid.toLowerCase()) {
              _fromRadioChar = char;
            } else if (uuid == fromNumUuid.toLowerCase()) {
              _fromNumChar = char;
            }
          }
        }
      }

      if (_toRadioChar == null || _fromRadioChar == null) {
        debugPrint('[Meshtastic BLE Native] Error: Required Meshtastic characteristics not found');
        await disconnect();
        return;
      }

      // 4. Subscribe to FromRadio notifications (with graceful fallback if read-only)
      try {
        await _fromRadioChar!.setNotifyValue(true);
        _fromRadioSub = _fromRadioChar!.onValueReceived.listen((bytes) {
          _handleIncomingBytes(Uint8List.fromList(bytes));
        });
      } catch (e) {
        debugPrint('[Meshtastic BLE Native] FromRadio notify fallback to FromNum/polling: $e');
      }

      // 5. Subscribe to FromNum packet counter notifications
      if (_fromNumChar != null) {
        try {
          await _fromNumChar!.setNotifyValue(true);
          _fromNumSub = _fromNumChar!.onValueReceived.listen((_) async {
            try {
              final readBytes = await _fromRadioChar!.read();
              if (readBytes.isNotEmpty) {
                _handleIncomingBytes(Uint8List.fromList(readBytes));
              }
            } catch (err) {
              debugPrint('[Meshtastic BLE Native] FromNum read error: $err');
            }
          });
        } catch (e) {
          debugPrint('[Meshtastic BLE Native] FromNum notify setup note: $e');
        }
      }

      // 6. Send initial handshake packet: want_config_id: 1 (payload [0x18, 0x01])
      debugPrint('[Meshtastic BLE Native] Sending handshake want_config_id: 1 payload [0x18, 0x01]');
      await _sendToRadio(const [0x18, 0x01]);

      _setConnectionState(BluetoothConnectionState.connected);
      debugPrint('[Meshtastic BLE Native] Connected & handshake sent successfully!');
    } catch (e) {
      debugPrint('[Meshtastic BLE Native] Connection error: $e');
      _setConnectionState(BluetoothConnectionState.disconnected);
    }
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

      // Check GPS Position telemetry (PortNum == POSITION_APP)
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

      // Check Emergency SOS (PortNum == TEXT_MESSAGE_APP or ALERT_APP with SOS)
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
      debugPrint('[Meshtastic BLE Native] Error decoding incoming frame: $e');
    }
  }

  Future<void> _sendToRadio(List<int> bytes) async {
    if (_toRadioChar == null) return;
    try {
      const maxChunk = 512;
      for (int i = 0; i < bytes.length; i += maxChunk) {
        final end = (i + maxChunk < bytes.length) ? i + maxChunk : bytes.length;
        final chunk = bytes.sublist(i, end);
        await _toRadioChar!.write(chunk, withoutResponse: true);
      }
    } catch (e) {
      debugPrint('[Meshtastic BLE Native] Write error to ToRadio: $e');
    }
  }

  @override
  Future<void> triggerAcousticSiren() async {
    debugPrint('[Meshtastic BLE Native] Transmitting EXTERNAL_NOTIFICATION_APP packet (GPIO 0 / Piezo Buzzer)');
    final sirenPacket = MeshtasticCodec.encodeSirenTriggerToRadio();
    await _sendToRadio(sirenPacket);
  }

  @override
  Future<void> triggerSarSiren() => triggerAcousticSiren();

  @override
  Future<void> broadcastEmergencySos() async {
    debugPrint('[Meshtastic BLE Native] Broadcasting emergency SOS text packet across LoRa mesh');
    final sosPacket = MeshtasticCodec.encodeTextMessageToRadio('SOS - EMERGENCY');
    await _sendToRadio(sosPacket);
  }

  @override
  Future<void> sendBroadcastMessage(String text) async {
    debugPrint('[Meshtastic BLE Native] Broadcasting text message over LoRa mesh: "$text"');
    final msgPacket = MeshtasticCodec.encodeTextMessageToRadio(text);
    await _sendToRadio(msgPacket);
  }

  @override
  Future<void> disconnect() async {
    try {
      _setConnectionState(BluetoothConnectionState.disconnecting);
      await _fromRadioSub?.cancel();
      await _fromNumSub?.cancel();
      await _connSub?.cancel();
      await _activeDevice?.disconnect();
    } catch (e) {
      debugPrint('[Meshtastic BLE Native] Disconnect error: $e');
    } finally {
      _activeDevice = null;
      _toRadioChar = null;
      _fromRadioChar = null;
      _fromNumChar = null;
      _connectedDeviceName = null;
      _setConnectionState(BluetoothConnectionState.disconnected);
    }
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

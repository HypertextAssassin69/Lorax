import 'dart:async';
import 'dart:ui';
import 'package:uuid/uuid.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/models/device.dart';
import 'package:rescue_link/models/emergency_event.dart';
import 'package:rescue_link/models/location_data.dart';
import 'package:rescue_link/models/network_node.dart';
import 'package:rescue_link/models/packet.dart';

/// Production Hardware Node Manager
/// Maintains live, reactive state for physical Meshtastic LoRa nodes.
/// Starts completely empty — zero mock data, zero simulated coordinates.
class HardwareNodeManager {
  HardwareNodeManager();

  final Map<String, Device> _devices = {};
  final List<NetworkNode> _nodes = [];
  final List<EmergencyEvent> _emergencyEvents = [];
  final Map<String, List<String>> _routes = {};

  final StreamController<List<Device>> _devicesController =
      StreamController<List<Device>>.broadcast();
  final StreamController<List<EmergencyEvent>> _emergencyController =
      StreamController<List<EmergencyEvent>>.broadcast();
  final StreamController<List<NetworkNode>> _networkController =
      StreamController<List<NetworkNode>>.broadcast();

  Stream<List<Device>> get devicesStream async* {
    yield currentDevices;
    yield* _devicesController.stream;
  }

  Stream<List<EmergencyEvent>> get emergencyStream async* {
    yield currentEmergencies;
    yield* _emergencyController.stream;
  }

  Stream<List<NetworkNode>> get networkStream async* {
    yield currentNodes;
    yield* _networkController.stream;
  }

  List<Device> get currentDevices => _devices.values.toList();
  List<EmergencyEvent> get currentEmergencies =>
      List.unmodifiable(_emergencyEvents);
  List<NetworkNode> get currentNodes => List.unmodifiable(_nodes);

  Device? getDevice(String id) => _devices[id];

  List<String> routeFor(String deviceId) {
    return List<String>.from(_routes[deviceId] ?? [deviceId]);
  }

  /// Ingests live telemetry packets received from physical Meshtastic LoRa nodes
  void ingestHardwareTelemetry({
    required String deviceId,
    required double latitude,
    required double longitude,
    double altitude = 0.0,
    int batteryLevel = 100,
    int satellites = 0,
    bool isSos = false,
    bool isCrash = false,
    int? rssi,
    double? snr,
    String? riderName,
  }) {
    final now = DateTime.now();

    SafetyStatus safety = SafetyStatus.safe;
    if (isSos) {
      safety = SafetyStatus.sosActive;
    } else if (isCrash) {
      safety = SafetyStatus.crashDetected;
    } else if (batteryLevel < 15) {
      safety = SafetyStatus.safe;
    }

    final loc = LocationData(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      timestamp: now,
      accuracy: 5.0,
      satellites: satellites,
      fixStatus: satellites >= 4 ? GpsFixStatus.fix3D : GpsFixStatus.fix2D,
    );

    final existing = _devices[deviceId];
    final updatedDevice = Device(
      id: deviceId,
      type: DeviceType.bikeNode,
      riderName: riderName ?? existing?.riderName ?? 'Operator ($deviceId)',
      batteryLevel: batteryLevel,
      status: DeviceStatus.active,
      safetyStatus: isSos || isCrash
          ? safety
          : (existing?.safetyStatus ?? SafetyStatus.safe),
      location: loc,
      rssi: rssi ?? existing?.rssi,
      snr: snr ?? existing?.snr,
      hopCount: existing?.hopCount ?? 0,
      lastSeen: now,
      isBluetoothConnected: true,
      firmwareVersion: '2.5.0-ESP32-C6',
    );

    _devices[deviceId] = updatedDevice;
    if (!_routes.containsKey(deviceId)) {
      _routes[deviceId] = [deviceId];
    }

    // Sync network node representation
    final nodeIndex = _nodes.indexWhere((n) => n.id == deviceId);
    final netNode = NetworkNode(
      id: deviceId,
      type: DeviceType.bikeNode,
      label: updatedDevice.riderName ?? deviceId,
      status: DeviceStatus.active,
      batteryLevel: batteryLevel,
      rssi: rssi,
      snr: snr,
      hopCount: updatedDevice.hopCount,
      lastSeen: now,
      connections: const [],
      position: Offset(latitude, longitude),
    );

    if (nodeIndex >= 0) {
      _nodes[nodeIndex] = netNode;
    } else {
      _nodes.add(netNode);
    }

    // Handle emergency creation if triggered by physical button or sensor
    if (isSos || isCrash) {
      final emergencyType =
          isSos ? EmergencyType.manualSos : EmergencyType.crashDetected;

      // Only add new event if no unacknowledged event for this device and type exists in the last 15s
      final recentEvent = _emergencyEvents.where((e) =>
          e.deviceId == deviceId &&
          e.type == emergencyType &&
          !e.acknowledged &&
          now.difference(e.timestamp).inSeconds < 15).firstOrNull;

      if (recentEvent == null) {
        final event = EmergencyEvent(
          id: const Uuid().v4(),
          packetId: const Uuid().v4(),
          type: emergencyType,
          deviceId: deviceId,
          riderName: updatedDevice.riderName,
          location: loc,
          timestamp: now,
          batteryLevel: batteryLevel,
          deliveryStatus: PacketState.delivered,
          route: [deviceId],
          acknowledged: false,
        );
        _emergencyEvents.insert(0, event);
      }
    }

    _emitUpdates();
  }

  void addDevice(Device device, {List<String>? route}) {
    _devices[device.id] = device;
    _routes[device.id] = route ?? [device.id];
    final loc = device.location;
    _nodes.removeWhere((n) => n.id == device.id);
    _nodes.insert(
      0,
      NetworkNode(
        id: device.id,
        type: device.type,
        label: device.riderName ?? device.id,
        status: device.status,
        batteryLevel: device.batteryLevel,
        rssi: device.rssi,
        snr: device.snr,
        hopCount: device.hopCount,
        lastSeen: device.lastSeen,
        connections: const [],
        position: loc == null
            ? const Offset(0, 0)
            : Offset(loc.latitude, loc.longitude),
      ),
    );
    _emitUpdates();
  }

  void removeDevice(String deviceId) {
    _devices.remove(deviceId);
    _routes.remove(deviceId);
    _nodes.removeWhere((n) => n.id == deviceId);
    _emitUpdates();
  }

  Packet buildEmergencyPacket({
    required String deviceId,
    required PacketType packetType,
    required PacketPriority priority,
    required SafetyStatus safetyStatus,
    bool forceFailure = false,
  }) {
    final dev = _devices[deviceId];
    final now = DateTime.now();
    return Packet(
      packetId: const Uuid().v4(),
      deviceId: deviceId,
      type: packetType,
      timestamp: now,
      latitude: dev?.location?.latitude,
      longitude: dev?.location?.longitude,
      batteryLevel: dev?.batteryLevel ?? 100,
      hopCount: 0,
      ttl: 3,
      priority: priority,
      state: forceFailure ? PacketState.failed : PacketState.delivered,
      source: deviceId,
      destination: 'BROADCAST',
      route: [deviceId],
      safetyStatus: safetyStatus,
      payload: {
        'safetyStatus': safetyStatus.name,
        'battery': dev?.batteryLevel ?? 100,
        'lat': dev?.location?.latitude ?? 0.0,
        'lng': dev?.location?.longitude ?? 0.0,
      },
    );
  }

  void registerEmergency({
    required Packet packet,
    required EmergencyType type,
  }) {
    final dev = _devices[packet.deviceId];
    final now = DateTime.now();

    final event = EmergencyEvent(
      id: const Uuid().v4(),
      packetId: packet.packetId,
      type: type,
      deviceId: packet.deviceId,
      riderName: dev?.riderName ?? packet.deviceId,
      location: dev?.location,
      timestamp: now,
      batteryLevel: dev?.batteryLevel ?? 100,
      deliveryStatus: packet.state,
      route: packet.route,
      acknowledged: false,
    );

    _emergencyEvents.insert(0, event);

    if (dev != null) {
      _devices[packet.deviceId] = dev.copyWith(
        safetyStatus: type == EmergencyType.crashDetected
            ? SafetyStatus.crashDetected
            : SafetyStatus.sosActive,
      );
    }

    _emitUpdates();
  }

  void acknowledgeEmergency(String eventId) {
    final index = _emergencyEvents.indexWhere((e) => e.id == eventId);
    if (index >= 0) {
      final ev = _emergencyEvents[index];
      _emergencyEvents[index] = ev.copyWith(acknowledged: true);

      final dev = _devices[ev.deviceId];
      if (dev != null) {
        final hasOtherActive = _emergencyEvents.any(
          (e) => e.deviceId == ev.deviceId && !e.acknowledged && e.id != eventId,
        );
        if (!hasOtherActive) {
          _devices[ev.deviceId] = dev.copyWith(safetyStatus: SafetyStatus.safe);
        }
      }
      _emitUpdates();
    }
  }

  void clearEvents() {
    _emergencyEvents.clear();
    for (final id in _devices.keys) {
      final dev = _devices[id]!;
      if (dev.status == DeviceStatus.active) {
        _devices[id] = dev.copyWith(safetyStatus: SafetyStatus.safe);
      }
    }
    _emitUpdates();
  }

  void _emitUpdates() {
    if (!_devicesController.isClosed) {
      _devicesController.add(currentDevices);
    }
    if (!_emergencyController.isClosed) {
      _emergencyController.add(currentEmergencies);
    }
    if (!_networkController.isClosed) {
      _networkController.add(currentNodes);
    }
  }

  void dispose() {
    _devicesController.close();
    _emergencyController.close();
    _networkController.close();
  }
}

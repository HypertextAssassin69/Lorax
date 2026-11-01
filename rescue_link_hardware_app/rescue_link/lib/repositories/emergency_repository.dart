import 'dart:async';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/models/emergency_event.dart';
import 'package:rescue_link/models/packet.dart';
import 'package:rescue_link/services/bluetooth/bluetooth_service.dart';
import 'package:rescue_link/services/hardware/hardware_node_manager.dart';
import 'package:rescue_link/services/storage/storage_service.dart';

class EmergencyRepository {
  EmergencyRepository({
    required this.bluetooth,
    required this.hardwareManager,
    required this.storage,
  });

  final BluetoothService bluetooth;
  final HardwareNodeManager hardwareManager;
  final StorageService storage;

  Stream<List<EmergencyEvent>> get eventsStream => hardwareManager.emergencyStream;
  List<EmergencyEvent> get currentEvents => hardwareManager.currentEmergencies;

  Stream<Packet> sendSos(String deviceId, {bool forceFailure = false}) {
    return _sendEmergency(
      deviceId: deviceId,
      packetType: PacketType.sos,
      emergencyType: EmergencyType.manualSos,
      priority: PacketPriority.critical,
      safety: SafetyStatus.sosActive,
      forceFailure: forceFailure,
    );
  }

  Stream<Packet> sendCrash(String deviceId, {bool forceFailure = false}) {
    return _sendEmergency(
      deviceId: deviceId,
      packetType: PacketType.crash,
      emergencyType: EmergencyType.crashDetected,
      priority: PacketPriority.critical,
      safety: SafetyStatus.crashDetected,
      forceFailure: forceFailure,
    );
  }

  Stream<Packet> _sendEmergency({
    required String deviceId,
    required PacketType packetType,
    required EmergencyType emergencyType,
    required PacketPriority priority,
    required SafetyStatus safety,
    bool forceFailure = false,
  }) {
    final controller = StreamController<Packet>();
    final packet = hardwareManager.buildEmergencyPacket(
      deviceId: deviceId,
      packetType: packetType,
      priority: priority,
      safetyStatus: safety,
      forceFailure: forceFailure,
    );
    hardwareManager.registerEmergency(packet: packet, type: emergencyType);
    controller.add(packet);

    late final StreamSubscription<Packet> sub;
    sub = bluetooth.packetStream.listen((update) {
      if (update.packetId != packet.packetId) return;
      if (!controller.isClosed) {
        controller.add(update);
      }
      if (update.state == PacketState.delivered || update.state == PacketState.failed) {
        sub.cancel();
        if (!controller.isClosed) {
          controller.close();
        }
        _persist();
      }
    });

    bluetooth.sendPacket(packet).whenComplete(() {
      _persist();
    });

    return controller.stream;
  }

  Future<void> acknowledge(String eventId) async {
    hardwareManager.acknowledgeEmergency(eventId);
    await _persist();
  }

  Future<void> _persist() async {
    await storage.saveEmergencyHistory(hardwareManager.currentEmergencies);
  }
}

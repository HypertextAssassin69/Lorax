import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/services/hardware/hardware_node_manager.dart';

void main() {
  group('HardwareNodeManager Production Tests', () {
    late HardwareNodeManager manager;

    setUp(() {
      manager = HardwareNodeManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('Initializes with zero devices, zero nodes, zero emergencies', () {
      expect(manager.currentDevices.isEmpty, isTrue);
      expect(manager.currentNodes.isEmpty, isTrue);
      expect(manager.currentEmergencies.isEmpty, isTrue);
    });

    test('Ingesting live telemetry creates device and network node dynamically', () {
      manager.ingestHardwareTelemetry(
        deviceId: 'Meshtastic_af88',
        latitude: 31.7640,
        longitude: 76.9860,
        altitude: 450.0,
        batteryLevel: 94,
        satellites: 8,
        rssi: -72,
        snr: 8.5,
      );

      expect(manager.currentDevices.length, 1);
      final dev = manager.getDevice('Meshtastic_af88');
      expect(dev, isNotNull);
      expect(dev!.id, 'Meshtastic_af88');
      expect(dev.location?.latitude, 31.7640);
      expect(dev.location?.longitude, 76.9860);
      expect(dev.location?.altitude, 450.0);
      expect(dev.location?.satellites, 8);
      expect(dev.batteryLevel, 94);
      expect(dev.rssi, -72);
      expect(dev.snr, 8.5);
      expect(dev.safetyStatus, SafetyStatus.safe);

      expect(manager.currentNodes.length, 1);
      final node = manager.currentNodes.first;
      expect(node.id, 'Meshtastic_af88');
      expect(node.status, DeviceStatus.active);
    });

    test('Ingesting SOS telemetry creates emergency event and activates SOS', () {
      manager.ingestHardwareTelemetry(
        deviceId: 'Meshtastic_af88',
        latitude: 31.7640,
        longitude: 76.9860,
        isSos: true,
      );

      final dev = manager.getDevice('Meshtastic_af88');
      expect(dev?.safetyStatus, SafetyStatus.sosActive);

      expect(manager.currentEmergencies.length, 1);
      final ev = manager.currentEmergencies.first;
      expect(ev.type, EmergencyType.manualSos);
      expect(ev.deviceId, 'Meshtastic_af88');
      expect(ev.acknowledged, isFalse);
    });

    test('Acknowledging emergency restores safe status', () {
      manager.ingestHardwareTelemetry(
        deviceId: 'Meshtastic_af88',
        latitude: 31.7640,
        longitude: 76.9860,
        isSos: true,
      );

      final ev = manager.currentEmergencies.first;
      manager.acknowledgeEmergency(ev.id);

      final updatedEv = manager.currentEmergencies.first;
      expect(updatedEv.acknowledged, isTrue);

      final dev = manager.getDevice('Meshtastic_af88');
      expect(dev?.safetyStatus, SafetyStatus.safe);
    });
  });
}

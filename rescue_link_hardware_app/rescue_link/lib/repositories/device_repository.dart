import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/models/device.dart';
import 'package:rescue_link/models/location_data.dart';
import 'package:rescue_link/services/hardware/hardware_node_manager.dart';
import 'package:rescue_link/services/storage/storage_service.dart';

class DeviceRepository {
  DeviceRepository({
    required this.hardwareManager,
    required this.storage,
  });

  final HardwareNodeManager hardwareManager;
  final StorageService storage;

  Stream<List<Device>> get devicesStream => hardwareManager.devicesStream;
  List<Device> get currentDevices => hardwareManager.currentDevices;
  Device? getDevice(String id) => hardwareManager.getDevice(id);

  Future<void> addBike({
    required String id,
    required String riderName,
  }) async {
    final now = DateTime.now();
    hardwareManager.addDevice(
      Device(
        id: id,
        type: DeviceType.bikeNode,
        riderName: riderName,
        batteryLevel: 100,
        status: DeviceStatus.active,
        safetyStatus: SafetyStatus.safe,
        location: LocationData(
          latitude: 0.0,
          longitude: 0.0,
          altitude: 0,
          timestamp: now,
          accuracy: 5,
          satellites: 0,
          fixStatus: GpsFixStatus.noFix,
        ),
        rssi: -70,
        snr: 8.0,
        hopCount: 0,
        lastSeen: now,
        firmwareVersion: '2.5.0-ESP32-C6',
      ),
    );
    await storage.saveDevices(hardwareManager.currentDevices);
  }

  Future<void> removeDevice(String id) async {
    hardwareManager.removeDevice(id);
    await storage.saveDevices(hardwareManager.currentDevices);
  }
}

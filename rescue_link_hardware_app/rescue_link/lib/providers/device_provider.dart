import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rescue_link/models/device.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';

final devicesProvider = StreamProvider<List<Device>>((ref) {
  return ref.watch(deviceRepositoryProvider).devicesStream;
});

final activeDeviceIdProvider = StateProvider<String>((ref) => '');

final activeDeviceProvider = Provider<Device?>((ref) {
  final devices = ref.watch(devicesProvider).valueOrNull;
  final activeId = ref.watch(activeDeviceIdProvider);
  if (devices == null || devices.isEmpty) return null;
  if (activeId.isNotEmpty) {
    final matched = devices.where((d) => d.id == activeId).firstOrNull;
    if (matched != null) return matched;
  }
  return devices.first;
});

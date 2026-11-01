import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rescue_link/models/network_node.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/providers/device_provider.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';

class NetworkStats {
  final int totalNodes;
  final int activeNodes;
  final int esp32Nodes;
  final int emergencyNodes;
  final double averageRssi;
  final double averageSnr;

  const NetworkStats({
    required this.totalNodes,
    required this.activeNodes,
    required this.esp32Nodes,
    required this.emergencyNodes,
    required this.averageRssi,
    required this.averageSnr,
  });
}

double _calculateAvgRssi(List<NetworkNode> nodes) {
  if (nodes.isEmpty) return 0.0;
  final sum = nodes.fold<double>(0, (prev, node) => prev + (node.rssi ?? 0));
  return sum / nodes.length;
}

double _calculateAvgSnr(List<NetworkNode> nodes) {
  if (nodes.isEmpty) return 0.0;
  final sum = nodes.fold<double>(0, (prev, node) => prev + (node.snr ?? 0.0));
  return sum / nodes.length;
}

final networkNodesProvider = StreamProvider<List<NetworkNode>>((ref) {
  return ref.watch(hardwareNodeManagerProvider).networkStream;
});

final networkStatsProvider = Provider<NetworkStats>((ref) {
  final nodes = ref.watch(networkNodesProvider).valueOrNull ?? [];
  final emergencyCount = nodes.where((n) {
    final device = ref.watch(devicesProvider).valueOrNull?.where((d) => d.id == n.id).firstOrNull;
    return device?.safetyStatus == SafetyStatus.sosActive ||
        device?.safetyStatus == SafetyStatus.crashDetected;
  }).length;
  return NetworkStats(
    totalNodes: nodes.length,
    activeNodes: nodes.where((n) => n.status == DeviceStatus.active).length,
    esp32Nodes: nodes.length,
    emergencyNodes: emergencyCount,
    averageRssi: _calculateAvgRssi(nodes),
    averageSnr: _calculateAvgSnr(nodes),
  );
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/core/utils/formatters.dart';
import 'package:rescue_link/models/network_node.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';
import 'package:rescue_link/providers/network_provider.dart';

class NetworkScreen extends ConsumerStatefulWidget {
  const NetworkScreen({super.key});

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleBroadcast() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref.read(meshtasticBleServiceProvider).sendBroadcastMessage(text);
      if (mounted) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.send, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Packet broadcasted to LoRa mesh (TEXT_MESSAGE_APP): "$text"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.secondaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(networkNodesProvider).valueOrNull ?? [];
    final stats = ref.watch(networkStatsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Broadcast Message Card
                _buildBroadcastCard(context),
                const SizedBox(height: 24),

                // Network Stats Row
                _buildStatsRow(context, stats),
                const SizedBox(height: 24),

                // Mesh Topology
                _buildSectionLabel(context, 'MESH TOPOLOGY'),
                const SizedBox(height: 16),
                _buildTopology(context, nodes),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBroadcastCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.cell_tower, color: AppTheme.secondaryColor, size: 22),
              SizedBox(width: 10),
              Text(
                'Broadcast Over LoRa Mesh',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Transmit unencrypted broadcast text to all Seeed Studio ESP32-C6 nodes within radio range (868 MHz).',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Enter SAR status, waypoint, or alert...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onSubmitted: (_) => _handleBroadcast(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 18),
              label: const Text(
                'TRANSMIT PACKET TO MESH',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8),
              ),
              onPressed: _isSending ? null : _handleBroadcast,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, NetworkStats stats) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'TOTAL NODES',
            value: stats.totalNodes.toString(),
            icon: Icons.hub,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'ACTIVE PEERS',
            value: stats.activeNodes.toString(),
            icon: Icons.wifi_tethering,
            color: AppTheme.safeColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'AVG SNR',
            value: stats.averageSnr > 0 ? '${stats.averageSnr.toStringAsFixed(1)} dB' : 'N/A',
            icon: Icons.show_chart,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _buildTopology(BuildContext context, List<NetworkNode> nodes) {
    if (nodes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.hub_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text(
                'No Mesh Topology Formed',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Heard ESP32-C6 nodes will dynamically appear here when telemetry packets are exchanged.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<Widget> topology = [];
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      topology.add(_NodeTile(
        node: node,
        icon: Icons.memory,
        nodeType: 'ESP32-C6 NODE',
      ));
      if (i < nodes.length - 1) {
        topology.add(const _ConnectorLine());
      }
    }

    return Column(children: topology);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  final NetworkNode node;
  final IconData icon;
  final String nodeType;

  const _NodeTile({
    required this.node,
    required this.icon,
    required this.nodeType,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = node.status == DeviceStatus.active;
    final color = isOnline ? AppTheme.safeColor : AppTheme.offlineColor;

    final rssiStr = node.rssi != null && node.rssi != 0 ? '${node.rssi} dBm' : null;
    final snrStr = node.snr != null && node.snr != 0 ? '${node.snr!.toStringAsFixed(1)} dB' : null;
    final battStr = node.batteryLevel != null ? '${node.batteryLevel}%' : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.label,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isOnline ? 'ACTIVE' : 'OFFLINE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (battStr != null) ...[
                Text('Batt: $battStr', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 14),
              ],
              if (rssiStr != null) ...[
                Text('RSSI: $rssiStr', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 14),
              ],
              if (snrStr != null)
                Text('SNR: $snrStr', style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text(
                node.lastSeen != null ? Formatters.formatTimeAgo(node.lastSeen!) : 'Just now',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  const _ConnectorLine();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(width: 2, height: 16, color: AppTheme.secondaryColor.withValues(alpha: 0.4)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.arrow_downward, size: 14, color: AppTheme.secondaryColor),
          ],
        ),
        Container(width: 2, height: 16, color: AppTheme.secondaryColor.withValues(alpha: 0.4)),
      ],
    );
  }
}

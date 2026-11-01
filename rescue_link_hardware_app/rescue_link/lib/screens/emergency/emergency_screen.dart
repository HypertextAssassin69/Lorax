import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/core/utils/formatters.dart';
import 'package:rescue_link/models/emergency_event.dart';
import 'package:rescue_link/providers/emergency_provider.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  void _showConfirmSos(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.emergencyRed),
            SizedBox(width: 8),
            Text('Broadcast Mesh SOS'),
          ],
        ),
        content: const Text(
          'This will transmit an emergency SOS alert across the LoRa mesh network to all search and rescue nodes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emergencyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(meshtasticBleServiceProvider).broadcastEmergencySos();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚨 Emergency SOS Broadcasted to Mesh!'),
                    backgroundColor: AppTheme.emergencyRed,
                  ),
                );
              }
            },
            child: const Text('BROADCAST NOW'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencies = ref.watch(emergencyEventsProvider).valueOrNull ?? [];

    final sorted = List<EmergencyEvent>.from(emergencies)
      ..sort((a, b) {
        if (a.acknowledged != b.acknowledged) return a.acknowledged ? 1 : -1;
        return b.timestamp.compareTo(a.timestamp);
      });

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.emergencyRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.warning_amber),
        label: const Text('BROADCAST SOS', style: TextStyle(fontWeight: FontWeight.w900)),
        onPressed: () => _showConfirmSos(context, ref),
      ),
      body: sorted.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: sorted.length,
              itemBuilder: (context, index) => _EmergencyCard(event: sorted[index]),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: AppTheme.safeColor.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            const Text(
              'No Active Emergencies',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'No SOS broadcasts or crash detections detected across the LoRa mesh network.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emergencyRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.warning),
              label: const Text('MANUAL SOS BROADCAST', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showConfirmSos(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends ConsumerWidget {
  final EmergencyEvent event;

  const _EmergencyCard({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = !event.acknowledged;
    final color = isActive ? AppTheme.emergencyRed : AppTheme.offlineColor;

    final riderStr = event.riderName != null && event.riderName!.isNotEmpty
        ? '${event.riderName} \u2022 ${event.deviceId}'
        : event.deviceId;

    final locationStr = event.location != null
        ? event.location!.displayString
        : 'No location data';

    final batteryStr = event.batteryLevel != null
        ? '${event.batteryLevel}%'
        : 'N/A';

    String? badge;
    Color? badgeColor;
    if (!isActive) {
      badge = 'ACKNOWLEDGED';
      badgeColor = AppTheme.offlineColor;
    } else if (event.deliveryStatus == PacketState.queued) {
      badge = 'QUEUED';
      badgeColor = AppTheme.warningColor;
    } else if (event.deliveryStatus == PacketState.delivered) {
      badge = 'DELIVERED';
      badgeColor = AppTheme.safeColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.04) : Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.3) : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.warning_rounded : Icons.check_circle_outlined,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  Formatters.formatEmergencyType(event.type).toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor!.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badgeColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _detail(context, Icons.person, riderStr),
          const SizedBox(height: 6),
          _detail(context, Icons.schedule, Formatters.formatTimeAgo(event.timestamp)),
          const SizedBox(height: 6),
          _detail(context, Icons.location_on_outlined, locationStr),
          const SizedBox(height: 6),
          _detail(context, Icons.battery_std, 'Battery: $batteryStr'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/map'),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('View on Map', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emergencyRed,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ref.read(emergencyRepositoryProvider).acknowledge(event.id);
                    },
                    child: const Text('Acknowledge', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningColor,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.campaign, size: 20),
                label: const Text('SOUND SAR SIREN (BUZZER)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                onPressed: () {
                  ref.read(meshtasticBleServiceProvider).triggerAcousticSiren();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔊 SAR Siren Signal Sent to Node (GPIO 0 Buzzer)!'),
                      backgroundColor: AppTheme.warningColor,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

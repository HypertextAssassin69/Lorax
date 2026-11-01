import 'package:flutter/material.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/core/utils/formatters.dart';
import 'package:rescue_link/models/device.dart';
import 'package:rescue_link/widgets/battery_indicator.dart';
import 'package:rescue_link/widgets/connection_indicator.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData typeIcon = switch (device.type) {
      DeviceType.bikeNode => Icons.directions_bike,
    };

    final isOnline = device.status == DeviceStatus.active;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(typeIcon, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.id,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (device.type == DeviceType.bikeNode && device.riderName != null)
                          Text(
                            device.riderName!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                  ConnectionIndicator(isConnected: isOnline),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BatteryIndicator(batteryLevel: device.batteryLevel),
                  Row(
                    children: [
                      const Icon(Icons.signal_cellular_alt, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${device.rssi ?? 0} dBm'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Last seen: ${Formatters.formatTimeAgo(device.lastSeen)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

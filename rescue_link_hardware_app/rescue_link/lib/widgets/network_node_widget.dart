import 'package:flutter/material.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/models/network_node.dart';
import 'package:rescue_link/widgets/battery_indicator.dart';

class NetworkNodeWidget extends StatelessWidget {
  final NetworkNode node;

  const NetworkNodeWidget({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    IconData icon = switch (node.type) {
      DeviceType.bikeNode => Icons.directions_bike,
    };

    final bool isActive = node.status == DeviceStatus.active;
    final color = isActive ? AppTheme.safeColor : AppTheme.offlineColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          node.id,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        if (node.batteryLevel != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: BatteryIndicator(batteryLevel: node.batteryLevel!),
          ),
      ],
    );
  }
}

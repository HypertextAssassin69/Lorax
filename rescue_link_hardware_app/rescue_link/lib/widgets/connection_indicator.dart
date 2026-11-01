import 'package:flutter/material.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/models/bluetooth_status.dart';

class ConnectionIndicator extends StatelessWidget {
  final bool isConnected;
  final String? label;

  const ConnectionIndicator({
    super.key,
    required this.isConnected,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppTheme.safeColor : AppTheme.criticalColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 8),
          Text(
            label!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ],
    );
  }
}

class BluetoothStatusBar extends StatelessWidget {
  final BluetoothStatus status;

  const BluetoothStatusBar({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ConnectionIndicator(
            isConnected: status.isConnected,
            label: status.isConnected ? 'Device Connected' : 'Device Offline',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.mode.name.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

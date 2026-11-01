import 'package:flutter/material.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/core/utils/formatters.dart';
import 'package:rescue_link/models/emergency_event.dart';

class EmergencyCard extends StatelessWidget {
  final EmergencyEvent event;
  final VoidCallback? onTap;

  const EmergencyCard({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = event.deliveryStatus != PacketState.delivered; 
    
    return Card(
      elevation: isActive ? 4 : 1,
      color: isActive ? AppTheme.criticalColor.withValues(alpha: 0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? AppTheme.criticalColor : Colors.transparent,
          width: 1.5,
        ),
      ),
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
                  Icon(
                    event.type == EmergencyType.manualSos ? Icons.sos : Icons.warning,
                    color: isActive ? AppTheme.criticalColor : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.type.name.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isActive ? AppTheme.criticalColor : null,
                          ),
                    ),
                  ),
                  Text(
                    Formatters.formatTime(event.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Device ID: ${event.deviceId}'),
              if (event.riderName != null) Text('Rider: ${event.riderName}'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    event.deliveryStatus == PacketState.delivered ? Icons.done_all : Icons.pending,
                    size: 16,
                    color: event.deliveryStatus == PacketState.delivered ? AppTheme.safeColor : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    event.deliveryStatus == PacketState.delivered ? 'Delivered' : 'Pending',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

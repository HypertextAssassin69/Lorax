import 'package:flutter/material.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/core/theme/app_theme.dart';

class PacketRouteWidget extends StatelessWidget {
  final List<String> route;
  final PacketState currentState;
  final int currentHopIndex;

  const PacketRouteWidget({
    super.key,
    required this.route,
    required this.currentState,
    required this.currentHopIndex,
  });

  IconData _getIconForNodeId(String id) {
    final upperId = id.toUpperCase();
    if (upperId.startsWith('BIKE')) return Icons.directions_bike;
    if (upperId.contains('ESP32')) return Icons.developer_board;
    if (upperId.startsWith('APP')) return Icons.smartphone;
    return Icons.device_unknown;
  }

  @override
  Widget build(BuildContext context) {
    if (route.isEmpty) {
      return const Text('No route available');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: route.length,
      itemBuilder: (context, index) {
        final nodeId = route[index];
        final isLast = index == route.length - 1;
        final isCompleted = index < currentHopIndex || (index == currentHopIndex && currentState == PacketState.delivered);
        final isCurrent = index == currentHopIndex && currentState != PacketState.delivered;

        Color nodeColor = Colors.grey;
        if (isCompleted) nodeColor = AppTheme.safeColor;
        if (isCurrent) nodeColor = AppTheme.warningColor; 

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: nodeColor.withValues(alpha: 0.1),
                      border: Border.all(color: nodeColor, width: 2),
                    ),
                    child: isCompleted
                        ? Icon(Icons.check, size: 16, color: nodeColor)
                        : isCurrent
                            ? const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(_getIconForNodeId(nodeId), size: 16, color: nodeColor),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isCompleted ? AppTheme.safeColor : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 4.0),
                  child: Text(
                    nodeId,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCompleted || isCurrent
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.grey,
                        ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

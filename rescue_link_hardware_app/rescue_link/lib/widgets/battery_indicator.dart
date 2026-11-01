import 'package:flutter/material.dart';

class BatteryIndicator extends StatelessWidget {
  final int batteryLevel;

  const BatteryIndicator({super.key, required this.batteryLevel});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    if (batteryLevel > 60) {
      color = Colors.green;
      icon = Icons.battery_full;
    } else if (batteryLevel >= 20) {
      color = Colors.amber;
      icon = Icons.battery_4_bar;
    } else if (batteryLevel >= 10) {
      color = Colors.orange;
      icon = Icons.battery_2_bar;
    } else {
      color = Colors.red;
      icon = Icons.battery_alert;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          '$batteryLevel%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

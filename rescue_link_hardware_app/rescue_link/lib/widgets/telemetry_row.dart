import 'package:flutter/material.dart';
import 'package:rescue_link/core/theme/app_theme.dart';

class TelemetryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const TelemetryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.slateCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.slateBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.cyberCyan),
          const SizedBox(width: 10),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
              color: valueColor ?? AppTheme.emeraldGreen,
            ),
          ),
        ],
      ),
    );
  }
}

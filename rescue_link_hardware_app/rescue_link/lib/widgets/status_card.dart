import 'package:flutter/material.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/core/theme/app_theme.dart';

class SafetyStatusCard extends StatefulWidget {
  final SafetyStatus status;

  const SafetyStatusCard({super.key, required this.status});

  @override
  State<SafetyStatusCard> createState() => _SafetyStatusCardState();
}

class _SafetyStatusCardState extends State<SafetyStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.status == SafetyStatus.sosActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SafetyStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == SafetyStatus.sosActive &&
        oldWidget.status != SafetyStatus.sosActive) {
      _controller.repeat(reverse: true);
    } else if (widget.status != SafetyStatus.sosActive &&
        oldWidget.status == SafetyStatus.sosActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (widget.status) {
      SafetyStatus.safe => (AppTheme.safeColor, Icons.check_circle, 'SAFE'),
      SafetyStatus.sosActive => (AppTheme.criticalColor, Icons.sos, 'SOS ACTIVE'),
      SafetyStatus.crashDetected => (
          AppTheme.warningColor,
          Icons.warning_amber_rounded,
          'CRASH DETECTED'
        ),
      SafetyStatus.offline => (AppTheme.offlineColor, Icons.cloud_off, 'OFFLINE'),
      SafetyStatus.unknown => (AppTheme.offlineColor, Icons.help_outline, 'UNKNOWN'),
    };

    Widget card = Card(
      elevation: 0,
      color: color.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );

    if (widget.status == SafetyStatus.sosActive) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: card,
      );
    }

    return card;
  }
}

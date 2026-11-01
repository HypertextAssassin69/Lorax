import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rescue_link/core/theme/app_theme.dart';

class SosButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Duration holdDuration;

  const SosButton({
    super.key,
    required this.onPressed,
    this.holdDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _holdController;
  late Animation<double> _pulseAnimation;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _holdController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          widget.onPressed();
          _holdController.reset();
          if (mounted) setState(() => _isHolding = false);
        }
      });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    setState(() => _isHolding = true);
    HapticFeedback.selectionClick();
    _holdController.forward();
  }

  void _onPointerUp(PointerUpEvent _) {
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
    }
    setState(() => _isHolding = false);
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _holdController.reverse();
    setState(() => _isHolding = false);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _holdController]),
          builder: (context, child) {
            final holdProgress = _holdController.value;
            final scale = _isHolding ? 0.95 : _pulseAnimation.value;

            return Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing Tactical Radial Glow
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.crimsonRed.withValues(
                            alpha: _isHolding ? 0.8 : 0.35 * _pulseAnimation.value,
                          ),
                          blurRadius: _isHolding ? 35 : 24 * _pulseAnimation.value,
                          spreadRadius: _isHolding ? 10 : 6 * _pulseAnimation.value,
                        ),
                      ],
                    ),
                  ),

                  // Hold-to-trigger Progress Ring
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: holdProgress,
                      strokeWidth: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyberCyan),
                    ),
                  ),

                  // Core Tactile Button
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.crimsonRed,
                          Color.lerp(AppTheme.crimsonRed, Colors.black, 0.35)!,
                        ],
                      ),
                      border: Border.all(
                        color: _isHolding ? AppTheme.cyberCyan : Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                        const SizedBox(height: 2),
                        const Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          _isHolding ? 'HOLDING...' : 'HOLD FOR SOS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

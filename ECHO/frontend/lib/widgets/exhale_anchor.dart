import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'orb_widget.dart';

class ExhaleAnchor extends StatefulWidget {
  final VoidCallback onHoldStart;
  final VoidCallback onRelease;
  final Function(double) onHoldUpdate;

  const ExhaleAnchor({
    super.key,
    required this.onHoldStart,
    required this.onRelease,
    required this.onHoldUpdate,
  });

  @override
  State<ExhaleAnchor> createState() => _ExhaleAnchorState();
}

class _ExhaleAnchorState extends State<ExhaleAnchor>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _holdController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _holdController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInQuad,
    );

    _holdController.addListener(() {
      widget.onHoldUpdate(_holdController.value);
      _triggerHaptics(_holdController.value);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  void _triggerHaptics(double value) {
    if (value > 0.3 && value < 0.35) HapticFeedback.selectionClick();
    if (value > 0.6 && value < 0.65) HapticFeedback.mediumImpact();
    if (value > 0.9 && value < 0.95) HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        widget.onHoldStart();
        _holdController.forward();
      },
      onLongPressEnd: (_) {
        widget.onRelease();
        _holdController.reverse();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _scaleAnimation]),
        builder: (context, child) {
          final double holdValue = _scaleAnimation.value;
          final double pulseValue = Curves.easeInOut.transform(
            _pulseController.value,
          );
          return Transform.scale(
            scale:
                1.0 + (holdValue * 0.7) + (pulseValue * 0.12 * (1 - holdValue)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.05 + (holdValue * 0.3)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                OrbWidget(
                  size: 85,
                  intensity:
                      0.8 +
                      (holdValue * 0.2) +
                      (pulseValue * 0.1 * (1 - holdValue)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

class OrbWidget extends StatelessWidget {
  final double size;
  final double intensity;
  final double blurSigma; // For depth of field

  const OrbWidget({
    super.key,
    required this.size,
    this.intensity = 1.0,
    this.blurSigma = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFFE1F5FE).withValues(alpha: 0.95 * intensity),
              const Color(0xFF81D4FA).withValues(alpha: 0.4 * intensity),
            ],
            stops: const [0.1, 1.0],
            center: const Alignment(-0.2, -0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.5 * intensity),
              blurRadius: (30 + blurSigma * 5) * intensity,
              spreadRadius: 4 * intensity,
            ),
            BoxShadow(
              color: const Color(0xFF01579B).withValues(alpha: 0.15 * intensity),
              blurRadius: (60 + blurSigma * 10) * intensity,
              spreadRadius: 10 * intensity,
            ),
          ],
        ),
      ),
    );
  }
}

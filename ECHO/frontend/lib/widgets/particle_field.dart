import 'package:flutter/material.dart';

class ExhaleParticle {
  double x, y, vx, vy, size, life, opacity;
  double hue; // For color variation
  ExhaleParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.opacity,
    this.hue = 0.0,
  });
}

class ParticleField extends CustomPainter {
  final List<ExhaleParticle> particles;

  // Reusable paint objects out of the paint method
  static final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

  static final Paint _corePaint = Paint()..color = Colors.white;

  ParticleField(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      if (p.life <= 0) continue;

      final center = Offset(p.x * size.width, p.y * size.height);
      final lifeOpacity = p.life.clamp(0.0, 1.0) * p.opacity;

      // fast glow (simple blur, no gradient)
      _glowPaint.color = Color.lerp(
        Colors.white,
        Colors.blue.shade300,
        p.hue,
      )!.withValues(alpha: lifeOpacity * 0.4);

      canvas.drawCircle(center, p.size * 2.0, _glowPaint);

      // fast core
      _corePaint.color = Colors.white.withValues(alpha: lifeOpacity);
      canvas.drawCircle(center, p.size * 0.8, _corePaint);
    }
  }

  @override
  bool shouldRepaint(ParticleField oldDelegate) => true;
}

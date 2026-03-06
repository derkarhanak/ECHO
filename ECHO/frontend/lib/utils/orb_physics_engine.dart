import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/animation.dart';
import '../models/echo_orb.dart';

class OrbPhysicsEngine {
  final Random _random = Random();

  List<EchoOrb> initializeOrbs(int count) {
    List<EchoOrb> orbs = [];
    for (int i = 0; i < count; i++) {
      orbs.add(
        EchoOrb(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: _random.nextDouble() * 20 + 35,
          vx: (_random.nextDouble() - 0.5) * 0.01,
          vy: (_random.nextDouble() - 0.5) * 0.01,
          hue: _random.nextDouble(),
          z: _random.nextDouble(),
        ),
      );
    }
    orbs.sort((a, b) => a.z.compareTo(b.z));
    return orbs;
  }

  void updateOrbs({
    required List<EchoOrb> orbs,
    required ui.Size screenSize,
    required EchoOrb? caughtOrb,
    required bool isExhaleSphereExpanded,
    required AnimationController exhaleExpandController,
    required AnimationController implodeController,
    required Enum echoState,
  }) {
    if (screenSize.width == 0 || screenSize.height == 0) return;

    // 1. Convert to absolute pixel space
    List<_OrbPhysics> phys = orbs
        .map(
          (o) => _OrbPhysics(
            o,
            o.x * screenSize.width,
            o.y * screenSize.height,
            o.vx * screenSize.width,
            o.vy * screenSize.height,
            (o.size * (0.6 + (o.z * 0.4))) / 2,
          ),
        )
        .toList();

    // 2. Movement & Wall Bounce
    for (var p in phys) {
      if (p.orb == caughtOrb) continue;

      p.px += p.pvx;
      p.py += p.pvy;

      if (p.px < p.radius) {
        p.px = p.radius;
        p.pvx = -p.pvx;
      }
      if (p.px > screenSize.width - p.radius) {
        p.px = screenSize.width - p.radius;
        p.pvx = -p.pvx;
      }
      if (p.py < p.radius) {
        p.py = p.radius;
        p.pvy = -p.pvy;
      }
      if (p.py > screenSize.height - p.radius) {
        p.py = screenSize.height - p.radius;
        p.pvy = -p.pvy;
      }

      p.pvx *= 0.999;
      p.pvy *= 0.999;
    }

    // 3. Orb-Orb Elastic Collision
    for (int i = 0; i < phys.length; i++) {
      for (int j = i + 1; j < phys.length; j++) {
        var p1 = phys[i];
        var p2 = phys[j];
        if (p1.orb == caughtOrb || p2.orb == caughtOrb) continue;

        double dx = p2.px - p1.px;
        double dy = p2.py - p1.py;
        double dist = sqrt(dx * dx + dy * dy);

        // Added +10 padding to account for the visual blur extending past the core radius
        double minDist = p1.radius + p2.radius + 10.0;

        if (dist < minDist && dist > 0.001) {
          double nx = dx / dist;
          double ny = dy / dist;
          double overlap = minDist - dist;

          // Push apart
          p1.px -= nx * overlap * 0.5;
          p1.py -= ny * overlap * 0.5;
          p2.px += nx * overlap * 0.5;
          p2.py += ny * overlap * 0.5;

          // Transfer momentum
          double rvx = p2.pvx - p1.pvx;
          double rvy = p2.pvy - p1.pvy;
          double velAlongNormal = rvx * nx + rvy * ny;

          if (velAlongNormal < 0) {
            double impulse = -(1 + 1.0) * velAlongNormal / 2;
            p1.pvx -= impulse * nx;
            p1.pvy -= impulse * ny;
            p2.pvx += impulse * nx;
            p2.pvy += impulse * ny;
          }
        }
      }
    }

    // 3.5. Constellation Tethering (Spring Physics)
    for (int i = 0; i < phys.length; i++) {
      for (int j = i + 1; j < phys.length; j++) {
        var p1 = phys[i];
        var p2 = phys[j];

        // Skip if either orb is caught, or if they don't share a threadId
        if (p1.orb == caughtOrb || p2.orb == caughtOrb) continue;
        if (p1.orb.threadId == null || p1.orb.threadId != p2.orb.threadId) {
          continue;
        }

        double dx = p2.px - p1.px;
        double dy = p2.py - p1.py;
        double dist = sqrt(dx * dx + dy * dy);

        // Target distance for tethered orbs
        double targetDist = p1.radius + p2.radius + 60.0;

        if (dist > 0.001) {
          double force = (dist - targetDist) * 0.0005; // Spring constant

          double nx = dx / dist;
          double ny = dy / dist;

          // Apply pulling/pushing forces
          p1.pvx += nx * force;
          p1.pvy += ny * force;
          p2.pvx -= nx * force;
          p2.pvy -= ny * force;
        }
      }
    }

    // 4. Main Sphere Collision (The Anchor)
    double mainCx = screenSize.width / 2;
    double mainCy;
    double mainRadius;

    if (isExhaleSphereExpanded) {
      final double tExp = Curves.fastOutSlowIn.transform(
        exhaleExpandController.value,
      );
      final double tDissolve = Curves.easeOutSine.transform(
        implodeController.value,
      );

      double currentSize = ui.lerpDouble(85.0, 260.0, tExp)!;
      if (tDissolve > 0) {
        currentSize = ui.lerpDouble(currentSize, currentSize * 1.3, tDissolve)!;
      }
      mainRadius = currentSize / 2;

      mainCy = ui.lerpDouble(
        screenSize.height - 122.5,
        screenSize.height / 2,
        tExp,
      )!;
      if (tDissolve > 0) mainCy -= 150 * tDissolve;
    } else {
      mainRadius = 42.5; // Half of 85.0
      mainCy = screenSize.height - 122.5;
    }

    if (echoState.name != 'chatting' &&
        echoState.name != 'arrival' &&
        echoState.name != 'focused') {
      for (var p in phys) {
        if (p.orb == caughtOrb) continue;

        double dx = p.px - mainCx;
        double dy = p.py - mainCy;
        double dist = sqrt(dx * dx + dy * dy);

        // Added +20 padding to account for the heavy glow on the main anchor
        double minDist = p.radius + mainRadius + 20.0;

        if (dist < minDist && dist > 0.001) {
          double nx = dx / dist;
          double ny = dy / dist;
          double overlap = minDist - dist;

          p.px += nx * overlap;
          p.py += ny * overlap;

          double velAlongNormal = p.pvx * nx + p.pvy * ny;
          if (velAlongNormal < 0) {
            p.pvx -= 2 * velAlongNormal * nx;
            p.pvy -= 2 * velAlongNormal * ny;
          }

          if (isExhaleSphereExpanded && exhaleExpandController.isAnimating) {
            p.pvx += nx * 4.0;
            p.pvy += ny * 4.0;
          }
        }
      }
    }

    // 5. Commit back to normalized coordinates
    for (var p in phys) {
      p.orb.x = p.px / screenSize.width;
      p.orb.y = p.py / screenSize.height;
      p.orb.vx = p.pvx / screenSize.width;
      p.orb.vy = p.pvy / screenSize.height;
    }
  }
}

class _OrbPhysics {
  final EchoOrb orb;
  double px, py, pvx, pvy, radius;
  _OrbPhysics(this.orb, this.px, this.py, this.pvx, this.pvy, this.radius);
}

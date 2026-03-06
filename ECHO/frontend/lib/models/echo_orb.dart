class EchoOrb {
  double x, y, size;
  double vx, vy;
  final String? threadId;
  final double hue;
  final double z; // Added depth layer: 0.0 (far background) to 1.0 (foreground)

  EchoOrb({
    required this.x,
    required this.y,
    required this.size,
    required this.vx,
    required this.vy,
    this.threadId,
    required this.hue,
    required this.z,
  });
}

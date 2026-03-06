import 'package:flutter/material.dart';

class EchoButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const EchoButton({super.key, required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25), 
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1))
        ),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 2)),
    );
  }
}

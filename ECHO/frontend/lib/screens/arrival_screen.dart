import 'package:flutter/material.dart';
import '../widgets/echo_button.dart';

class ArrivalScreen extends StatelessWidget {
  final VoidCallback onReply;
  final VoidCallback onLetFade;
  final String? message;
  final bool isFetching;

  const ArrivalScreen({
    super.key,
    required this.onReply,
    required this.onLetFade,
    this.message,
    this.isFetching = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Center(
      child: Container(
        width: screenSize.width * 0.85,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFetching)
              const CircularProgressIndicator(color: Colors.white30)
            else
              Text(
                message ?? "The echo faded before it reached you.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w100,
                  fontFamily: 'Georgia',
                  height: 1.6,
                ),
              ),
            const SizedBox(height: 60),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 15,
              children: [
                EchoButton(
                  label: "Reply",
                  color: Colors.white.withValues(alpha: 0.1),
                  onPressed: onReply,
                ),
                EchoButton(
                  label: "Let Fade",
                  color: Colors.transparent,
                  onPressed: onLetFade,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

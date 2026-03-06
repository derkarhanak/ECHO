import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'deep_sky_screen.dart';
import '../widgets/orb_widget.dart';
import '../widgets/exhale_anchor.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _orbFloatController;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    )..forward();

    _orbFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _orbFloatController.dispose();
    super.dispose();
  }

  void _nextStep() async {
    HapticFeedback.lightImpact();
    if (_currentStep < 2) {
      _fadeController.reverse().then((_) {
        setState(() {
          _currentStep++;
        });
        _fadeController.forward();
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const DeepSkyScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "E C H O",
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w200,
                letterSpacing: 12.0,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "The void listens.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
                letterSpacing: 2.0,
              ),
            ),
          ],
        );
      case 1:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 150,
              child: ExhaleAnchor(
                onHoldStart: () {},
                onRelease: () {},
                onHoldUpdate: (val) {},
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              "Hold to Exhale",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 4.0,
              ),
            ),
          ],
        );
      case 2:
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 150,
              child: AnimatedBuilder(
                animation: _orbFloatController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 10 * _orbFloatController.value - 5),
                    child: const OrbWidget(size: 60, intensity: 0.8),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              "Tap to Catch",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 4.0,
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF0F2027), Color(0xFF030712)],
                radius: 1.5,
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return Opacity(
                  opacity: Curves.easeInOut.transform(_fadeController.value),
                  child: Transform.scale(
                    scale: 0.95 + (0.05 * _fadeController.value),
                    child: _buildStepContent(),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _fadeController,
                builder: (context, child) {
                  return Opacity(
                    opacity: Curves.easeInOut.transform(_fadeController.value),
                    child: TextButton(
                      onPressed: _nextStep,
                      child: Text(
                        _currentStep == 2 ? "Enter the Void" : "Continue",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

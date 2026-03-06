import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'utils/sound_manager.dart';
import 'screens/deep_sky_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/echo_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SoundManager.init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  await EchoApiService.instance.authenticate();
  
  final prefs = await SharedPreferences.getInstance();
  final bool hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

  runApp(MyApp(hasCompletedOnboarding: hasCompletedOnboarding));
}

class MyApp extends StatelessWidget {
  final bool hasCompletedOnboarding;

  const MyApp({super.key, required this.hasCompletedOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECHO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        brightness: Brightness.dark,
        textTheme: GoogleFonts.rajdhaniTextTheme(Theme.of(context).textTheme),
      ),
      home: hasCompletedOnboarding ? const DeepSkyScreen() : const OnboardingScreen(),
    );
  }
}


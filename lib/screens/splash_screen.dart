import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import 'auth/welcome_screen.dart';
import 'home/main_screen.dart';
import 'onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _bg = Color(0xFF3A90A3);

  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    // Wait for both the minimum splash duration AND for Firebase Auth to
    // emit its first state (+ load Firestore user data if signed in).
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2800)),
      auth.authReady,
    ]);

    if (!mounted) return;

    if (auth.isLoggedIn) {
      _go(const MainScreen());
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;
    _go(done ? const WelcomeScreen() : const OnboardingScreen());
  }

  void _go(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // ── Logo ──────────────────────────────────────────
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/photo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.3, 0.3),
                  end: const Offset(1.0, 1.0),
                  duration: 700.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 28),

            // ── App Name ──────────────────────────────────────
            Text(
              AppLocalizations.of(context)!.appName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            )
                .animate()
                .slideY(
                  begin: 0.4,
                  end: 0.0,
                  delay: 400.ms,
                  duration: 600.ms,
                  curve: Curves.easeOut,
                )
                .fadeIn(delay: 400.ms, duration: 600.ms),

            const SizedBox(height: 8),

            // ── Tagline ───────────────────────────────────────
            Text(
              AppLocalizations.of(context)!.splashTagline,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            )
                .animate()
                .fadeIn(delay: 800.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0.0, delay: 800.ms, duration: 600.ms),

            const Spacer(),

            // ── Loading dots ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white70,
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .scaleXY(
                        begin: 0.6,
                        end: 1.2,
                        delay: Duration(milliseconds: 1000 + i * 200),
                        duration: 500.ms,
                        curve: Curves.easeInOut,
                      )
                      .then()
                      .scaleXY(
                        begin: 1.2,
                        end: 0.6,
                        duration: 500.ms,
                        curve: Curves.easeInOut,
                      );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
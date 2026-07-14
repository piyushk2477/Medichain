import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/services/supabase_service.dart';
import 'package:medichain_beta/screens/onboarding_screen.dart';
import 'package:medichain_beta/screens/auth/login_screen.dart';
import 'package:medichain_beta/screens/patient/patient_dashboard.dart';
import 'package:medichain_beta/screens/doctor/doctor_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final AnimationController _textController;

  @override
  void initState() {
    super.initState();

    // Light splash -> dark status/nav bar icons so they stay visible.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack);
    _logoFade  = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _textController.forward();
    });

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

    if (!seenOnboarding) {
      _pushReplacement(const OnboardingScreen());
      return;
    }

    // Onboarding seen — check auth and route to the right home.
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _pushReplacement(const LoginScreen());
      return;
    }

    try {
      final role = await SupabaseService.getUserRole();
      if (!mounted) return;
      if (role == 'patient') {
        _pushReplacement(const PatientDashboard());
      } else if (role == 'doctor') {
        _pushReplacement(const DoctorDashboardScreen());
      } else {
        _pushReplacement(const LoginScreen());
      }
    } catch (_) {
      _pushReplacement(const LoginScreen());
    }
  }

  void _pushReplacement(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF1F5FB)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Centered logo mark (no wordmark)
              Center(
                child: FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.6, end: 1.0).animate(_logoScale),
                    child: Image.asset(
                      'assets/images/medichain_icon.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Wordmark near the bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 64),
                  child: FadeTransition(
                    opacity: _textController,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/medichain_wordmark.png',
                            width: 230,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 28),
                          _LoadingDots(color: AppColors.primary.withOpacity(0.85)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  final Color color;
  const _LoadingDots({required this.color});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value - i * 0.15) % 1.0;
            final wave = (1 - (t * 2 - 1).abs()).clamp(0.0, 1.0);
            final scale = 0.7 + 0.5 * wave;
            final opacity = 0.4 + 0.6 * wave;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
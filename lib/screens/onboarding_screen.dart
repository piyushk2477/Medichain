import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/screens/auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      tag: '01 · YOUR VAULT',
      caption: 'illustration · secure vault / storage',
      heading: 'Records you actually own.',
      description:
      'Upload prescriptions, lab reports, and scans. Every file is encrypted on your device before it ever leaves it.',
      illustration: _VaultIllustration(),
    ),
    _OnboardingPageData(
      tag: '02 · ONE TAP TO SHARE',
      caption: 'illustration · doctor handshake / share',
      heading: 'Send to any doctor,\ninstantly.',
      description:
      'Share a record with your physician for an appointment, a second opinion, or an emergency — and revoke access whenever you want.',
      illustration: _ShareIllustration(),
    ),
    _OnboardingPageData(
      tag: '03 · ON THE BLOCKCHAIN',
      caption: 'illustration · chain links / audit log',
      heading: 'Every access, on an audit trail.',
      description:
      'Each view, share, or edit is signed and timestamped on-chain. Tamper-proof. Inspectable. Yours.',
      illustration: _ChainIllustration(),
    ),
  ];

  bool get _isLast => _currentPage == _pages.length - 1;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _next() {
    if (_isLast) {
      _completeOnboarding();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_currentPage == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bars
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Row(
                children: List.generate(_pages.length, (i) {
                  final filled = i <= _currentPage;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == _pages.length - 1 ? 0 : 6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        height: 4,
                        decoration: BoxDecoration(
                          color: filled ? AppColors.primary : AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Back / Skip header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _IconTextButton(
                    icon: Icons.arrow_back,
                    label: 'Back',
                    enabled: _currentPage > 0,
                    onTap: _back,
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),
            // Dots + Continue/Get started
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Row(
                    children: List.generate(_pages.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.primary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(160, 56),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_isLast ? 'Get started' : 'Continue'),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _IconTextButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.textSecondary
        : AppColors.textSecondary.withOpacity(0.35);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String tag;
  final String caption;
  final String heading;
  final String description;
  final Widget illustration;

  const _OnboardingPageData({
    required this.tag,
    required this.caption,
    required this.heading,
    required this.description,
    required this.illustration,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5FF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: data.illustration,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '◇  ${data.caption}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textTertiary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data.tag,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.heading,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.12,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.description,
            style: const TextStyle(
              fontSize: 15.5,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ─── Inline illustrations (no asset dependencies) ──────────────────────────

class _VaultIllustration extends StatelessWidget {
  const _VaultIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          Positioned(
            top: 20,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 3),
              ),
              child: const Center(
                child: Icon(Icons.lock_outline_rounded, size: 36, color: AppColors.primary),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 14,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: AppColors.accentRed, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareIllustration extends StatelessWidget {
  const _ShareIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 130,
      child: CustomPaint(painter: _ShareIllustrationPainter()),
    );
  }
}

class _ShareIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.42),
      Offset(size.width * 0.72, size.height * 0.78),
      linePaint,
    );

    canvas.drawCircle(Offset(size.width * 0.32, size.height * 0.42), 28, Paint()..color = AppColors.primary);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.78), 22, Paint()..color = AppColors.accentRed);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.45, size.height * 0.5),
          width: 14,
          height: 14,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChainIllustration extends StatelessWidget {
  const _ChainIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(left: 0, bottom: 0, child: _Ring(color: AppColors.primary, size: 64)),
          const Positioned(right: 0, bottom: 0, child: _Ring(color: AppColors.primary, size: 64)),
          const Positioned(top: 0, child: _Ring(color: AppColors.accentRed, size: 54)),
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 38),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final Color color;
  final double size;
  const _Ring({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 8),
      ),
    );
  }
}
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:medichain_beta/services/supabase_service.dart';
import 'package:medichain_beta/screens/auth/signup_screen.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/medichain_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Animation controllers
  late final AnimationController _entranceCtrl; // one-shot staggered entry
  late final AnimationController _pulseCtrl;    // logo breathing + heartbeat
  late final AnimationController _bgCtrl;       // drifting orbs
  late final AnimationController _shakeCtrl;    // error shake

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Auto-clear the error banner as soon as the user starts editing again.
    _emailController.addListener(_clearErrorOnEdit);
    _passwordController.addListener(_clearErrorOnEdit);
  }

  void _clearErrorOnEdit() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _bgCtrl.dispose();
    _shakeCtrl.dispose();
    _emailController.removeListener(_clearErrorOnEdit);
    _passwordController.removeListener(_clearErrorOnEdit);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      final role = await SupabaseService.getUserRole();
      if (!mounted) return;

      if (role == 'patient') {
        Navigator.pushReplacementNamed(context, '/patient/dashboard');
      } else if (role == 'doctor') {
        Navigator.pushReplacementNamed(context, '/doctor/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      _shakeCtrl.forward(from: 0);
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Converts raw Supabase / network exceptions into human-friendly text.
  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('invalid login') ||
        msg.contains('invalid credentials') ||
        msg.contains('invalid_grant')) {
      return "That email and password don't match. Please try again.";
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before signing in. Check your inbox for the confirmation link.';
    }
    if (msg.contains('user not found')) {
      return "We couldn't find an account with that email.";
    }
    if (msg.contains('rate limit') ||
        msg.contains('too many requests') ||
        msg.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection') ||
        msg.contains('timeout') ||
        msg.contains('timed out')) {
      return "Couldn't reach our servers. Check your internet and try again.";
    }
    if (msg.contains('email logins are disabled')) {
      return 'Email sign-in is currently unavailable. Please try again later.';
    }
    if (msg.contains('weak password')) {
      return 'That password is too weak. Try a stronger one.';
    }
    return "We couldn't sign you in right now. Please try again.";
  }

  /// Helper to build a curved interval animation for entrance staggering.
  Animation<double> _stagger(double begin, double end) => CurvedAnimation(
    parent: _entranceCtrl,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  @override
  Widget build(BuildContext context) {
    // Keyboard avoidance is handled entirely by the single scroll view below.
    // The header and form live in ONE SingleChildScrollView, so when the
    // keyboard opens the page scrolls as a unit — the header scrolls up out of
    // the way and the focused field is lifted above the keyboard. The header
    // is no longer a fixed slot that the form card can slide back underneath,
    // which was what made the blue banner appear to cover the text field.
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        // Keep the focused field clear of the keyboard with a little breathing
        // room; the scroll view auto-scrolls it into view.
        child: Column(
          children: [
            _AnimatedHeader(
              pulseCtrl: _pulseCtrl,
              bgCtrl: _bgCtrl,
              entranceCtrl: _entranceCtrl,
            ),
            Padding(
              // The card overlaps the header bottom (-28) for depth, exactly
              // as before. Bottom padding grows with the keyboard so the last
              // field never ends up flush against it.
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Transform.translate(
                offset: const Offset(0, -28),
                child: _FormCard(
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  isLoading: _isLoading,
                  shakeCtrl: _shakeCtrl,
                  stagger: _stagger,
                  errorMessage: _errorMessage,
                  onDismissError: () =>
                      setState(() => _errorMessage = null),
                  onTogglePassword: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                  ),
                  onSubmit: _login,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated Header
// ---------------------------------------------------------------------------
class _AnimatedHeader extends StatelessWidget {
  final AnimationController pulseCtrl;
  final AnimationController bgCtrl;
  final AnimationController entranceCtrl;

  const _AnimatedHeader({
    required this.pulseCtrl,
    required this.bgCtrl,
    required this.entranceCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    final headerHeight = mediaTop + 280;

    return SizedBox(
      width: double.infinity,
      height: headerHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3B82F6),
                    AppColors.primary,
                    Color(0xFF1D4ED8),
                  ],
                ),
              ),
            ),

            // Drifting decorative orbs
            AnimatedBuilder(
              animation: bgCtrl,
              builder: (context, _) => CustomPaint(
                painter: _OrbsPainter(t: bgCtrl.value),
              ),
            ),

            // Scrolling heartbeat / ECG line
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              height: 56,
              child: AnimatedBuilder(
                animation: pulseCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _HeartbeatPainter(progress: pulseCtrl.value),
                ),
              ),
            ),

            // Foreground content
            Padding(
              padding: EdgeInsets.fromLTRB(26, mediaTop + 28, 26, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Breathing logo
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: entranceCtrl,
                      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                    ),
                    child: AnimatedBuilder(
                      animation: pulseCtrl,
                      builder: (context, child) {
                        // Smooth sine-based scale — natural breathing feel.
                        final t = pulseCtrl.value;
                        final scale =
                            1.0 + math.sin(t * 2 * math.pi) * 0.035;
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: const MedichainLogo(size: 64),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _SlideFadeIn(
                    animation: CurvedAnimation(
                      parent: entranceCtrl,
                      curve: const Interval(0.10, 0.60,
                          curve: Curves.easeOutCubic),
                    ),
                    fromOffset: const Offset(-26, 0),
                    child: const Text(
                      'Welcome back.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SlideFadeIn(
                    animation: CurvedAnimation(
                      parent: entranceCtrl,
                      curve: const Interval(0.22, 0.72,
                          curve: Curves.easeOutCubic),
                    ),
                    fromOffset: const Offset(-20, 0),
                    child: Text(
                      'Your records, encrypted and within reach.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 15,
                        height: 1.4,
                      ),
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

// ---------------------------------------------------------------------------
// Form Card (overlaps header bottom for depth)
// ---------------------------------------------------------------------------
class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final AnimationController shakeCtrl;
  final Animation<double> Function(double, double) stagger;
  final String? errorMessage;
  final VoidCallback onDismissError;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  const _FormCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.shakeCtrl,
    required this.stagger,
    required this.errorMessage,
    required this.onDismissError,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: shakeCtrl,
        builder: (context, child) {
          final t = shakeCtrl.value;
          // Damped sine — 2 quick oscillations decaying to zero.
          final dx = t == 0 ? 0.0 : math.sin(t * math.pi * 4) * 10 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Inline blue-themed error banner — appears & dismisses smoothly.
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SizeTransition(
                      sizeFactor: anim,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: errorMessage == null
                      ? const SizedBox(
                    key: ValueKey('no-error'),
                    width: double.infinity,
                  )
                      : Padding(
                    key: const ValueKey('error'),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ErrorBanner(
                      message: errorMessage!,
                      onDismiss: onDismissError,
                    ),
                  ),
                ),
              ),
              _StaggeredFadeSlide(
                animation: stagger(0.30, 0.75),
                child: _RoundedField(
                  controller: emailController,
                  hint: 'Email address',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!v.contains('@')) return 'Please enter a valid email';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 14),
              _StaggeredFadeSlide(
                animation: stagger(0.40, 0.85),
                child: _RoundedField(
                  controller: passwordController,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                  suffix: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: onTogglePassword,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 24),
              _StaggeredFadeSlide(
                animation: stagger(0.50, 0.95),
                child: _MorphingSignInButton(
                  isLoading: isLoading,
                  onPressed: onSubmit,
                ),
              ),
              const SizedBox(height: 14),
              _StaggeredFadeSlide(
                animation: stagger(0.60, 1.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'New to Medichain?',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entrance helpers
// ---------------------------------------------------------------------------
class _SlideFadeIn extends StatelessWidget {
  final Animation<double> animation;
  final Offset fromOffset;
  final Widget child;

  const _SlideFadeIn({
    required this.animation,
    required this.fromOffset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, c) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(
              fromOffset.dx * (1 - t),
              fromOffset.dy * (1 - t),
            ),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

class _StaggeredFadeSlide extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _StaggeredFadeSlide({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, c) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Drifting orbs painter (decorative background motion)
// ---------------------------------------------------------------------------
class _OrbsPainter extends CustomPainter {
  final double t; // 0..1
  _OrbsPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final two = 2 * math.pi;

    _orb(canvas,
        cx: w * 0.85 + math.sin(t * two) * 22,
        cy: h * 0.15 + math.cos(t * two) * 18,
        r: 130,
        a: 0.10);
    _orb(canvas,
        cx: w * 0.18 + math.cos(t * two + 1.2) * 20,
        cy: h * 0.62 + math.sin(t * two + 1.2) * 22,
        r: 95,
        a: 0.07);
    _orb(canvas,
        cx: w * 0.72 + math.sin(t * two + 2.4) * 24,
        cy: h * 0.82 + math.cos(t * two + 2.4) * 14,
        r: 70,
        a: 0.05);
  }

  void _orb(
      Canvas canvas, {
        required double cx,
        required double cy,
        required double r,
        required double a,
      }) {
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white.withOpacity(a),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbsPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ---------------------------------------------------------------------------
// Heartbeat / ECG line painter — the signature medical motif
// ---------------------------------------------------------------------------
class _HeartbeatPainter extends CustomPainter {
  final double progress; // 0..1
  _HeartbeatPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseY = h * 0.55;

    // The spike scrolls across the screen from left to right.
    final spikeX = -40.0 + progress * (w + 80);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.30)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(0, baseY);

    const step = 1.5;
    for (double x = 0; x <= w; x += step) {
      final d = x - spikeX;
      double y = baseY;

      if (d >= -16 && d <= 18) {
        if (d < -8) {
          // Small Q dip
          y = baseY + (d + 8) * 0.4;
        } else if (d < -2) {
          // Sharp R ascent
          final p = (d + 8) / 6;
          y = baseY - p * 26;
        } else if (d < 2) {
          // R peak (held briefly)
          y = baseY - 26;
        } else if (d < 8) {
          // Sharp S descent below baseline
          final p = (d - 2) / 6;
          y = baseY - 26 + p * 40;
        } else {
          // T-wave return
          final p = (d - 8) / 10;
          y = baseY + 14 - p * 14;
        }
      }
      path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // Glow + dot at the R peak for a subtle "live" highlight
    if (spikeX > 0 && spikeX < w) {
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(spikeX, baseY - 26), 3.0, glowPaint);
      canvas.drawCircle(
        Offset(spikeX, baseY - 26),
        2.0,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeartbeatPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ---------------------------------------------------------------------------
// Morphing Sign In button — pill that collapses into a loading circle
// ---------------------------------------------------------------------------
class _MorphingSignInButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _MorphingSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_MorphingSignInButton> createState() => _MorphingSignInButtonState();
}

class _MorphingSignInButtonState extends State<_MorphingSignInButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        return Align(
          alignment: Alignment.center,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown:
            widget.isLoading ? null : (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.isLoading ? null : widget.onPressed,
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                height: 54,
                width: widget.isLoading ? 54 : fullWidth,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                  BorderRadius.circular(widget.isLoading ? 32 : 14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.34),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: widget.isLoading
                      ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                      : Row(
                    key: const ValueKey('label'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Sign in',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Inline error banner — blue-themed, matches the login aesthetic
// ---------------------------------------------------------------------------
class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        // Light blue tint — sits naturally on the white form card.
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading icon in a soft circle
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Dismiss button
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 18,
              iconSize: 18,
              tooltip: 'Dismiss',
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.textTertiary,
              ),
              onPressed: onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable rounded input field
// ---------------------------------------------------------------------------
class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;

  const _RoundedField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffix,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(icon, color: AppColors.textTertiary, size: 22),
        ),
        prefixIconConstraints:
        const BoxConstraints(minWidth: 44, minHeight: 44),
        suffixIcon: suffix,
      ),
    );
  }
}
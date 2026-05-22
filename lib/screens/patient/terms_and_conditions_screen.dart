import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medichain_beta/theme/app_theme.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _shieldPulse;

  static const _sections = <_TermsSection>[
    _TermsSection(
      icon: Icons.health_and_safety_outlined,
      title: 'About MediChain',
      body:
      'MediChain is a blockchain-backed personal health records platform. '
          'You upload medical records once and decide who can see them — '
          'doctors, hospitals, or no one at all. There is no central server '
          'that owns your history.',
      tint: Color(0xFF3B82F6),
    ),
    _TermsSection(
      icon: Icons.lock_outline_rounded,
      title: 'End-to-End Encryption',
      body:
      'Every record is encrypted on your device with AES-256 before it '
          'ever leaves your phone. We never see the contents. Only people '
          'you explicitly grant access to can decrypt them.',
      tint: Color(0xFF8B5CF6),
    ),
    _TermsSection(
      icon: Icons.cloud_done_outlined,
      title: 'Decentralized Storage',
      body:
      "Encrypted files are stored on IPFS — a distributed network where "
          "content lives across many nodes rather than a single company's "
          "servers. The reference (CID) and integrity hash are anchored on "
          "the Polygon blockchain.",
      tint: Color(0xFF14B8A6),
    ),
    _TermsSection(
      icon: Icons.verified_user_outlined,
      title: 'Tamper-Proof Audit Trail',
      body:
      'Every share, every access, and every revocation is timestamped '
          'on-chain. You can review the complete history of who looked at '
          'what — and prove it independently if you ever need to.',
      tint: Color(0xFF059669),
    ),
    _TermsSection(
      icon: Icons.handshake_outlined,
      title: 'Sharing with Doctors',
      body:
      'Doctors request access; you approve or deny each request. '
          'Approved access can be revoked at any time, instantly. Doctors '
          'cannot view records that have not been explicitly shared with '
          'them.',
      tint: Color(0xFFEC4899),
    ),
    _TermsSection(
      icon: Icons.account_balance_outlined,
      title: 'Your Data, Your Control',
      body:
      'You own every record you upload. You can download originals, '
          'revoke shares, and delete records at any time. We do not sell, '
          'monetize, or analyze your medical data — and we cannot, because '
          'we cannot read it.',
      tint: Color(0xFFF59E0B),
    ),
    _TermsSection(
      icon: Icons.gavel_outlined,
      title: 'Your Responsibilities',
      body:
      'Keep your account credentials safe. Only share records with '
          'doctors and providers you trust. MediChain is an early-stage '
          'platform and should not be used as a substitute for emergency '
          'medical care or for storing records you cannot afford to lose '
          'as your only copy.',
      tint: Color(0xFFEF4444),
    ),
    _TermsSection(
      icon: Icons.update_rounded,
      title: 'Changes to These Terms',
      body:
      'As we move from beta toward production, these terms may evolve. '
          'You will be notified in-app of any material changes before they '
          'take effect.',
      tint: Color(0xFF6366F1),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _shieldPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _shieldPulse.dispose();
    super.dispose();
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
    parent: _entranceCtrl,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _TermsHeader(
              shieldPulse: _shieldPulse,
              entranceCtrl: _entranceCtrl,
              onBack: () => Navigator.pop(context),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverList.separated(
              itemCount: _sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final start = (0.15 + i * 0.06).clamp(0.0, 0.55);
                final end = (start + 0.40).clamp(0.0, 1.0);
                return _FadeSlideIn(
                  animation: _stage(start, end),
                  child: _SectionCard(section: _sections[i]),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: _FadeSlideIn(
              animation: _stage(0.75, 1.0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  children: [
                    const _LastUpdated(),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'I understand',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header with pulsing shield ────────────────────────────────────────
class _TermsHeader extends StatelessWidget {
  final AnimationController shieldPulse;
  final AnimationController entranceCtrl;
  final VoidCallback onBack;

  const _TermsHeader({
    required this.shieldPulse,
    required this.entranceCtrl,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, mediaTop + 14, 20, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), AppColors.primary, Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _CircularIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
                const Spacer(),
              ]),
              const SizedBox(height: 22),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: entranceCtrl,
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                ),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: shieldPulse,
                        builder: (context, _) {
                          final t = shieldPulse.value;
                          final size = 56 + 28 * t;
                          final opacity = (1.0 - t) * 0.35;
                          return Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(opacity),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.28),
                              width: 1),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.verified_user_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Terms & Conditions',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'How MediChain protects your health records.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.86),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircularIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ─── Section card ──────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final _TermsSection section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: section.tint.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: section.tint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(section.icon, color: section.tint, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  section.body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection {
  final IconData icon;
  final String title;
  final String body;
  final Color tint;
  const _TermsSection({
    required this.icon,
    required this.title,
    required this.body,
    required this.tint,
  });
}

// ─── Last updated footer ───────────────────────────────────────────────
class _LastUpdated extends StatelessWidget {
  const _LastUpdated();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Last updated: May 2026  •  MediChain Beta',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fade + slide entrance ─────────────────────────────────────────────
class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _FadeSlideIn({required this.animation, required this.child});

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
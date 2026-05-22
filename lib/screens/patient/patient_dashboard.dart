import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medichain_beta/services/supabase_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'find_doctors_screen.dart';
import 'specialty_doctors_screen.dart';
import 'terms_and_conditions_screen.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard>
    with TickerProviderStateMixin {
  late Future<_DashboardData> _data;
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _data = _load();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
    parent: _entranceCtrl,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<_DashboardData> _load() async {
    final user = SupabaseService.currentUser;
    try {
      final results = await Future.wait([
        if (user != null)
          Supabase.instance.client
              .from('medical_records')
              .select('id')
              .eq('patient_id', user.id)
        else
          Future.value(<dynamic>[]),
        if (user != null)
          Supabase.instance.client
              .from('doctor_requests')
              .select('id, status')
              .eq('patient_id', user.id)
        else
          Future.value(<dynamic>[]),
        // ALL doctors — used to compute per-specialty counts shown on the cards.
        Supabase.instance.client.from('doctors').select('specialization'),
      ]);

      final records = (results[0] as List).length;
      final requests = (results[1] as List).cast<Map<String, dynamic>>();
      final allDocs = (results[2] as List).cast<Map<String, dynamic>>();

      final connected = requests.where((r) => r['status'] == 'accepted').length;
      final pending = requests.where((r) => r['status'] == 'pending').length;

      final specCounts = <String, int>{};
      for (final d in allDocs) {
        final raw = (d['specialization'] as String? ?? '').toLowerCase();
        if (raw.isEmpty) continue;
        for (final s in _kSpecialties) {
          if (raw.contains(s.name.toLowerCase())) {
            specCounts[s.name] = (specCounts[s.name] ?? 0) + 1;
          }
        }
      }

      return _DashboardData(
        records: records,
        connected: connected,
        pending: pending,
        specialtyCounts: specCounts,
      );
    } catch (_) {
      return _DashboardData.zero();
    }
  }

  void _openFindDoctors() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FindDoctorsScreen()),
    );
    if (!mounted) return;
    setState(() => _data = _load());
  }

  void _openSpecialty(_Specialty s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpecialtyDoctorsScreen(
          specialty: s.name,
          icon: s.icon,
          color: s.color,
        ),
      ),
    );
  }

  void _openTerms() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()),
    );
  }

  void _openAllSpecialties() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllSpecialtiesSheet(
        onTap: (s) {
          Navigator.pop(context);
          _openSpecialty(s);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final fullName = (user?.userMetadata?['full_name'] as String?) ?? 'User';
    final firstName = fullName.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(() => _data = _load());
          await _data;
        },
        child: FutureBuilder<_DashboardData>(
          future: _data,
          builder: (context, snap) {
            final data = snap.data ?? _DashboardData.zero();
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Compact top bar ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: _FadeSlideIn(
                    animation: _stage(0.0, 0.35),
                    slide: 10,
                    child: _TopBar(
                      greeting: _getGreeting(),
                      name: firstName,
                      fullName: fullName,
                      onProfileTap: () => Navigator.pushNamed(
                          context, '/patient/profile'),
                    ),
                  ),
                ),

                // ── Bold hero headline ──────────────────────────────────
                SliverToBoxAdapter(
                  child: _FadeSlideIn(
                    animation: _stage(0.05, 0.45),
                    slide: 24,
                    child: const _HeroHeadline(),
                  ),
                ),

                // ── Animated search hero ────────────────────────────────
                SliverToBoxAdapter(
                  child: _FadeSlideIn(
                    animation: _stage(0.12, 0.55),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                      child: _SearchHero(onTap: _openFindDoctors),
                    ),
                  ),
                ),

                // ── Quick actions (Upload / Records / Share) ────────────
                SliverToBoxAdapter(
                  child: _FadeSlideIn(
                    animation: _stage(0.20, 0.62),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: _QuickActions(
                        onUpload: () =>
                            Navigator.pushNamed(context, '/patient/upload'),
                        onRecords: () =>
                            Navigator.pushNamed(context, '/patient/records'),
                        onShare: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const FindDoctorsScreen()),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── "Browse by Specialty" section header ────────────────
                SliverToBoxAdapter(
                  child: _FadeSlideIn(
                    animation: _stage(0.28, 0.70),
                    child: _SectionHeader(
                      title: 'Browse by Specialty',
                      trailing: 'View all',
                      onTrailing: _openAllSpecialties,
                    ),
                  ),
                ),

                // ── Big alternating specialty cards (the standout) ──────
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      final s = _kSpecialties[i];
                      final start = (0.32 + i * 0.06).clamp(0.0, 0.85);
                      final end = (start + 0.32).clamp(0.0, 1.0);
                      return _FadeSlideIn(
                        animation: _stage(start, end),
                        slide: 32,
                        child: Padding(
                          padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 14),
                          child: _BigSpecialtyCard(
                            specialty: s,
                            doctorCount: data.specialtyCounts[s.name] ?? 0,
                            gradient: i.isEven,
                            onTap: () => _openSpecialty(s),
                          ),
                        ),
                      );
                    },
                    childCount: 4, // top 4 specialties as big cards
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                // ── My Doctors preview ──────────────────────────────────
                SliverToBoxAdapter(
                  child: _FadeSlideIn(
                    animation: _stage(0.58, 0.97),
                    child: _ConnectedDoctorsPreview(onSeeAll: _openFindDoctors),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Terms footer ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _FadeSlideIn(
                    animation: _stage(0.70, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: _TermsFooterCard(onTap: _openTerms),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const PatientBottomNav(currentIndex: 0),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Top bar — clean avatar + greeting + bell
// ═════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final String greeting;
  final String name;
  final String fullName;
  final VoidCallback onProfileTap;

  const _TopBar({
    required this.greeting,
    required this.name,
    required this.fullName,
    required this.onProfileTap,
  });

  String _initial() {
    final t = fullName.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, mediaTop + 12, 20, 22),
      child: Row(
        children: [
          // Gradient avatar with initial
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), AppColors.primary, Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _initial(),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$greeting 👋',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // Notification bell
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {}, // wire up later
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined,
                        color: AppColors.textPrimary, size: 20),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.accentRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
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

// ═════════════════════════════════════════════════════════════════════════
// Hero headline — bold typography
// ═════════════════════════════════════════════════════════════════════════
class _HeroHeadline extends StatelessWidget {
  const _HeroHeadline();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -1.2,
                height: 1.08,
              ),
              children: [
                const TextSpan(text: 'Your health,\n'),
                TextSpan(
                  text: 'in your hands.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1.0,
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

// ═════════════════════════════════════════════════════════════════════════
// Search hero — pulsing icon + rolling hints
// ═════════════════════════════════════════════════════════════════════════
class _SearchHero extends StatefulWidget {
  final VoidCallback onTap;
  const _SearchHero({required this.onTap});

  @override
  State<_SearchHero> createState() => _SearchHeroState();
}

class _SearchHeroState extends State<_SearchHero>
    with TickerProviderStateMixin {
  static const _hints = <String>[
    'Search for "Cardiologist"',
    'Find "Dr. Sharma"',
    'Try "Pediatrics" near you',
    'Search by hospital name',
    'Find "Dermatologist"',
  ];

  int _hintIndex = 0;
  Timer? _hintTimer;
  bool _pressed = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _hintTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (!mounted) return;
      setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.10),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, _) {
                        final t = _pulseCtrl.value;
                        final size = 38 + 20 * t;
                        final opacity = (1.0 - t) * 0.35;
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(opacity),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.34),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.search_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Find Your Doctor',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 18,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.6),
                            end: Offset.zero,
                          ).animate(anim),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Text(
                          _hints[_hintIndex],
                          key: ValueKey(_hintIndex),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Quick actions — 3 big tappable tiles (replaces the old "Soon" grid)
// ═════════════════════════════════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  final VoidCallback onUpload;
  final VoidCallback onRecords;
  final VoidCallback onShare;

  const _QuickActions({
    required this.onUpload,
    required this.onRecords,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.cloud_upload_rounded,
            label: 'Upload',
            sub: 'Add records',
            tint: const Color(0xFF8B5CF6),
            onTap: onUpload,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.folder_rounded,
            label: 'Records',
            sub: 'Your files',
            tint: const Color(0xFF059669),
            onTap: onRecords,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.share_rounded,
            label: 'Share',
            sub: 'To doctors',
            tint: const Color(0xFFF59E0B),
            onTap: onShare,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color tint;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.tint,
    required this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: widget.tint.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.tint.withOpacity(0.85), widget.tint],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.tint.withOpacity(0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.sub,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// THE STANDOUT — Big alternating gradient/white specialty cards
// ═════════════════════════════════════════════════════════════════════════
class _BigSpecialtyCard extends StatefulWidget {
  final _Specialty specialty;
  final int doctorCount;
  final bool gradient;
  final VoidCallback onTap;

  const _BigSpecialtyCard({
    required this.specialty,
    required this.doctorCount,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_BigSpecialtyCard> createState() => _BigSpecialtyCardState();
}

class _BigSpecialtyCardState extends State<_BigSpecialtyCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.specialty;
    final dark = widget.gradient;
    final textColor = dark ? Colors.white : AppColors.textPrimary;
    final mutedColor =
    dark ? Colors.white.withOpacity(0.78) : AppColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? null : Colors.white,
            gradient: dark
                ? const LinearGradient(
              colors: [
                Color(0xFF3B82F6),
                AppColors.primary,
                Color(0xFF1E40AF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            borderRadius: BorderRadius.circular(24),
            border: dark ? null : Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: (dark ? AppColors.primary : s.color)
                    .withOpacity(dark ? 0.32 : 0.08),
                blurRadius: dark ? 24 : 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Decorative background blobs
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: (dark ? Colors.white : s.color)
                          .withOpacity(dark ? 0.10 : 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: -20,
                  bottom: -50,
                  child: Icon(
                    s.icon,
                    size: 150,
                    color: (dark ? Colors.white : s.color)
                        .withOpacity(dark ? 0.08 : 0.04),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top row: icon + count pill
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: dark
                                  ? Colors.white.withOpacity(0.18)
                                  : s.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: dark
                                  ? Border.all(
                                  color: Colors.white.withOpacity(0.25))
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Icon(s.icon,
                                color: dark ? Colors.white : s.color,
                                size: 24),
                          ),
                          const Spacer(),
                          _CountPill(
                            count: widget.doctorCount,
                            dark: dark,
                            tint: s.color,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Specialty name + subtitle
                      Text(
                        s.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.6,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        s.subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: mutedColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Avatar stack + arrow CTA
                      Row(
                        children: [
                          _AvatarStack(
                            dark: dark,
                            extra: widget.doctorCount > 3
                                ? widget.doctorCount - 3
                                : 0,
                          ),
                          const Spacer(),
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: dark ? Colors.white : s.color,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: dark
                                  ? null
                                  : [
                                BoxShadow(
                                  color: s.color.withOpacity(0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.arrow_outward_rounded,
                              color: dark ? AppColors.primary : Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Count pill with animated counter
class _CountPill extends StatelessWidget {
  final int count;
  final bool dark;
  final Color tint;
  const _CountPill(
      {required this.count, required this.dark, required this.tint});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? Colors.white : tint.withOpacity(0.10);
    final fg = dark ? AppColors.primary : tint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medical_services_rounded, size: 12, color: fg),
          const SizedBox(width: 5),
          _AnimatedCount(
            value: count,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            count == 1 ? 'doctor' : 'doctors',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// Counts up from 0 to value on entrance
class _AnimatedCount extends StatefulWidget {
  final int value;
  final TextStyle style;
  const _AnimatedCount({required this.value, required this.style});

  @override
  State<_AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<_AnimatedCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<int> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _anim = IntTween(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Text('${_anim.value}', style: widget.style),
    );
  }
}

// Stacked avatar circles — generic doctor representation
class _AvatarStack extends StatelessWidget {
  final bool dark;
  final int extra; // count for the "+N" badge

  const _AvatarStack({required this.dark, required this.extra});

  @override
  Widget build(BuildContext context) {
    const palette = <List<Color>>[
      [Color(0xFFEC4899), Color(0xFFF59E0B)],
      [Color(0xFF14B8A6), Color(0xFF06B6D4)],
      [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ];

    final ringColor = Colors.white;
    final hasBadge = extra > 0;

    return SizedBox(
      width: hasBadge ? 102 : 72,
      height: 32,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: palette[i],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: ringColor, width: 2),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
          if (hasBadge)
            Positioned(
              left: 60,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? Colors.white : AppColors.primary,
                  border: Border.all(color: ringColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$extra',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: dark ? AppColors.primary : Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Section header (inline)
// ═════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          if (trailing != null)
            InkWell(
              onTap: onTrailing,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      trailing!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Specialty data (with subtitles for the big cards)
// ═════════════════════════════════════════════════════════════════════════
class _Specialty {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _Specialty(this.name, this.subtitle, this.icon, this.color);
}

const List<_Specialty> _kSpecialties = [
  _Specialty('Cardiology', 'Heart & circulation',
      Icons.favorite_rounded, Color(0xFFEF4444)),
  _Specialty('Neurology', 'Brain & nerves',
      Icons.psychology_rounded, Color(0xFF8B5CF6)),
  _Specialty('Orthopedics', 'Bones & joints',
      Icons.accessibility_new_rounded, Color(0xFF14B8A6)),
  _Specialty('Dermatology', 'Skin, hair & nails',
      Icons.face_retouching_natural, Color(0xFFEC4899)),
  _Specialty('Pediatrics', 'Child health',
      Icons.child_care_rounded, Color(0xFFF59E0B)),
  _Specialty('Dentistry', 'Dental & oral',
      Icons.medical_information_rounded, Color(0xFF0EA5E9)),
  _Specialty('Ophthalmology', 'Eyes & vision',
      Icons.visibility_rounded, Color(0xFF6366F1)),
  _Specialty('Gynecology', "Women's health",
      Icons.pregnant_woman_rounded, Color(0xFFE11D48)),
  _Specialty('General Medicine', 'Primary care',
      Icons.medical_services_rounded, Color(0xFF059669)),
  _Specialty('ENT', 'Ear, nose & throat',
      Icons.hearing_rounded, Color(0xFFD97706)),
  _Specialty('Psychiatry', 'Mental health',
      Icons.self_improvement_rounded, Color(0xFF7C3AED)),
  _Specialty('Endocrinology', 'Hormones & metabolism',
      Icons.science_outlined, Color(0xFF0891B2)),
];

// ═════════════════════════════════════════════════════════════════════════
// All Specialties bottom sheet
// ═════════════════════════════════════════════════════════════════════════
class _AllSpecialtiesSheet extends StatelessWidget {
  final void Function(_Specialty) onTap;
  const _AllSpecialtiesSheet({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Row(
                  children: [
                    Text(
                      'All Specialties',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_kSpecialties.length} specialties',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _kSpecialties.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final s = _kSpecialties[i];
                    return StaggeredAppear(
                      index: i,
                      delayMsPerIndex: 30,
                      child: _SpecialtyRow(specialty: s, onTap: () => onTap(s)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpecialtyRow extends StatefulWidget {
  final _Specialty specialty;
  final VoidCallback onTap;
  const _SpecialtyRow({required this.specialty, required this.onTap});

  @override
  State<_SpecialtyRow> createState() => _SpecialtyRowState();
}

class _SpecialtyRowState extends State<_SpecialtyRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.specialty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: s.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(s.icon, color: s.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: s.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.arrow_forward_rounded,
                    color: s.color, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Connected doctors preview — My Doctors section
// ═════════════════════════════════════════════════════════════════════════
class _ConnectedDoctorsPreview extends StatefulWidget {
  final VoidCallback onSeeAll;
  const _ConnectedDoctorsPreview({required this.onSeeAll});

  @override
  State<_ConnectedDoctorsPreview> createState() =>
      _ConnectedDoctorsPreviewState();
}

class _ConnectedDoctorsPreviewState extends State<_ConnectedDoctorsPreview> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = SupabaseService.currentUser;
    if (user == null) return [];
    try {
      final rows = await Supabase.instance.client
          .from('doctor_requests')
          .select('doctor_id, doctor:doctors!doctor_id('
          'id, name, specialization, hospital_name)')
          .eq('patient_id', user.id)
          .eq('status', 'accepted')
          .limit(5);
      return (rows as List).map((r) => (r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'My Doctors',
              trailing: 'See all',
              onTrailing: widget.onSeeAll,
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.handshake_outlined,
                            size: 28, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No connected doctors yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse specialties or search to find your doctor',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: widget.onSeeAll,
                        icon: const Icon(Icons.search_rounded, size: 16),
                        label: const Text('Find Doctors'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final row = items[i];
                  final doc = (row['doctor'] as Map?) ?? const {};
                  final name = (doc['name'] as String?) ?? 'Doctor';
                  final spec = doc['specialization'] as String?;
                  final id = doc['id'] as String?;
                  return StaggeredAppear(
                    index: i,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: id == null
                            ? null
                            : () => Navigator.pushNamed(
                          context,
                          '/patient/upload',
                          arguments: id,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF60A5FA),
                                      AppColors.primary,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                    Icons.medical_services_rounded,
                                    color: Colors.white,
                                    size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Dr. $name',
                                            style:
                                            GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified_rounded,
                                            color: AppColors.success,
                                            size: 14),
                                      ],
                                    ),
                                    if (spec != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        spec,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.send_rounded,
                                        color: Colors.white, size: 13),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Send',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Terms & Conditions footer card
// ═════════════════════════════════════════════════════════════════════════
class _TermsFooterCard extends StatelessWidget {
  final VoidCallback onTap;
  const _TermsFooterCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.verified_user_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Terms & Conditions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'How MediChain handles your data',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Small fade+slide entrance utility
// ═════════════════════════════════════════════════════════════════════════
class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final double slide;
  const _FadeSlideIn({
    required this.animation,
    required this.child,
    this.slide = 18,
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
            offset: Offset(0, slide * (1 - t)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Data model
// ═════════════════════════════════════════════════════════════════════════
class _DashboardData {
  final int records;
  final int connected;
  final int pending;
  final Map<String, int> specialtyCounts;
  _DashboardData({
    required this.records,
    required this.connected,
    required this.pending,
    required this.specialtyCounts,
  });
  factory _DashboardData.zero() => _DashboardData(
    records: 0,
    connected: 0,
    pending: 0,
    specialtyCounts: const {},
  );
}

// Public re-export so other files can use the same specialty list
class SpecialtyData {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  const SpecialtyData(this.name, this.subtitle, this.icon, this.color);
}

List<SpecialtyData> get kAllSpecialties => _kSpecialties
    .map((s) => SpecialtyData(s.name, s.subtitle, s.icon, s.color))
    .toList(growable: false);
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medichain_beta/services/supabase_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'terms_and_conditions_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late Future<_ProfileData> _data;

  late final AnimationController _entranceCtrl;
  late final AnimationController _avatarPulse;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
    _avatarPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _data = _load();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _avatarPulse.dispose();
    super.dispose();
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
    parent: _entranceCtrl,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  Future<_ProfileData> _load() async {
    final user = SupabaseService.currentUser;
    if (user == null) return _ProfileData.zero();

    final client = Supabase.instance.client;

    // Stats — gracefully handle each one in case a table is missing.
    int records = 0, doctors = 0, shared = 0;

    try {
      final rows = await client
          .from('medical_records')
          .select('id')
          .eq('patient_id', user.id);
      records = (rows as List).length;
    } catch (_) {}

    try {
      final rows = await client
          .from('doctor_requests')
          .select('id, status')
          .eq('patient_id', user.id)
          .eq('status', 'accepted');
      doctors = (rows as List).length;
    } catch (_) {}

    try {
      final rows = await client
          .from('shared_records')
          .select('id')
          .eq('patient_id', user.id);
      shared = (rows as List).length;
    } catch (_) {}

    // Names / extras — try to read full_name from profiles, fall back to
    // auth metadata.
    String fullName =
        (user.userMetadata?['full_name'] as String?) ?? 'User';
    String email = user.email ?? '';

    try {
      final profile = await client
          .from('profiles')
          .select('full_name, email')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null) {
        fullName = (profile['full_name'] as String?) ?? fullName;
        email = (profile['email'] as String?) ?? email;
      }
    } catch (_) {}

    return _ProfileData(
      fullName: fullName,
      email: email,
      records: records,
      doctors: doctors,
      shared: shared,
    );
  }

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (result == true && mounted) {
      setState(() => _data = _load());
    }
  }

  Future<void> _openterms() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()),
    );
    if (result == true && mounted) {
      setState(() => _data = _load());
    }
  }

  void _soon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.schedule_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            'Coming soon',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ]),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _LogoutDialog(),
    );
    if (confirm == true) {
      await SupabaseService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FutureBuilder<_ProfileData>(
        future: _data,
        builder: (context, snap) {
          final data = snap.data ?? _ProfileData.zero();
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              setState(() => _data = _load());
              await _data;
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ── Header ────────────────────────────────────────────
                _FadeSlideIn(
                  animation: _stage(0.0, 0.4),
                  slide: 14,
                  child: _Header(
                    name: data.fullName,
                    email: data.email,
                    avatarPulse: _avatarPulse,
                    onEdit: _openEdit,
                  ),
                ),
                const SizedBox(height: 18),

                // ── Stat row (REAL counts, animated) ──────────────────
                _FadeSlideIn(
                  animation: _stage(0.10, 0.50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _StatRow(
                      records: data.records,
                      doctors: data.doctors,
                      shared: data.shared,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── ACCOUNT section ───────────────────────────────────
                _FadeSlideIn(
                  animation: _stage(0.20, 0.60),
                  child: const _SectionLabel('ACCOUNT'),
                ),
                _FadeSlideIn(
                  animation: _stage(0.24, 0.64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MenuCard(children: [
                      _MenuItem(
                        icon: Icons.person_outline_rounded,
                        tint: AppColors.primary,
                        label: 'Personal Information',
                        subtitle: 'Name, date of birth, gender',
                        onTap: _openEdit,
                      ),
                      const _MenuDivider(),
                      _MenuItem(
                        icon: Icons.lock_outline_rounded,
                        tint: const Color(0xFF8B5CF6),
                        label: 'Security',
                        subtitle: 'Password & authentication',
                        onTap: _openterms,
                      ),
                      const _MenuDivider(),

                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // ── HEALTH section ────────────────────────────────────
                _FadeSlideIn(
                  animation: _stage(0.34, 0.74),
                  child: const _SectionLabel('HEALTH'),
                ),
                _FadeSlideIn(
                  animation: _stage(0.38, 0.78),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MenuCard(children: [
                      _MenuItem(
                        icon: Icons.bloodtype_outlined,
                        tint: const Color(0xFFEF4444),
                        label: 'Medical Info',
                        subtitle: 'Blood group, allergies, conditions',
                        onTap: _openEdit,
                      ),
                      const _MenuDivider(),
                      _MenuItem(
                        icon: Icons.contact_emergency_outlined,
                        tint: const Color(0xFFF59E0B),
                        label: 'Emergency Contact',
                        subtitle: 'Who to call in an emergency',
                        onTap: _openEdit,
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // ── PREFERENCES section ───────────────────────────────
                _FadeSlideIn(
                  animation: _stage(0.46, 0.86),
                  child: const _SectionLabel('PREFERENCES'),
                ),
                _FadeSlideIn(
                  animation: _stage(0.50, 0.90),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MenuCard(children: [

                      _MenuItem(
                        icon: Icons.headset_mic_outlined,
                        tint: const Color(0xFF6366F1),
                        label: 'Help & Support',
                        subtitle: 'FAQs, contact support',
                        onTap: _openterms,
                      ),
                      const _MenuDivider(),
                      _MenuItem(
                        icon: Icons.info_outline_rounded,
                        tint: const Color(0xFF14B8A6),
                        label: 'About MediChain',
                        subtitle: 'Privacy, terms',
                        onTap: _openterms,
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Logout ────────────────────────────────────────────
                _FadeSlideIn(
                  animation: _stage(0.62, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _LogoutButton(onTap: _logout),
                  ),
                ),

                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'MediChain · v1.0.0',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const PatientBottomNav(currentIndex: 3),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Header — avatar, name, email, role pill, edit CTA
// ═══════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final String name;
  final String email;
  final AnimationController avatarPulse;
  final VoidCallback onEdit;

  const _Header({
    required this.name,
    required this.email,
    required this.avatarPulse,
    required this.onEdit,
  });

  String _initials() {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t
        .split(RegExp(r'\s+'))
        .map((p) => p.isEmpty ? '' : p[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, mediaTop + 14, 20, 30),
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
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              // Top row: Edit pill on the right
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.30)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_outlined,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Edit',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Avatar with pulse ring
              SizedBox(
                width: 124,
                height: 124,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: avatarPulse,
                      builder: (context, _) {
                        final t = avatarPulse.value;
                        final size = 92 + 30 * t;
                        final opacity = (1.0 - t) * 0.34;
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
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                            width: 2.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13.5,
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      'PATIENT',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stat row with real animated counts
// ═══════════════════════════════════════════════════════════════════════════
class _StatRow extends StatelessWidget {
  final int records;
  final int doctors;
  final int shared;

  const _StatRow({
    required this.records,
    required this.doctors,
    required this.shared,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'Records',
              value: records,
              icon: Icons.description_outlined,
              tint: AppColors.primary,
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _Stat(
              label: 'Doctors',
              value: doctors,
              icon: Icons.handshake_outlined,
              tint: const Color(0xFF059669),
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _Stat(
              label: 'Shared',
              value: shared,
              icon: Icons.share_outlined,
              tint: const Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tint.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: tint, size: 18),
        ),
        const SizedBox(height: 8),
        _AnimatedCount(
          value: value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: AppColors.border);
}

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

// ═══════════════════════════════════════════════════════════════════════════
// Section label
// ═══════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 20, 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textTertiary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Menu card + items
// ═══════════════════════════════════════════════════════════════════════════
class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.tint,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
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
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.tint.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, color: widget.tint, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Divider(height: 1, thickness: 1, color: AppColors.border),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Logout button + dialog
// ═══════════════════════════════════════════════════════════════════════════
class _LogoutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.accentRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accentRed.withOpacity(0.20)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded,
                  color: AppColors.accentRed, size: 19),
              const SizedBox(width: 8),
              Text(
                'Log out',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.accentRed,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.accentRed, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              'Log out?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You\'ll need to sign in again to access your records.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Log out',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Fade + slide entrance
// ═══════════════════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════════════════
// Data
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileData {
  final String fullName;
  final String email;
  final int records;
  final int doctors;
  final int shared;

  const _ProfileData({
    required this.fullName,
    required this.email,
    required this.records,
    required this.doctors,
    required this.shared,
  });

  factory _ProfileData.zero() => const _ProfileData(
    fullName: 'User',
    email: '',
    records: 0,
    doctors: 0,
    shared: 0,
  );
}
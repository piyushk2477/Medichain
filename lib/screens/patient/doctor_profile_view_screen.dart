import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';
import 'package:medichain_beta/screens/patient/book_appointment_screen.dart';

/// Full doctor profile — all existing logic preserved + Book Appointment.
/// UI polished with entrance animations, pulsing avatar, animated stats.
class DoctorProfileViewScreen extends StatefulWidget {
  final String doctorId;
  const DoctorProfileViewScreen({super.key, required this.doctorId});

  @override
  State<DoctorProfileViewScreen> createState() =>
      _DoctorProfileViewScreenState();
}

class _DoctorProfileViewScreenState extends State<DoctorProfileViewScreen> {
  final _supabase = Supabase.instance.client;
  late Future<_DoctorProfile> _future;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // ── LOGIC PRESERVED EXACTLY ─────────────────────────────────────────────

  Future<_DoctorProfile> _load() async {
    final user = _supabase.auth.currentUser;

    final results = await Future.wait<Map<String, dynamic>?>([
      _supabase
          .from('doctors')
          .select(
        'id, name, specialization, hospital_name, experience_years, '
            'license_number, state, city, address, about, education, '
            'languages, consultation_fee, available_online, profiles(full_name)',
      )
          .eq('id', widget.doctorId)
          .maybeSingle(),
      user == null
          ? Future<Map<String, dynamic>?>.value(null)
          : _supabase
          .from('doctor_requests')
          .select('status')
          .eq('patient_id', user.id)
          .eq('doctor_id', widget.doctorId)
          .maybeSingle(),
    ]);

    return _DoctorProfile(
      doctor: results[0],
      status: (results[1]?['status'] ?? 'none') as String,
    );
  }

  Future<void> _sendRequest() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _acting = true);
    try {
      final existing = await _supabase
          .from('doctor_requests')
          .select('id, status')
          .eq('patient_id', user.id)
          .eq('doctor_id', widget.doctorId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('doctor_requests').insert({
          'patient_id': user.id,
          'doctor_id': widget.doctorId,
          'status': 'pending',
        });
      } else {
        await _supabase
            .from('doctor_requests')
            .update({'status': 'pending'}).eq('id', existing['id']);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Request sent'),
          ]),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() {
        _future = _load();
        _acting = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not send request: $e'),
            backgroundColor: AppColors.accentRed),
      );
      setState(() => _acting = false);
    }
  }

  void _sendData() => Navigator.of(context)
      .pushNamed('/patient/upload', arguments: widget.doctorId);

  void _bookAppointment(Map<String, dynamic> doctor) {
    final name = _nameOf(doctor);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(
          doctorId: widget.doctorId,
          doctorName: name,
          specialization: doctor['specialization'] as String?,
          hospital: doctor['hospital_name'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FutureBuilder<_DoctorProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError ||
              snapshot.data == null ||
              snapshot.data!.doctor == null) {
            return _NotFound(
                error: snapshot.hasError ? '${snapshot.error}' : null);
          }
          return _ProfileBody(
            profile: snapshot.data!,
            acting: _acting,
            onRequest: _sendRequest,
            onSendData: _sendData,
            onBookAppointment: () =>
                _bookAppointment(snapshot.data!.doctor!),
          );
        },
      ),
    );
  }

  String _nameOf(Map<String, dynamic> d) {
    final n = d['name'] as String?;
    if (n != null && n.trim().isNotEmpty) return n;
    final p = d['profiles'] as Map<String, dynamic>?;
    return (p?['full_name'] as String?) ?? 'Doctor';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Profile body — Stateful for animations
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileBody extends StatefulWidget {
  final _DoctorProfile profile;
  final bool acting;
  final VoidCallback onRequest;
  final VoidCallback onSendData;
  final VoidCallback onBookAppointment;

  const _ProfileBody({
    required this.profile,
    required this.acting,
    required this.onRequest,
    required this.onSendData,
    required this.onBookAppointment,
  });

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _avatarPulse;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _avatarPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
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

  String _nameOf(Map<String, dynamic> d) {
    final n = d['name'] as String?;
    if (n != null && n.trim().isNotEmpty) return n;
    final p = d['profiles'] as Map<String, dynamic>?;
    return (p?['full_name'] as String?) ?? 'Doctor';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.profile.doctor!;
    final status = widget.profile.status;
    final name = _nameOf(d);
    final spec = d['specialization'] as String?;
    final hosp = d['hospital_name'] as String?;
    final license = d['license_number'] as String?;
    final years = d['experience_years'];
    final city = d['city'] as String?;
    final state = d['state'] as String?;
    final address = d['address'] as String?;
    final about = d['about'] as String?;
    final edu = d['education'] as String?;
    final fee = d['consultation_fee'] as int?;
    final online = (d['available_online'] ?? false) as bool;
    final langs =
        (d['languages'] as List?)?.whereType<String>().toList() ?? [];
    final initials = _initials(name);

    final locationStr = [
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
    ].join(', ');

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // ── Hero header with pulsing avatar ────────────────────
            SliverToBoxAdapter(
              child: _HeroHeader(
                initials: initials,
                name: name,
                spec: spec,
                edu: edu,
                status: status,
                online: online,
                fee: fee,
                locationStr: locationStr,
                avatarPulse: _avatarPulse,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // ── Stats row with animated counters ───────────────────
            SliverToBoxAdapter(
              child: _FadeSlideIn(
                animation: _stage(0.0, 0.40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Experience',
                          tint: AppColors.primary,
                          fallback: years == null ? '—' : null,
                          numericValue: years is int ? years : null,
                          valueSuffix: ' yrs',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Fee',
                          tint: AppColors.success,
                          fallback: fee == null ? '—' : null,
                          numericValue: fee,
                          valuePrefix: '₹',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.verified_user_rounded,
                          label: 'License',
                          tint: const Color(0xFF8B5CF6),
                          fallback: (license == null || license.isEmpty)
                              ? '—'
                              : 'Verified',
                          numericValue: null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // ── Quick action chips ─────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeSlideIn(
                animation: _stage(0.10, 0.50),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _QuickActionRow(
                    online: online,
                    fee: fee,
                    onBookAppointment: widget.onBookAppointment,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // ── About ──────────────────────────────────────────────
            if (about != null && about.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _FadeSlideIn(
                  animation: _stage(0.20, 0.60),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('About the Doctor'),
                        const SizedBox(height: 10),
                        _InfoCard(children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(about,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    height: 1.55)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],

            // ── Qualifications ─────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeSlideIn(
                animation: _stage(0.28, 0.68),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('Qualifications'),
                      const SizedBox(height: 10),
                      _InfoCard(children: [
                        if (edu != null && edu.isNotEmpty)
                          _InfoRow(
                              icon: Icons.school_outlined,
                              label: 'Education',
                              value: edu),
                        if (edu != null && edu.isNotEmpty && spec != null)
                          const _InfoDivider(),
                        if (spec != null && spec.isNotEmpty)
                          _InfoRow(
                              icon: Icons.healing_outlined,
                              label: 'Specialization',
                              value: spec),
                        if (spec != null && spec.isNotEmpty)
                          const _InfoDivider(),
                        _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'License number',
                            value: license,
                            isLast: true),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // ── Location ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeSlideIn(
                animation: _stage(0.36, 0.76),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('Location'),
                      const SizedBox(height: 10),
                      _InfoCard(children: [
                        if (hosp != null && hosp.isNotEmpty) ...[
                          _InfoRow(
                              icon: Icons.local_hospital_outlined,
                              label: 'Hospital / Clinic',
                              value: hosp),
                          const _InfoDivider(),
                        ],
                        if (address != null && address.isNotEmpty) ...[
                          _InfoRow(
                              icon: Icons.home_outlined,
                              label: 'Address',
                              value: address),
                          const _InfoDivider(),
                        ],
                        _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'City & State',
                            value: locationStr.isEmpty ? null : locationStr,
                            isLast: langs.isEmpty && !online),
                        if (online) ...[
                          const _InfoDivider(),
                          _OnlineBadgeRow(),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // ── Languages ──────────────────────────────────────────
            if (langs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _FadeSlideIn(
                  animation: _stage(0.44, 0.84),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Languages'),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: langs
                                .map((lang) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withOpacity(0.08),
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons.language_rounded,
                                      size: 13,
                                      color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(lang,
                                      style: GoogleFonts
                                          .plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight:
                                          FontWeight.w600,
                                          color: AppColors
                                              .primary)),
                                ],
                              ),
                            ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],

            // ── Connection card ─────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeSlideIn(
                animation: _stage(0.52, 0.92),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ConnectionCard(status: status, name: name),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),

        // ── Sticky action area ──────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: _ActionButton(
                  status: status,
                  acting: widget.acting,
                  onRequest: widget.onRequest,
                  onSendData: widget.onSendData,
                  onBookAppointment: widget.onBookAppointment,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Quick action row with press-scale
// ═══════════════════════════════════════════════════════════════════════════
class _QuickActionRow extends StatefulWidget {
  final bool online;
  final int? fee;
  final VoidCallback onBookAppointment;

  const _QuickActionRow({
    required this.online,
    required this.fee,
    required this.onBookAppointment,
  });

  @override
  State<_QuickActionRow> createState() => _QuickActionRowState();
}

class _QuickActionRowState extends State<_QuickActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onBookAppointment,
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 110),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('Book Appointment',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.online) ...[
          const SizedBox(width: 10),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border:
              Border.all(color: AppColors.success.withOpacity(0.30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PulseDot(color: AppColors.success, size: 7),
                const SizedBox(width: 6),
                Text('Online',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Hero header with pulsing avatar ring
// ═══════════════════════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  final String initials;
  final String name;
  final String? spec;
  final String? edu;
  final String status;
  final bool online;
  final int? fee;
  final String locationStr;
  final AnimationController avatarPulse;

  const _HeroHeader({
    required this.initials,
    required this.name,
    required this.spec,
    required this.edu,
    required this.status,
    required this.online,
    required this.fee,
    required this.locationStr,
    required this.avatarPulse,
  });

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: mediaTop),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), AppColors.primary, Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: 20,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2))),
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const Spacer(),
                    _StatusPill(status: status),
                  ],
                ),
                const SizedBox(height: 16),
                // Avatar with pulse ring
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: avatarPulse,
                        builder: (context, _) {
                          final t = avatarPulse.value;
                          final size = 100 + 36 * t;
                          final op = (1 - t) * 0.32;
                          return Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(op),
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
                              width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 26,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(initials,
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                      ),
                      if (online)
                        Positioned(
                          right: 18,
                          bottom: 18,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border:
                              Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.videocam_rounded,
                                color: Colors.white, size: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Dr. $name',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4),
                    textAlign: TextAlign.center),
                if (edu != null && edu!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(edu!,
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
                if (spec != null && spec!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Text(spec!,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (locationStr.isNotEmpty) ...[
                      const Icon(Icons.location_on_rounded,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(locationStr,
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                    if (locationStr.isNotEmpty && fee != null)
                      Text('  ·  ',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6))),
                    if (fee != null) ...[
                      const Icon(Icons.currency_rupee_rounded,
                          color: Colors.white70, size: 14),
                      Text('$fee consultation',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(
                        5,
                            (i) => Icon(
                            i < 4
                                ? Icons.star_rounded
                                : Icons.star_half_rounded,
                            color: const Color(0xFFFBBF24),
                            size: 16)),
                    const SizedBox(width: 6),
                    Text('4.8  ·  50+ patients',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color dot, String label) = switch (status) {
      'accepted' => (AppColors.success, 'Connected'),
      'pending' => (AppColors.warning, 'Pending'),
      'rejected' => (AppColors.accentRed, 'Declined'),
      _ => (Colors.white, 'Not connected'),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(status),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 7,
                height: 7,
                decoration:
                BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stat card with animated counter when numeric
// ═══════════════════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final String? fallback;
  final int? numericValue;
  final String valuePrefix;
  final String valueSuffix;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.tint,
    this.fallback,
    this.numericValue,
    this.valuePrefix = '',
    this.valueSuffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: tint.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tint.withOpacity(0.18), tint.withOpacity(0.10)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(height: 10),
          if (numericValue != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (valuePrefix.isNotEmpty)
                  Text(valuePrefix,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                _AnimatedCount(
                  value: numericValue!,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                if (valueSuffix.isNotEmpty)
                  Text(valueSuffix,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
              ],
            )
          else
            Text(fallback ?? '—',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
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
// Section helpers
// ═══════════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.3));
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]),
    child: Column(children: children),
  );
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Divider(height: 1, thickness: 1, color: AppColors.border),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool isLast;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.14),
                  AppColors.primary.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(
                  empty ? 'Not provided' : value!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: empty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
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

class _OnlineBadgeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withOpacity(0.18),
                  AppColors.success.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.videocam_rounded,
                color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Online consultations',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const PulseDot(color: AppColors.success, size: 7),
                    const SizedBox(width: 6),
                    Text('Available for video consultations',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Connection card with smooth transitions
// ═══════════════════════════════════════════════════════════════════════════
class _ConnectionCard extends StatelessWidget {
  final String status;
  final String name;
  const _ConnectionCard({required this.status, required this.name});

  @override
  Widget build(BuildContext context) {
    final (Color col, IconData icon, String header) = switch (status) {
      'accepted' => (AppColors.success, Icons.verified_rounded, 'CONNECTED'),
      'pending' => (
      AppColors.warning,
      Icons.hourglass_top_rounded,
      'REQUEST IN REVIEW'
      ),
      'rejected' => (
      AppColors.accentRed,
      Icons.cancel_outlined,
      'REQUEST DECLINED'
      ),
      _ => (AppColors.primary, Icons.handshake_outlined, 'NOT YET CONNECTED'),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: col.withOpacity(0.30)),
        boxShadow: [
          BoxShadow(
            color: col.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: col.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(17),
                  topRight: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Icon(icon, color: col, size: 16),
                const SizedBox(width: 8),
                Text(header,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: col,
                        letterSpacing: 1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.medical_services_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dr. $name',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      Text(
                        switch (status) {
                          'accepted' => 'You can now share records',
                          'pending' => 'Awaiting approval',
                          'rejected' => 'You can send a new request',
                          _ => 'Send a request to connect',
                        },
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════
// Sticky action button
// ═══════════════════════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final String status;
  final bool acting;
  final VoidCallback onRequest;
  final VoidCallback onSendData;
  final VoidCallback onBookAppointment;

  const _ActionButton({
    required this.status,
    required this.acting,
    required this.onRequest,
    required this.onSendData,
    required this.onBookAppointment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == 'accepted')
          ElevatedButton.icon(
            onPressed: onSendData,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.send_rounded, size: 17),
            label: Text('Send Records',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800, fontSize: 15)),
          )
        else if (status == 'pending')
          ElevatedButton.icon(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.grey.shade500,
            ),
            icon: const Icon(Icons.hourglass_top_rounded, size: 17),
            label: Text('Request Pending',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800, fontSize: 15)),
          )
        else
          ElevatedButton.icon(
            onPressed: acting ? null : onRequest,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
            icon: acting
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
                : const Icon(Icons.handshake_rounded, size: 17),
            label: Text(
              acting
                  ? 'Sending…'
                  : (status == 'rejected'
                  ? 'Send Request Again'
                  : 'Send Connection Request'),
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onBookAppointment,
          icon: const Icon(Icons.calendar_month_rounded, size: 17),
          label: Text('Book Appointment',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, fontSize: 15)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Not found
// ═══════════════════════════════════════════════════════════════════════════
class _NotFound extends StatelessWidget {
  final String? error;
  const _NotFound({this.error});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop()),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.accentRed.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.error_outline,
                          size: 42, color: AppColors.accentRed),
                    ),
                    const SizedBox(height: 16),
                    Text(error ?? 'Doctor not found.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

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
// Model
// ═══════════════════════════════════════════════════════════════════════════
class _DoctorProfile {
  final Map<String, dynamic>? doctor;
  final String status;
  _DoctorProfile({required this.doctor, required this.status});
}

String _initials(String name) {
  if (name.trim().isEmpty) return 'DR';
  return name
      .trim()
      .split(RegExp(r'\s+'))
      .map((p) => p.isEmpty ? '' : p[0])
      .take(2)
      .join()
      .toUpperCase();
}
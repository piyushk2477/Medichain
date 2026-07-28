import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medichain_beta/services/appointment_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/wallet_setup_dialog.dart';

import 'doctor_profile_edit_screen.dart';
import 'patient_records_screen.dart';
import 'patient_request_detail_screen.dart';

/// 3 main tabs: Requests (2 inner tabs) | Patients | Profile
class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});
  @override
  State<DoctorDashboardScreen> createState() => _State();
}

class _State extends State<DoctorDashboardScreen> {
  int _index = 0;
  int _refreshKey = 0;
  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    final body = switch (_index) {
      0 => _RequestsTab(key: ValueKey(_refreshKey), onChanged: _refresh),
      1 => _PatientsTab(key: const ValueKey('p')),
      _ => _ProfileTab(key: const ValueKey('pr'), onChanged: _refresh),
    };
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: body,
      ),
      bottomNavigationBar: _Nav(index: _index, onChanged: (i) => setState(() => _index = i)),
    );
  }
}

// ── Bottom nav ─────────────────────────────────────────────────────────────

class _Nav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _Nav({required this.index, required this.onChanged});

  static const _items = [
    (Icons.inbox_outlined,         Icons.inbox_rounded,    'Requests'),
    (Icons.people_outline_rounded, Icons.people_rounded,   'Patients'),
    (Icons.person_outline_rounded, Icons.person_rounded,   'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.06),
            blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: List.generate(_items.length, (i) {
              final sel = i == index;
              final (off, on, label) = _items[i];
              return Expanded(child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44, height: 36,
                      decoration: BoxDecoration(
                        gradient: sel ? const LinearGradient(
                          colors: [Color(0xFF3B82F6), AppColors.primary],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ) : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(sel ? on : off, size: 22,
                          color: sel ? Colors.white : AppColors.textTertiary),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: TextStyle(
                      fontSize: 11,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? AppColors.textPrimary : AppColors.textTertiary,
                    )),
                  ]),
                ),
              ));
            }),
          ),
        ),
      ),
    );
  }
}

// ── Branded gradient header ─────────────────────────────────────────────────

class _GradHeader extends StatelessWidget {
  final String name;
  final List<_Stat>? stats;
  final List<Widget>? actions;
  const _GradHeader({required this.name, this.stats, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), AppColors.primary, Color(0xFF1D4ED8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(children: [
        Positioned(right: -50, top: 10,
            child: Container(width: 190, height: 190,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06), shape: BoxShape.circle))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: Colors.white.withOpacity(0.22)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.medical_services_rounded,
                          color: Colors.white, size: 20)),
                  const Spacer(),
                  if (actions != null) ...actions!,
                ]),
                const SizedBox(height: 18),
                Text('Welcome back', style: TextStyle(
                    color: Colors.white.withOpacity(0.75), fontSize: 13)),
                const SizedBox(height: 3),
                Text(name, style: const TextStyle(
                    color: Colors.white, fontSize: 24,
                    fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                if (stats != null && stats!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(children: [
                    for (var i = 0; i < stats!.length; i++) ...[
                      Expanded(child: _StatTile(s: stats![i])),
                      if (i < stats!.length - 1) const SizedBox(width: 10),
                    ],
                  ]),
                ],
              ]),
        ),
      ]),
    );
  }
}

class _Stat {
  final String value, label;
  final bool dot;
  const _Stat(this.value, this.label, {this.dot = false});
}

class _StatTile extends StatelessWidget {
  final _Stat s;
  const _StatTile({required this.s});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, children: [
          if (s.dot)
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(s.value, style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ])
          else
            Text(s.value, style: const TextStyle(
                color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w800, height: 1.0)),
          const SizedBox(height: 5),
          Text(s.label, style: TextStyle(
              color: Colors.white.withOpacity(0.75), fontSize: 10,
              fontWeight: FontWeight.w600, letterSpacing: 1.1)),
        ]),
  );
}

class _HBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _HBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 18)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// TAB 0 — Requests  (2 inner sub-tabs: Connections | Appointments)
// ══════════════════════════════════════════════════════════════════════════

class _RequestsTab extends StatefulWidget {
  final VoidCallback onChanged;
  const _RequestsTab({super.key, required this.onChanged});
  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;
  late TabController _tc;
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _tc     = TabController(length: 2, vsync: this);
    _future = _load();
    // rebuild when inner tab changes so correct list shows
    _tc.addListener(() { if (!_tc.indexIsChanging) setState(() {}); });
  }

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  Future<_Data> _load() async {
    final user = _sb.auth.currentUser;
    if (user == null) return _Data.empty();

    final doc = await _sb.from('doctors')
        .select('id, name, hospital_name')
        .eq('profile_id', user.id).maybeSingle();
    if (doc == null) return _Data.empty();

    final did = doc['id'] as String;
    final res = await Future.wait([
      _sb.from('doctor_requests')
          .select('id, created_at, patient_id, '
          'patient:profiles!patient_id(id, full_name, email)')
          .eq('doctor_id', did).eq('status', 'pending')
          .order('created_at', ascending: false),
      _sb.from('doctor_requests')
          .select('id').eq('doctor_id', did).eq('status', 'accepted'),
      _sb.from('appointment_requests')
          .select('id, preferred_date, preferred_time, notes, created_at, '
          'patient:profiles!appt_fk_patient(id, full_name, email)')
          .eq('doctor_id', did).eq('status', 'pending')
          .order('created_at', ascending: true),
    ]);

    return _Data(
      name:         (doc['name'] as String?) ?? 'Doctor',
      hospital:     doc['hospital_name'] as String?,
      connections:  (res[0] as List).cast<Map<String, dynamic>>(),
      accepted:     (res[1] as List).length,
      appointments: (res[2] as List).cast<Map<String, dynamic>>(),
    );
  }

  void _reload() => setState(() { _future = _load(); widget.onChanged(); });

  // ── Accept / Reject connection ──────────────────────────────────────────

  Future<void> _setConn(String id, String status) async {
    await _sb.from('doctor_requests').update({'status': status}).eq('id', id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(status == 'accepted' ? 'Accepted' : 'Rejected'),
      backgroundColor: status == 'accepted' ? AppColors.success : AppColors.textPrimary,
    ));
    _reload();
  }

  // ── Confirm appointment ─────────────────────────────────────────────────

  Future<void> _confirmAppt(Map<String, dynamic> req, _Data d) async {
    final p     = req['patient'] as Map? ?? {};
    final pName = (p['full_name'] as String?) ?? 'Patient';
    final pMail = (p['email']    as String?) ?? '';

    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        patientName:   pName,
        preferredDate: req['preferred_date'] as String? ?? '',
        preferredTime: req['preferred_time'] as String? ?? '',
      ),
    );
    if (res == null || !mounted) return;

    final bar = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: const [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 10), Text('Sending confirmation email…'),
      ]),
      duration: const Duration(seconds: 30),
      backgroundColor: AppColors.primary,
    ));

    try {
      await AppointmentService.confirmAppointment(
        requestId:     req['id'] as String,
        patientEmail:  pMail,
        patientName:   pName,
        doctorName:    d.name,
        hospital:      d.hospital,
        confirmedDate: res['date'] as DateTime,
        confirmedTime: res['time'] as String,
      );
      bar.close();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: const [
          Icon(Icons.mark_email_read_outlined, color: Colors.white),
          SizedBox(width: 8),
          Expanded(child: Text('Confirmed! Email sent.')),
        ]),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
      ));
      _reload();
    } catch (e) {
      bar.close();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentRed));
    }
  }

  // ── Decline appointment ─────────────────────────────────────────────────

  Future<void> _declineAppt(String id, String name) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text("Decline $name's appointment request?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
              child: const Text('Decline')),
        ],
      ),
    );
    if (ok != true) return;
    await AppointmentService.declineAppointment(id);
    _reload();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Data>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final d = snap.data ?? _Data.empty();

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async { _reload(); await _future; },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [

              // Header
              SliverToBoxAdapter(child: _GradHeader(
                name: loading ? 'Loading…' : 'Dr. ${d.name}',
                actions: const [_HBtn(icon: Icons.notifications_none_rounded)],
                stats: [
                  _Stat('${d.connections.length}',  'CONNECTIONS'),
                  _Stat('${d.appointments.length}', 'APPOINTMENTS'),
                  _Stat('${d.accepted}',            'PATIENTS'),
                ],
              )),

              // Inner tab bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tc,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textTertiary,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                    tabs: [
                      _BadgeTab(
                        label: 'Connections',
                        count: d.connections.length,
                        color: AppColors.primary,
                      ),
                      _BadgeTab(
                        label: 'Appointments',
                        count: d.appointments.length,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ),

              // List content
              if (loading)
                const SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (_tc.index == 0)
              // ── Connections list ────────────────────────────────
                d.connections.isEmpty
                    ? const SliverFillRemaining(hasScrollBody: false,
                    child: _Empty(Icons.inbox_outlined,
                        'No connection requests',
                        'New patient requests will appear here.'))
                    : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: d.connections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final r = d.connections[i];
                      final p = r['patient'] as Map? ?? {};
                      final id   = r['id']          as String;
                      final pid  = r['patient_id']  as String;
                      final nm   = (p['full_name']  as String?) ?? 'Patient';
                      final em   = p['email']       as String?;
                      final ca   = r['created_at']  as String?;
                      return _Stagger(i, _ConnCard(
                        id:        id,
                        name:      nm,
                        email:     em,
                        timeAgo:   ca != null ? _ago(DateTime.parse(ca)) : null,
                        onDetail:  () async {
                          final res = await Navigator.of(context).push<String>(
                              MaterialPageRoute(builder: (_) =>
                                  PatientRequestDetailScreen(requestId: id)));
                          if (res == 'accepted' || res == 'rejected') _reload();
                        },
                        onAccept: () => _setConn(id, 'accepted'),
                        onReject: () => _setConn(id, 'rejected'),
                      ));
                    },
                  ),
                )
              else
              // ── Appointments list ───────────────────────────────
                d.appointments.isEmpty
                    ? const SliverFillRemaining(hasScrollBody: false,
                    child: _Empty(Icons.event_available_rounded,
                        'No appointment requests',
                        'Patient appointment requests will appear here.'))
                    : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: d.appointments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final r = d.appointments[i];
                      final p = r['patient'] as Map? ?? {};
                      return _Stagger(i, _ApptCard(
                        request:   r,
                        onConfirm: () => _confirmAppt(r, d),
                        onDecline: () => _declineAppt(
                            r['id'] as String,
                            (p['full_name'] as String?) ?? 'Patient'),
                      ));
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

class _Data {
  final String name;
  final String? hospital;
  final List<Map<String, dynamic>> connections, appointments;
  final int accepted;
  _Data({required this.name, this.hospital, required this.connections,
    required this.appointments, required this.accepted});
  factory _Data.empty() => _Data(name: 'Doctor',
      connections: const [], appointments: const [], accepted: 0);
}

// ── Pinned tab bar delegate ─────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar bar;
  const _TabBarDelegate(this.bar);
  @override double get minExtent => 50;
  @override double get maxExtent => 50;
  @override bool shouldRebuild(_) => true;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: Column(children: [
        Expanded(child: bar),
        const Divider(height: 1, color: AppColors.border),
      ]),
    );
  }
}

// ── Tab with optional count badge ───────────────────────────────────────────

class _BadgeTab extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _BadgeTab({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 6),
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ]),
  );
}

// ── Connection request card ─────────────────────────────────────────────────

class _ConnCard extends StatelessWidget {
  final String id, name;
  final String? email, timeAgo;
  final VoidCallback onDetail, onAccept, onReject;
  const _ConnCard({required this.id, required this.name,
    this.email, this.timeAgo,
    required this.onDetail, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _Avatar(name: name, colors: const [Color(0xFF3B82F6), AppColors.primary]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                if (email != null)
                  Text(email!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ])),
              if (timeAgo != null)
                Text(timeAgo!, style: const TextStyle(
                    fontSize: 11, color: AppColors.textTertiary)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: AppColors.accentRed,
                  side: BorderSide(color: AppColors.accentRed.withOpacity(0.4)),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Appointment request card ────────────────────────────────────────────────

class _ApptCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onConfirm, onDecline;
  const _ApptCard({required this.request, required this.onConfirm, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final p    = request['patient'] as Map? ?? {};
    final name = (p['full_name'] as String?) ?? 'Patient';
    final mail = (p['email']    as String?) ?? '';
    final date = request['preferred_date'] as String? ?? '';
    final time = request['preferred_time'] as String? ?? '';
    final note = request['notes'] as String?;
    final ca   = request['created_at'] as String?;

    String dLabel = date;
    try { dLabel = DateFormat('EEE, d MMM yyyy').format(DateTime.parse(date)); }
    catch (_) {}

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Avatar(name: name, colors: const [Color(0xFF60A5FA), AppColors.primary]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 15.5,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(mail, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('PENDING', style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w800, color: AppColors.warning, letterSpacing: 0.8)),
          ),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.border)),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _Chip(Icons.calendar_today_outlined, dLabel, AppColors.primary),
          _Chip(Icons.schedule_outlined, time, const Color(0xFF8B5CF6)),
          if (ca != null)
            _Chip(Icons.access_time_outlined, _ago(DateTime.parse(ca)),
                AppColors.textTertiary),
        ]),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface,
                borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.notes_rounded, size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Expanded(child: Text(note, style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.4))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onDecline,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Decline'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: AppColors.accentRed,
              side: BorderSide(color: AppColors.accentRed.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Confirm & Email'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ]),
      ]),
    );
  }
}

// ── Confirm bottom sheet ────────────────────────────────────────────────────

class _ConfirmSheet extends StatefulWidget {
  final String patientName, preferredDate, preferredTime;
  const _ConfirmSheet({required this.patientName,
    required this.preferredDate, required this.preferredTime});
  @override
  State<_ConfirmSheet> createState() => _CSState();
}

class _CSState extends State<_ConfirmSheet> {
  late DateTime _date;
  String? _time;
  static const _slots = [
    '9:00 AM','9:30 AM','10:00 AM','10:30 AM','11:00 AM','11:30 AM',
    '1:00 PM','1:30 PM','2:00 PM','2:30 PM','3:00 PM','3:30 PM',
    '4:00 PM','5:00 PM','5:30 PM','6:00 PM','6:30 PM','7:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    try { _date = DateTime.parse(widget.preferredDate); }
    catch (_) { _date = DateTime.now().add(const Duration(days: 1)); }
    _time = widget.preferredTime;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: AppColors.border,
                borderRadius: BorderRadius.circular(4))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), AppColors.primary],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Confirm Appointment', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Text('for ${widget.patientName}', style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
            ])),
            IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(11),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Patient preferred: ${widget.preferredDate} at ${widget.preferredTime}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                )),
              ]),
            ),
            const Text('Pick confirmed date', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border)),
              child: CalendarDatePicker(
                initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 60)),
                onDateChanged: (d) => setState(() => _date = d),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Pick confirmed time', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: _slots.map((s) {
                final sel = s == _time;
                return InkWell(
                  onTap: () => setState(() => _time = s),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? AppColors.primary : AppColors.border,
                          width: sel ? 1.5 : 1),
                    ),
                    child: Text(s, style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _time == null
                  ? null
                  : () => Navigator.pop(context, {'date': _date, 'time': _time}),
              icon: const Icon(Icons.mark_email_read_outlined, size: 18),
              label: const Text('Confirm & Send Email',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ]),
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// TAB 1 — Patients
// ══════════════════════════════════════════════════════════════════════════

class _PatientsTab extends StatefulWidget {
  const _PatientsTab({super.key});
  @override
  State<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<_PatientsTab> {
  final _sb = Supabase.instance.client;
  late Future<_PData> _future;
  String _q = '';

  @override
  void initState() { super.initState(); _future = _load(); }

  Future<_PData> _load() async {
    final user = _sb.auth.currentUser;
    if (user == null) return _PData.empty();
    final doc = await _sb.from('doctors')
        .select('id, name').eq('profile_id', user.id).maybeSingle();
    if (doc == null) return _PData.empty();
    final rows = await _sb.from('doctor_requests')
        .select('patient_id, patient:profiles!patient_id(id, full_name, email)')
        .eq('doctor_id', doc['id'] as String).eq('status', 'accepted');
    return _PData(
      name: (doc['name'] as String?) ?? 'Doctor',
      items: (rows as List).map((r) {
        final p = (r as Map)['patient'] as Map? ?? {};
        return (
        id:    (p['id'] ?? r['patient_id']) as String,
        name:  (p['full_name'] as String?) ?? 'Patient',
        email: p['email'] as String?,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async { setState(() => _future = _load()); await _future; },
      child: FutureBuilder<_PData>(
        future: _future,
        builder: (ctx, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final d       = snap.data ?? _PData.empty();
          final list    = _q.isEmpty ? d.items
              : d.items.where((x) => x.name.toLowerCase().contains(_q.toLowerCase())).toList();
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _GradHeader(
                name:    loading ? 'Loading…' : 'Dr. ${d.name}',
                actions: const [_HBtn(icon: Icons.notifications_none_rounded)],
                stats:   [_Stat('${d.items.length}', 'PATIENTS'),
                  const _Stat('Active', 'STATUS', dot: true)],
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Search patients…',
                    filled: true, fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textTertiary, size: 22),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                ),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (loading)
                const SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()))
              else if (list.isEmpty)
                SliverFillRemaining(hasScrollBody: false,
                    child: _Empty(
                      d.items.isEmpty ? Icons.people_outline : Icons.search_off_rounded,
                      d.items.isEmpty ? 'No patients yet' : 'No matches',
                      d.items.isEmpty ? 'Accepted patients appear here.' : 'Try another search.',
                    ))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final pt = list[i];
                      return _Stagger(i, Material(color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PatientRecordsScreen(
                                  patientId: pt.id, patientName: pt.name))),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border)),
                            child: Row(children: [
                              _Avatar(name: pt.name,
                                  colors: const [Color(0xFF60A5FA), AppColors.primary]),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pt.name, style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                                  if (pt.email != null)
                                    Text(pt.email!, maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13, color: AppColors.textSecondary)),
                                ],
                              )),
                              Container(width: 30, height: 30,
                                  decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(9)),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.chevron_right_rounded,
                                      color: AppColors.primary, size: 18)),
                            ]),
                          ),
                        ),
                      ));
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

typedef _PatRec = ({String id, String name, String? email});

class _PData {
  final String name;
  final List<_PatRec> items;
  _PData({required this.name, required this.items});
  factory _PData.empty() => _PData(name: 'Doctor', items: const []);
}

// ══════════════════════════════════════════════════════════════════════════
// TAB 2 — Profile
// ══════════════════════════════════════════════════════════════════════════

class _ProfileTab extends StatefulWidget {
  final VoidCallback onChanged;
  const _ProfileTab({super.key, required this.onChanged});
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _sb = Supabase.instance.client;
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() { super.initState(); _future = _load(); }

  Future<Map<String, dynamic>?> _load() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;
    return _sb.from('doctors').select().eq('profile_id', user.id).maybeSingle();
  }

  Future<void> _signOut() async {
    await _sb.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _edit() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const DoctorProfileEditScreen(isEditing: true)));
    if (ok == true) { widget.onChanged(); setState(() => _future = _load()); }
  }

  Future<void> _changeWallet() async {
    final result = await showWalletSetupDialog(context);
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final d    = snap.data;
        final name = (d?['name'] as String?) ?? 'Doctor';
        final spec = d?['specialization'] as String?;
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), AppColors.primary, Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.white),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      backgroundColor: Colors.white.withOpacity(0.14),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                _Avatar(name: name, size: 88, fontSize: 28,
                    colors: const [Color(0xFF3B82F6), AppColors.primary]),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                if (spec != null) ...[
                  const SizedBox(height: 4),
                  Text(spec, style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 14)),
                ],
              ]),
            ),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Card(children: [
              _Row(Icons.badge_outlined,          'License',
                  _val(d?['license_number'])),
              const _Div(),
              _Row(Icons.local_hospital_outlined, 'Hospital',
                  _val(d?['hospital_name'])),
              const _Div(),
              _Row(Icons.timeline_outlined,       'Experience',
                  d?['experience_years'] == null
                      ? 'Not set' : '${d!['experience_years']} years'),
            ]),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Card(children: [
              _Row(Icons.edit_outlined,       'Edit Profile',  null, onTap: _edit),
              const _Div(),
              _Row(Icons.account_balance_wallet_outlined, 'Wallet', null, onTap: _changeWallet),
              const _Div(),
              _Row(Icons.headset_mic_outlined, 'Support',      null,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support coming soon.')))),
            ]),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(color: AppColors.accentRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(onTap: _signOut,
                borderRadius: BorderRadius.circular(16),
                child: Container(width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Icon(Icons.logout_rounded, color: AppColors.accentRed, size: 18),
                    SizedBox(width: 8),
                    Text('Log out', style: TextStyle(
                        color: AppColors.accentRed, fontSize: 15,
                        fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ]);
      },
    );
  }

  String _val(dynamic v) => (v as String?)?.isNotEmpty == true ? v! : 'Not set';
}

// ══════════════════════════════════════════════════════════════════════════
// Shared small widgets
// ══════════════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final String name;
  final List<Color> colors;
  final double size;
  final double fontSize;
  const _Avatar({required this.name, required this.colors,
    this.size = 48, this.fontSize = 15});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors,
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(size * 0.28),
    ),
    alignment: Alignment.center,
    child: Text(_ini(name), style: TextStyle(
        color: Colors.white, fontWeight: FontWeight.w800, fontSize: fontSize)),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12.5,
          fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border)),
    child: Column(children: children),
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  const _Row(this.icon, this.label, this.value, {this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary, size: 18)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              if (value != null)
                Text(value!, style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            ])),
        if (onTap != null)
          const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
      ]),
    ),
  );
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Divider(height: 1, color: AppColors.border),
  );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _Empty(this.icon, this.title, this.sub);
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 84, height: 84,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 34, color: AppColors.primary)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text(sub, textAlign: TextAlign.center, style: const TextStyle(
          fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
    ]),
  ));
}

class _Stagger extends StatefulWidget {
  final int index;
  final Widget child;
  const _Stagger(this.index, this.child);
  @override
  State<_Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<_Stagger> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 360));
    Future.delayed(Duration(milliseconds: (widget.index * 50).clamp(0, 300)),
            () { if (mounted) _c.forward(); });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _c,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
        child: widget.child,
      ));
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String _ini(String n) {
  if (n.trim().isEmpty) return '?';
  return n.trim().split(RegExp(r'\s+')).map((p) => p.isEmpty ? '' : p[0])
      .take(2).join().toUpperCase();
}

String _ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${d.day}/${d.month}/${d.year}';
}
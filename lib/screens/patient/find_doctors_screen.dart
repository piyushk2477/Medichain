import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'doctor_profile_view_screen.dart';

/// Patient-facing screen with two tabs:
///   • Browse — all doctors, searchable, with status (none/pending/accepted)
///   • My Doctors — only accepted doctors, tap to send data
class FindDoctorsScreen extends StatefulWidget {
  const FindDoctorsScreen({super.key});

  @override
  State<FindDoctorsScreen> createState() => _FindDoctorsScreenState();
}

class _FindDoctorsScreenState extends State<FindDoctorsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Cached fetch — rebuilds when refreshed or after a request is sent.
  late Future<_DoctorsData> _future;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _future = _load();
    _searchCtrl.addListener(() {
      if (_query != _searchCtrl.text) {
        setState(() => _query = _searchCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<_DoctorsData> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return _DoctorsData.empty();

    final results = await Future.wait([
      _supabase
          .from('doctors')
          .select('id, specialization, hospital_name, experience_years, '
          'license_number, name, profiles(full_name)')
          .order('created_at', ascending: false),
      _supabase
          .from('doctor_requests')
          .select('doctor_id, status')
          .eq('patient_id', user.id),
    ]);

    final doctors = (results[0] as List).cast<Map<String, dynamic>>();
    final requests = (results[1] as List).cast<Map<String, dynamic>>();

    final statusByDoctor = <String, String>{
      for (final r in requests)
        r['doctor_id'] as String: (r['status'] ?? 'pending') as String,
    };

    return _DoctorsData(doctors: doctors, statusByDoctor: statusByDoctor);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5FA),
        elevation: 0,
        title: const Text(
          'Doctors',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by name, specialty, hospital',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon:
                      Icon(Icons.search, color: Colors.grey[600]),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tab,
                indicatorColor: const Color(0xFF6C63FF),
                indicatorWeight: 3,
                labelColor: const Color(0xFF6C63FF),
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Browse'),
                  Tab(text: 'My Doctors'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<_DoctorsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            );
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: '${snapshot.error}',
              onRetry: _refresh,
            );
          }
          final data = snapshot.data ?? _DoctorsData.empty();
          return TabBarView(
            controller: _tab,
            children: [
              _BrowseTab(
                data: data,
                query: _query,
                onChanged: _refresh,
              ),
              _MyDoctorsTab(
                data: data,
                onChanged: _refresh,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Browse tab — all doctors, status-aware request button
// ---------------------------------------------------------------------------

class _BrowseTab extends StatelessWidget {
  final _DoctorsData data;
  final String query;
  final VoidCallback onChanged;

  const _BrowseTab({
    required this.data,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = _filter(data.doctors, query);

    if (filtered.isEmpty) {
      return _EmptyView(
        icon: Icons.search_off,
        title: query.isEmpty
            ? 'No doctors available yet'
            : 'No matches for "$query"',
        subtitle: query.isEmpty
            ? 'Check back soon — new doctors join regularly.'
            : 'Try a different name, specialty or hospital.',
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6C63FF),
      onRefresh: () async => onChanged(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final d = filtered[i];
          final id = d['id'] as String;
          final status = data.statusByDoctor[id] ?? 'none';
          return _DoctorCard(
            doctor: d,
            status: status,
            onTap: () async {
              final result = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => DoctorProfileViewScreen(doctorId: id),
                ),
              );
              if (result != null) onChanged();
            },
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> all, String q) {
    if (q.trim().isEmpty) return all;
    final needle = q.trim().toLowerCase();
    return all.where((d) {
      final name = _doctorName(d).toLowerCase();
      final spec = (d['specialization'] ?? '').toString().toLowerCase();
      final hosp = (d['hospital_name'] ?? '').toString().toLowerCase();
      return name.contains(needle) ||
          spec.contains(needle) ||
          hosp.contains(needle);
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// My Doctors tab — only accepted, tap → send-data route
// ---------------------------------------------------------------------------

class _MyDoctorsTab extends StatelessWidget {
  final _DoctorsData data;
  final VoidCallback onChanged;

  const _MyDoctorsTab({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accepted = data.doctors.where((d) {
      final status = data.statusByDoctor[d['id']] ?? 'none';
      return status == 'accepted';
    }).toList();

    if (accepted.isEmpty) {
      return const _EmptyView(
        icon: Icons.handshake_outlined,
        title: 'No connected doctors yet',
        subtitle:
        'Send a request from the Browse tab. Once a doctor accepts, '
            'they\'ll appear here and you can share records with them.',
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6C63FF),
      onRefresh: () async => onChanged(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: accepted.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final d = accepted[i];
          return _ConnectedDoctorCard(
            doctor: d,
            onSendData: () => Navigator.of(context).pushNamed(
              '/patient/upload',
              arguments: d['id'],
            ),
            onView: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    DoctorProfileViewScreen(doctorId: d['id'] as String),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doctor card — used in Browse tab
// ---------------------------------------------------------------------------

class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final String status;
  final VoidCallback onTap;

  const _DoctorCard({
    required this.doctor,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = _doctorName(doctor);
    final spec = doctor['specialization'] as String?;
    final hosp = doctor['hospital_name'] as String?;
    final years = doctor['experience_years'];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4A3FD4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.medical_services,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (spec != null && spec.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        spec,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    if (hosp != null && hosp.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hosp,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (years != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· $years yrs',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: status),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connected doctor card — used in My Doctors tab
// ---------------------------------------------------------------------------

class _ConnectedDoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onSendData;
  final VoidCallback onView;

  const _ConnectedDoctorCard({
    required this.doctor,
    required this.onSendData,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final name = _doctorName(doctor);
    final spec = doctor['specialization'] as String?;
    final hosp = doctor['hospital_name'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA6).withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.verified,
                    color: Color(0xFF00BFA6), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    if (spec != null && spec.isNotEmpty)
                      Text(
                        '${spec}${hosp != null && hosp.isNotEmpty ? " · $hosp" : ""}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                color: Colors.grey[600],
                onPressed: onView,
                tooltip: 'View profile',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onSendData,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send Records'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label, IconData icon) = switch (status) {
      'accepted' => (
      const Color(0xFF00BFA6).withAlpha(30),
      const Color(0xFF00BFA6),
      'Connected',
      Icons.check_circle,
      ),
      'pending' => (
      const Color(0xFFFFB347).withAlpha(40),
      const Color(0xFFE08800),
      'Pending',
      Icons.hourglass_top,
      ),
      'rejected' => (
      const Color(0xFFFF6B6B).withAlpha(30),
      const Color(0xFFD64545),
      'Rejected',
      Icons.block,
      ),
      _ => (
      const Color(0xFF6C63FF).withAlpha(25),
      const Color(0xFF6C63FF),
      'Request',
      Icons.add,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers / shared
// ---------------------------------------------------------------------------

String _doctorName(Map<String, dynamic> d) {
  // Prefer the doctors.name column; fall back to profiles.full_name.
  final name = d['name'] as String?;
  if (name != null && name.trim().isNotEmpty) return name;
  final profile = d['profiles'] as Map<String, dynamic>?;
  final fullName = profile?['full_name'] as String?;
  if (fullName != null && fullName.trim().isNotEmpty) return fullName;
  return 'Doctor';
}

class _DoctorsData {
  final List<Map<String, dynamic>> doctors;
  final Map<String, String> statusByDoctor;
  _DoctorsData({required this.doctors, required this.statusByDoctor});
  factory _DoctorsData.empty() =>
      _DoctorsData(doctors: const [], statusByDoctor: const {});
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Icon(icon, size: 72, color: Colors.grey[400]),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
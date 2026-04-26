import 'package:flutter/material.dart';
import 'package:medichain_beta/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'find_doctors_screen.dart';

/// Cleaner patient dashboard: greeting + health summary + quick actions.
/// The "Available Doctors" list has been moved to its own screen
/// (FindDoctorsScreen) so this view stays focused.
class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  late Future<_DashboardCounts> _counts;

  @override
  void initState() {
    super.initState();
    _counts = _loadCounts();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<_DashboardCounts> _loadCounts() async {
    final user = SupabaseService.currentUser;
    if (user == null) return _DashboardCounts.zero();

    try {
      // Counts of records, accepted doctors. Adjust the table name
      // (medical_records) to whatever you use for uploads.
      final results = await Future.wait([
        Supabase.instance.client
            .from('medical_records')
            .select('id')
            .eq('patient_id', user.id),
        Supabase.instance.client
            .from('doctor_requests')
            .select('id, status')
            .eq('patient_id', user.id),
      ]);
      final records = (results[0] as List).length;
      final requests = (results[1] as List).cast<Map<String, dynamic>>();
      final connected = requests.where((r) => r['status'] == 'accepted').length;
      return _DashboardCounts(
        records: records,
        uploads: records,
        connected: connected,
      );
    } catch (_) {
      return _DashboardCounts.zero();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final name = user?.userMetadata?['full_name'] ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF6C63FF),
          onRefresh: () async {
            setState(() => _counts = _loadCounts());
            await _counts;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                          context, '/patient/profile'),
                      child: const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF6C63FF),
                        child: Icon(Icons.person,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 🔹 HEALTH CARD
                FutureBuilder<_DashboardCounts>(
                  future: _counts,
                  builder: (context, snap) {
                    final c = snap.data ?? _DashboardCounts.zero();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF4A3FD4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(50),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.favorite,
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Health Summary',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildHealthStat('Records', '${c.records}',
                                  Icons.description),
                              _buildHealthStat('Uploads', '${c.uploads}',
                                  Icons.cloud_upload),
                              _buildHealthStat('Doctors', '${c.connected}',
                                  Icons.handshake),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // 🔹 QUICK ACTIONS
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Upload\nDocument',
                        Icons.cloud_upload_outlined,
                        const Color(0xFF6C63FF),
                            () => Navigator.pushNamed(
                            context, '/patient/upload'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'View\nRecords',
                        Icons.folder_open_outlined,
                        const Color(0xFF00BFA6),
                            () => Navigator.pushNamed(
                            context, '/patient/records'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Find\nDoctors',
                        Icons.search_rounded,
                        const Color(0xFFFFB347),
                            () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FindDoctorsScreen(),
                            ),
                          );
                          // Refresh counts when returning
                          setState(() => _counts = _loadCounts());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Share\nRecords',
                        Icons.share_outlined,
                        const Color(0xFFFF6B6B),
                            () => Navigator.of(context).push(
                          MaterialPageRoute(
                            // Lands on the My Doctors tab indirectly —
                            // user picks a connected doctor to share with.
                            builder: (_) => const FindDoctorsScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 🔹 CONNECTED DOCTORS PREVIEW
                _ConnectedDoctorsPreview(
                  onSeeAll: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FindDoctorsScreen(),
                      ),
                    );
                    setState(() => _counts = _loadCounts());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, 0),
    );
  }

  Widget _buildHealthStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withAlpha(180), size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
      ],
    );
  }

  Widget _buildActionCard(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }

  static Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF6C63FF),
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        switch (index) {
          case 0:
            break; // already home
          case 1:
            Navigator.pushNamed(context, '/patient/upload');
            break;
          case 2:
            Navigator.pushNamed(context, '/patient/records');
            break;
          case 3:
            Navigator.pushNamed(context, '/patient/profile');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.upload), label: 'Upload'),
        BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Records'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}

/// Compact horizontal preview of accepted doctors, with "See all" → FindDoctorsScreen.
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

    final rows = await Supabase.instance.client
        .from('doctor_requests')
        .select('doctor_id, doctor:doctors!fk_doctor('
        'id, name, specialization, hospital_name, profiles(full_name))')
        .eq('patient_id', user.id)
        .eq('status', 'accepted')
        .limit(5);

    return (rows as List)
        .map((r) => (r as Map<String, dynamic>))
        .toList();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Doctors',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                TextButton(
                  onPressed: widget.onSeeAll,
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                  children: [
                    Icon(Icons.handshake_outlined,
                        size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No connected doctors yet.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Find Doctors" above to send a request.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else
              ...items.map((row) {
                final doc = (row['doctor'] as Map?) ?? const {};
                final name = (doc['name'] as String?) ??
                    ((doc['profiles'] as Map?)?['full_name'] as String?) ??
                    'Doctor';
                final spec = doc['specialization'] as String?;
                final id = doc['id'] as String?;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA6).withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified,
                          color: Color(0xFF00BFA6)),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    subtitle: spec == null ? null : Text(spec),
                    trailing: ElevatedButton(
                      onPressed: id == null
                          ? null
                          : () => Navigator.pushNamed(
                        context,
                        '/patient/send-data',
                        arguments: id,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Send'),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _DashboardCounts {
  final int records;
  final int uploads;
  final int connected;
  _DashboardCounts({
    required this.records,
    required this.uploads,
    required this.connected,
  });
  factory _DashboardCounts.zero() =>
      _DashboardCounts(records: 0, uploads: 0, connected: 0);
}
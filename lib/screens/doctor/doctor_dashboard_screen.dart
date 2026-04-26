import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'doctor_profile_edit_screen.dart';
import 'patient_records_screen.dart';
import 'patient_request_detail_screen.dart';
// 👇 CHANGE THIS to the actual path of your login screen file.
import 'package:medichain_beta/screens/auth/login_screen.dart';

/// Main shell for a doctor after they sign in. Three tabs:
///   1. Requests   — pending patient connection requests (accept / reject)
///   2. My Patients — accepted patients; tap to view their shared records
///   3. Profile    — view own profile + edit / sign out
class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  int _index = 0;

  // Bumping this counter forces the child tabs to re-fetch when, e.g.,
  // a request is accepted or the profile is edited.
  int _refreshKey = 0;

  void _refreshAll() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _RequestsTab(refreshKey: _refreshKey, onChanged: _refreshAll),
      _PatientsTab(refreshKey: _refreshKey),
      _ProfileTab(refreshKey: _refreshKey, onChanged: _refreshAll),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(_index)),
        centerTitle: false,
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'My Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String _titleFor(int i) => switch (i) {
    0 => 'Patient Requests',
    1 => 'My Patients',
    _ => 'My Profile',
  };
}

// ---------------------------------------------------------------------------
// Tab 1 — Pending requests
// ---------------------------------------------------------------------------

class _RequestsTab extends StatefulWidget {
  final int refreshKey;
  final VoidCallback onChanged;
  const _RequestsTab({required this.refreshKey, required this.onChanged});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  final _supabase = Supabase.instance.client;
  late Future<List<_RequestItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _RequestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      setState(() => _future = _load());
    }
  }

  Future<List<_RequestItem>> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // Find this doctor's row
    final doctor = await _supabase
        .from('doctors')
        .select('id')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (doctor == null) return [];
    final doctorId = doctor['id'] as String;

    // Fetch pending requests + the requesting patient's profile.
    // NOTE: change `full_name` here if your profiles column is named differently.
    final rows = await _supabase
        .from('doctor_requests')
        .select('id, status, created_at, patient_id, '
        'patient:profiles!fk_patient(id, full_name, email)')
        .eq('doctor_id', doctorId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => _RequestItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> _updateStatus(String requestId, String status) async {
    try {
      await _supabase
          .from('doctor_requests')
          .update({'status': status}).eq('id', requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'accepted'
              ? 'Request accepted'
              : 'Request rejected'),
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = _load());
        await _future;
      },
      child: FutureBuilder<List<_RequestItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: '${snapshot.error}',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const _EmptyView(
              icon: Icons.inbox_outlined,
              title: 'No pending requests',
              subtitle: 'New patient requests will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = items[i];
              return _RequestCard(
                item: r,
                onTap: () async {
                  final result = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) =>
                          PatientRequestDetailScreen(requestId: r.id),
                    ),
                  );
                  if (result == 'accepted' || result == 'rejected') {
                    widget.onChanged();
                  }
                },
                onAccept: () => _updateStatus(r.id, 'accepted'),
                onReject: () => _updateStatus(r.id, 'rejected'),
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestItem {
  final String id;
  final String patientId;
  final String patientName;
  final String? patientEmail;
  final DateTime? createdAt;

  _RequestItem({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientEmail,
    this.createdAt,
  });

  factory _RequestItem.fromMap(Map<String, dynamic> m) {
    final patient = (m['patient'] as Map?) ?? const {};
    return _RequestItem(
      id: m['id'] as String,
      patientId: m['patient_id'] as String,
      patientName: (patient['full_name'] ?? 'Unknown patient') as String,
      patientEmail: patient['email'] as String?,
      createdAt: m['created_at'] == null
          ? null
          : DateTime.tryParse(m['created_at'] as String),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final _RequestItem item;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.item,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = item.patientName.isEmpty
        ? '?'
        : item.patientName
        .trim()
        .split(RegExp(r'\s+'))
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.patientName,
                            style: theme.textTheme.titleMedium),
                        if (item.patientEmail != null)
                          Text(item.patientEmail!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — Accepted patients
// ---------------------------------------------------------------------------

class _PatientsTab extends StatefulWidget {
  final int refreshKey;
  const _PatientsTab({required this.refreshKey});

  @override
  State<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<_PatientsTab> {
  final _supabase = Supabase.instance.client;
  late Future<List<_PatientItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _PatientsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      setState(() => _future = _load());
    }
  }

  Future<List<_PatientItem>> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final doctor = await _supabase
        .from('doctors')
        .select('id')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (doctor == null) return [];
    final doctorId = doctor['id'] as String;

    final rows = await _supabase
        .from('doctor_requests')
        .select('patient_id, created_at, '
        'patient:profiles!fk_patient(id, full_name, email)')
        .eq('doctor_id', doctorId)
        .eq('status', 'accepted')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => _PatientItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = _load());
        await _future;
      },
      child: FutureBuilder<List<_PatientItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: '${snapshot.error}',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const _EmptyView(
              icon: Icons.people_outline,
              title: 'No connected patients yet',
              subtitle: 'Patients you accept will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = items[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                    child: Text(
                      p.initials,
                      style: TextStyle(
                        color:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Text(p.name),
                  subtitle: p.email == null ? null : Text(p.email!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PatientRecordsScreen(
                        patientId: p.id,
                        patientName: p.name,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PatientItem {
  final String id;
  final String name;
  final String? email;

  _PatientItem({required this.id, required this.name, this.email});

  String get initials => name.isEmpty
      ? '?'
      : name
      .trim()
      .split(RegExp(r'\s+'))
      .map((p) => p[0])
      .take(2)
      .join()
      .toUpperCase();

  factory _PatientItem.fromMap(Map<String, dynamic> m) {
    final patient = (m['patient'] as Map?) ?? const {};
    return _PatientItem(
      id: (patient['id'] ?? m['patient_id']) as String,
      name: (patient['full_name'] ?? 'Unknown patient') as String,
      email: patient['email'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3 — Doctor's own profile
// ---------------------------------------------------------------------------

class _ProfileTab extends StatefulWidget {
  final int refreshKey;
  final VoidCallback onChanged;
  const _ProfileTab({required this.refreshKey, required this.onChanged});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      setState(() => _future = _load());
    }
  }

  Future<Map<String, dynamic>?> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return _supabase
        .from('doctors')
        .select()
        .eq('profile_id', user.id)
        .maybeSingle();
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;

      // Replace the entire navigation stack with the login screen so the
      // user can't "back" their way into the dashboard after signing out.
      // 👇 CHANGE THIS to your app's login screen widget.
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Sign out failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.medical_services,
                    size: 40, color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                (d?['name'] ?? 'Unnamed doctor') as String,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            if (d?['specialization'] != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  d!['specialization'] as String,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _InfoRow(
                icon: Icons.badge_outlined,
                label: 'License',
                value: d?['license_number'] as String?),
            _InfoRow(
                icon: Icons.local_hospital_outlined,
                label: 'Hospital',
                value: d?['hospital_name'] as String?),
            _InfoRow(
              icon: Icons.timeline_outlined,
              label: 'Experience',
              value: d?['experience_years'] == null
                  ? null
                  : '${d!['experience_years']} years',
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                    const DoctorProfileEditScreen(isEditing: true),
                  ),
                );
                if (saved == true) widget.onChanged();
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Edit profile'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Sign out'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                Text(
                  value == null || value!.isEmpty ? 'Not set' : value!,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared empty + error widgets
// ---------------------------------------------------------------------------

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
    final theme = Theme.of(context);
    return ListView(
      // ListView so RefreshIndicator works on empty state
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Center(
          child: Text(title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
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
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
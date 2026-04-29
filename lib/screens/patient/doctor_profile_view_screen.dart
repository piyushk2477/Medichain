import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Patient view of a single doctor's profile.
/// Shows full info + a context-aware action button:
///   • status = none      → "Send Connection Request"
///   • status = pending   → disabled "Request Pending"
///   • status = rejected  → "Send Again" (creates a new pending request)
///   • status = accepted  → "Send Records" → navigates to /patient/send-data
///
/// Pops with a status string ('pending', etc) when something changed,
/// so the caller can refresh.
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

  Future<_DoctorProfile> _load() async {
    final user = _supabase.auth.currentUser;

    final results = await Future.wait<Map<String, dynamic>?>([
      _supabase
          .from('doctors')
          .select('id, name, specialization, hospital_name, '
          'experience_years, license_number, profiles(full_name)')
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

    final doctor = results[0];
    final request = results[1];
    return _DoctorProfile(
      doctor: doctor,
      status: (request?['status'] ?? 'none') as String,
    );
  }

  Future<void> _sendRequest() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _acting = true);
    try {
      // First check if a row already exists (could be 'rejected' that we want to flip)
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
        const SnackBar(
          content: Text('Request sent'),
          backgroundColor: Color(0xFF00BFA6),
        ),
      );
      setState(() {
        _future = _load();
        _acting = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
      setState(() => _acting = false);
    }
  }

  void _sendData() {
    Navigator.of(context)
        .pushNamed('/patient/upload', arguments: widget.doctorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: FutureBuilder<_DoctorProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            );
          }
          if (snapshot.hasError ||
              snapshot.data == null ||
              snapshot.data!.doctor == null) {
            return Scaffold(
              backgroundColor: const Color(0xFFF5F5FA),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.hasError
                        ? '${snapshot.error}'
                        : 'Doctor not found.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          return _Body(
            profile: snapshot.data!,
            acting: _acting,
            onRequest: _sendRequest,
            onSendData: _sendData,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final _DoctorProfile profile;
  final bool acting;
  final VoidCallback onRequest;
  final VoidCallback onSendData;

  const _Body({
    required this.profile,
    required this.acting,
    required this.onRequest,
    required this.onSendData,
  });

  @override
  Widget build(BuildContext context) {
    final d = profile.doctor!;
    final status = profile.status;
    final name = _nameOf(d);
    final spec = d['specialization'] as String?;
    final hosp = d['hospital_name'] as String?;
    final license = d['license_number'] as String?;
    final years = d['experience_years'];

    return Stack(
      children: [
        // Purple gradient header
        Container(
          height: 240,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4A3FD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.white,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF4A3FD4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(44),
                  ),
                  child: const Icon(Icons.medical_services,
                      color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (spec != null && spec.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    spec,
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontSize: 14,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    children: [
                      // Stat row
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Icons.workspace_premium,
                              label: 'Experience',
                              value: years == null ? '—' : '$years yrs',
                              color: const Color(0xFF6C63FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.verified_user,
                              label: 'License',
                              value: (license == null || license.isEmpty)
                                  ? '—'
                                  : 'Verified',
                              color: const Color(0xFF00BFA6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'About',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(children: [
                        _InfoRow(
                          icon: Icons.local_hospital_outlined,
                          label: 'Hospital / Clinic',
                          value: hosp,
                        ),
                        _InfoRow(
                          icon: Icons.healing_outlined,
                          label: 'Specialization',
                          value: spec,
                        ),
                        _InfoRow(
                          icon: Icons.badge_outlined,
                          label: 'License number',
                          value: license,
                          isLast: true,
                        ),
                      ]),
                      const SizedBox(height: 20),
                      if (status == 'pending')
                        _InfoBanner(
                          color: const Color(0xFFFFB347),
                          icon: Icons.hourglass_top,
                          text:
                          'Your request is awaiting the doctor\'s approval. '
                              'You\'ll be able to share records once accepted.',
                        )
                      else if (status == 'rejected')
                        _InfoBanner(
                          color: const Color(0xFFFF6B6B),
                          icon: Icons.info_outline,
                          text:
                          'This doctor declined your previous request. '
                              'You can send a new one if you\'d like.',
                        )
                      else if (status == 'accepted')
                          _InfoBanner(
                            color: const Color(0xFF00BFA6),
                            icon: Icons.verified,
                            text:
                            'You\'re connected with this doctor. Tap below to share records.',
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Sticky action button
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _ActionButton(
                status: status,
                acting: acting,
                onRequest: onRequest,
                onSendData: onSendData,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _nameOf(Map<String, dynamic> d) {
    final name = d['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final profile = d['profiles'] as Map<String, dynamic>?;
    return (profile?['full_name'] as String?) ?? 'Doctor';
  }
}

class _ActionButton extends StatelessWidget {
  final String status;
  final bool acting;
  final VoidCallback onRequest;
  final VoidCallback onSendData;

  const _ActionButton({
    required this.status,
    required this.acting,
    required this.onRequest,
    required this.onSendData,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'accepted') {
      return _bigButton(
        label: 'Send Records',
        icon: Icons.send_rounded,
        color: const Color(0xFF6C63FF),
        onPressed: onSendData,
      );
    }
    if (status == 'pending') {
      return _bigButton(
        label: 'Request Pending',
        icon: Icons.hourglass_top,
        color: Colors.grey.shade400,
        onPressed: null,
      );
    }
    final label = status == 'rejected'
        ? 'Send Request Again'
        : 'Send Connection Request';
    return _bigButton(
      label: acting ? 'Sending…' : label,
      icon: Icons.send_outlined,
      color: const Color(0xFF6C63FF),
      onPressed: acting ? null : onRequest,
      loading: acting,
    );
  }

  Widget _bigButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        )
            : Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(children: children),
    );
  }
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF6C63FF), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (value == null || value!.isEmpty) ? 'Not provided' : value!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: (value == null || value!.isEmpty)
                            ? Colors.grey[500]
                            : const Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLast) ...[
            const SizedBox(height: 4),
            Divider(color: Colors.grey[200], height: 1),
          ],
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _InfoBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF1A1A2E).withAlpha(220),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorProfile {
  final Map<String, dynamic>? doctor;
  final String status;
  _DoctorProfile({required this.doctor, required this.status});
}

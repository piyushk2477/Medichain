import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medichain_beta/theme/app_theme.dart';

/// Opens when the doctor taps a pending request card.
/// Shows the patient's full profile, then lets the doctor accept or reject.
/// On action, pops with `'accepted'` or `'rejected'` so the caller can refresh.
class PatientRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const PatientRequestDetailScreen({super.key, required this.requestId});

  @override
  State<PatientRequestDetailScreen> createState() =>
      _PatientRequestDetailScreenState();
}

class _PatientRequestDetailScreenState
    extends State<PatientRequestDetailScreen> {
  final _supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>?> _future;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    return _supabase
        .from('doctor_requests')
        .select('id, status, created_at, patient_id, '
        'patient:profiles!patient_id(*)')
        .eq('id', widget.requestId)
        .maybeSingle();
  }

  Future<void> _act(String status) async {
    setState(() => _acting = true);
    try {
      await _supabase
          .from('doctor_requests')
          .update({'status': status}).eq('id', widget.requestId);
      if (!mounted) return;
      Navigator.of(context).pop(status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: $e'), backgroundColor: AppColors.accentRed),
      );
      setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _ErrorState(
              message: snapshot.hasError ? '${snapshot.error}' : 'Request not found.',
            );
          }
          return _Body(
            data: snapshot.data!,
            acting: _acting,
            onAccept: () => _act('accepted'),
            onReject: () => _act('rejected'),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool acting;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _Body({
    required this.data,
    required this.acting,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final patient = (data['patient'] as Map?) ?? const {};
    final name = (patient['full_name'] ?? 'Unknown patient') as String;
    final email = patient['email'] as String?;
    final phone = patient['phone'] as String?;
    final dob = patient['date_of_birth'] as String?;
    final gender = patient['gender'] as String?;
    final bloodGroup = patient['blood_group'] as String?;
    final address = patient['address'] as String?;

    final status = (data['status'] ?? 'pending') as String;
    final createdAt = data['created_at'] == null
        ? null
        : DateTime.tryParse(data['created_at'] as String);

    final initials = _initialsFor(name);

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              // ── Branded header with avatar ────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), AppColors.primary, Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -50,
                        top: 10,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
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
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  'Patient Request',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                const SizedBox(width: 40),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.28), width: 2),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            _StatusChip(status: status),
                            if (createdAt != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Requested ${_friendlyDate(createdAt)}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _Section(title: 'Contact', children: [
                        _InfoTile(icon: Icons.mail_outline_rounded, label: 'Email', value: email),
                        _InfoTile(icon: Icons.phone_outlined, label: 'Phone', value: phone),
                        _InfoTile(icon: Icons.home_outlined, label: 'Address', value: address),
                      ]),
                      const SizedBox(height: 14),
                      _Section(title: 'Personal', children: [
                        _InfoTile(icon: Icons.cake_outlined, label: 'Date of birth', value: dob),
                        _InfoTile(icon: Icons.wc_outlined, label: 'Gender', value: gender),
                        _InfoTile(icon: Icons.bloodtype_outlined, label: 'Blood group', value: bloodGroup),
                      ]),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (status == 'pending')
          Container(
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: acting ? null : onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentRed,
                          side: BorderSide(color: AppColors.accentRed.withOpacity(0.5)),
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: acting ? null : onAccept,
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        icon: acting
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color dot, String label) = switch (status) {
      'accepted' => (Color(0xFF4ADE80), 'Accepted'),
      'rejected' => (AppColors.accentRed, 'Rejected'),
      _ => (Color(0xFFFBBF24), 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value == null || value!.isEmpty ? 'Not provided' : value!,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: value == null || value!.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
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

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            const Spacer(),
            const Icon(Icons.error_outline, size: 56, color: AppColors.accentRed),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

String _initialsFor(String name) {
  if (name.trim().isEmpty) return '?';
  return name
      .trim()
      .split(RegExp(r'\s+'))
      .map((p) => p.isEmpty ? '' : p[0])
      .take(2)
      .join()
      .toUpperCase();
}

String _friendlyDate(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inDays == 0) return 'today';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${d.day}/${d.month}/${d.year}';
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    // Pull the request + the patient's profile in one call.
    // Adjust selected profile columns to match your `profiles` table.
    return _supabase
        .from('doctor_requests')
        .select('id, status, created_at, patient_id, '
        'patient:profiles!fk_patient(*)')
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not update: $e')));
      setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient request')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.hasError
                      ? '${snapshot.error}'
                      : 'Request not found.',
                  textAlign: TextAlign.center,
                ),
              ),
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
    final theme = Theme.of(context);
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

    final initials = name.isEmpty
        ? '?'
        : name
        .trim()
        .split(RegExp(r'\s+'))
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    initials,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child:
                Text(name, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: 4),
              Center(
                child: _StatusChip(status: status),
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Requested ${_friendlyDate(createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _Section(title: 'Contact', children: [
                _InfoTile(icon: Icons.email_outlined, label: 'Email', value: email),
                _InfoTile(icon: Icons.phone_outlined, label: 'Phone', value: phone),
                _InfoTile(
                    icon: Icons.home_outlined, label: 'Address', value: address),
              ]),
              const SizedBox(height: 16),
              _Section(title: 'Personal', children: [
                _InfoTile(
                    icon: Icons.cake_outlined,
                    label: 'Date of birth',
                    value: dob),
                _InfoTile(
                    icon: Icons.wc_outlined, label: 'Gender', value: gender),
                _InfoTile(
                    icon: Icons.bloodtype_outlined,
                    label: 'Blood group',
                    value: bloodGroup),
              ]),
            ],
          ),
        ),
        if (status == 'pending')
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: acting ? null : onReject,
                      icon: const Icon(Icons.close),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text('Reject'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: acting ? null : onAccept,
                      icon: acting
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.check),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text('Accept'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _friendlyDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg, String label) = switch (status) {
      'accepted' => (
      theme.colorScheme.tertiaryContainer,
      theme.colorScheme.onTertiaryContainer,
      'Accepted'
      ),
      'rejected' => (
      theme.colorScheme.errorContainer,
      theme.colorScheme.onErrorContainer,
      'Rejected'
      ),
      _ => (
      theme.colorScheme.secondaryContainer,
      theme.colorScheme.onSecondaryContainer,
      'Pending'
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: theme.textTheme.labelMedium?.copyWith(color: fg)),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title,
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600)),
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
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      subtitle: Text(
        value == null || value!.isEmpty ? 'Not provided' : value!,
        style: theme.textTheme.bodyLarge,
      ),
    );
  }
}
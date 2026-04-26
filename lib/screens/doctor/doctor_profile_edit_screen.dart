import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'doctor_dashboard_screen.dart';

/// Shown right after a doctor signs up (and any time they want to edit later).
/// Reads/writes the `doctors` table keyed by the auth user's profile_id.
class DoctorProfileEditScreen extends StatefulWidget {
  /// If true, a successful save pops back instead of navigating to the dashboard.
  /// Pass true when opening this screen from the "Edit Profile" button on the dashboard.
  final bool isEditing;

  const DoctorProfileEditScreen({super.key, this.isEditing = false});

  @override
  State<DoctorProfileEditScreen> createState() =>
      _DoctorProfileEditScreenState();
}

class _DoctorProfileEditScreenState extends State<DoctorProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _nameCtrl = TextEditingController();
  final _specializationCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _existingDoctorId; // null if no row yet (fresh signup)

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specializationCtrl.dispose();
    _licenseCtrl.dispose();
    _hospitalCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // profile_id == auth.uid() in your schema (profiles.id is the auth user id)
      final row = await _supabase
          .from('doctors')
          .select()
          .eq('profile_id', user.id)
          .maybeSingle();

      if (row != null) {
        _existingDoctorId = row['id'] as String?;
        _nameCtrl.text = (row['name'] ?? '') as String;
        _specializationCtrl.text = (row['specialization'] ?? '') as String;
        _licenseCtrl.text = (row['license_number'] ?? '') as String;
        _hospitalCtrl.text = (row['hospital_name'] ?? '') as String;
        final years = row['experience_years'];
        _experienceCtrl.text = years == null ? '' : years.toString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not signed in.')),
      );
      return;
    }

    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'profile_id': user.id,
      'name': _nameCtrl.text.trim(),
      'specialization': _specializationCtrl.text.trim().isEmpty
          ? null
          : _specializationCtrl.text.trim(),
      'license_number': _licenseCtrl.text.trim().isEmpty
          ? null
          : _licenseCtrl.text.trim(),
      'hospital_name': _hospitalCtrl.text.trim().isEmpty
          ? null
          : _hospitalCtrl.text.trim(),
      'experience_years': _experienceCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_experienceCtrl.text.trim()),
    };

    try {
      // Upsert on the unique profile_id constraint — handles both insert (signup)
      // and update (edit) cases.
      await _supabase.from('doctors').upsert(
        payload,
        onConflict: 'profile_id',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );

      if (widget.isEditing) {
        Navigator.of(context).pop(true);
      } else {
        // Fresh signup → land on the dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const DoctorDashboardScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingDoctorId == null
            ? 'Complete your profile'
            : 'Edit profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.medical_services_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Patients will see this information when '
                              'deciding whether to share records with you.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _Field(
                  controller: _nameCtrl,
                  label: 'Full name',
                  hint: 'Dr. Jane Doe',
                  icon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _Field(
                  controller: _specializationCtrl,
                  label: 'Specialization',
                  hint: 'Cardiology, General Physician, etc.',
                  icon: Icons.healing_outlined,
                ),
                const SizedBox(height: 16),
                _Field(
                  controller: _licenseCtrl,
                  label: 'License number',
                  hint: 'Medical Council registration ID',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 16),
                _Field(
                  controller: _hospitalCtrl,
                  label: 'Hospital / Clinic',
                  hint: 'Where you currently practice',
                  icon: Icons.local_hospital_outlined,
                ),
                const SizedBox(height: 16),
                _Field(
                  controller: _experienceCtrl,
                  label: 'Years of experience',
                  hint: 'e.g. 8',
                  icon: Icons.timeline_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.check),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_existingDoctorId == null
                        ? 'Continue to dashboard'
                        : 'Save changes'),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
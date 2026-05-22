import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medichain_beta/theme/app_theme.dart';
import 'doctor_dashboard_screen.dart';

class DoctorProfileEditScreen extends StatefulWidget {
  final bool isEditing;
  const DoctorProfileEditScreen({super.key, this.isEditing = false});

  @override
  State<DoctorProfileEditScreen> createState() =>
      _DoctorProfileEditScreenState();
}

class _DoctorProfileEditScreenState extends State<DoctorProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _nameCtrl       = TextEditingController();
  final _licenseCtrl    = TextEditingController();
  final _hospitalCtrl   = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _feeCtrl        = TextEditingController();
  final _addressCtrl    = TextEditingController();
  final _aboutCtrl      = TextEditingController();
  final _educationCtrl  = TextEditingController();

  String? _selectedSpec;
  String? _selectedState;
  String? _selectedCity;
  final Set<String> _selectedLanguages = {};
  bool _availableOnline = false;

  bool _loading = true;
  bool _saving  = false;
  String? _existingDoctorId;

  static const _specializations = [
    'General Physician', 'Cardiology', 'Dermatology', 'Pediatrics',
    'Orthopedics', 'Neurology', 'Dentistry', 'Gynecology & Obstetrics',
    'Psychiatry', 'Ophthalmology', 'ENT (Ear, Nose, Throat)',
    'Urology', 'Oncology', 'Endocrinology', 'Gastroenterology',
    'Pulmonology', 'Rheumatology', 'Nephrology', 'Radiology',
    'Physiotherapy', 'Homeopathy', 'Ayurveda', 'Other',
  ];

  static const Map<String, List<String>> _stateCities = {
    'Andhra Pradesh':  ['Visakhapatnam','Vijayawada','Guntur','Tirupati','Kurnool'],
    'Bihar':           ['Patna','Gaya','Muzaffarpur','Bhagalpur','Darbhanga'],
    'Delhi':           ['New Delhi','Dwarka','Rohini','Pitampura','Janakpuri'],
    'Goa':             ['Panaji','Margao','Vasco da Gama','Mapusa'],
    'Gujarat':         ['Ahmedabad','Surat','Vadodara','Rajkot','Bhavnagar','Jamnagar'],
    'Haryana':         ['Gurugram','Faridabad','Hisar','Rohtak','Panipat'],
    'Karnataka':       ['Bangalore','Mysore','Hubli-Dharwad','Mangalore','Belgaum'],
    'Kerala':          ['Thiruvananthapuram','Kochi','Kozhikode','Thrissur','Kannur'],
    'Madhya Pradesh':  ['Bhopal','Indore','Jabalpur','Gwalior','Ujjain'],
    'Maharashtra':     ['Mumbai','Pune','Nagpur','Nashik','Aurangabad','Solapur','Kolhapur'],
    'Odisha':          ['Bhubaneswar','Cuttack','Rourkela','Berhampur'],
    'Punjab':          ['Chandigarh','Ludhiana','Amritsar','Jalandhar','Patiala'],
    'Rajasthan':       ['Jaipur','Jodhpur','Udaipur','Kota','Ajmer','Bikaner'],
    'Tamil Nadu':      ['Chennai','Coimbatore','Madurai','Salem','Tiruchirappalli'],
    'Telangana':       ['Hyderabad','Warangal','Nizamabad','Karimnagar','Khammam'],
    'Uttar Pradesh':   ['Lucknow','Kanpur','Agra','Varanasi','Allahabad','Meerut','Noida'],
    'Uttarakhand':     ['Dehradun','Haridwar','Roorkee','Rishikesh'],
    'West Bengal':     ['Kolkata','Howrah','Durgapur','Asansol','Siliguri'],
    'Other':           ['Other'],
  };

  static const _languages = [
    'English','Hindi','Marathi','Tamil','Telugu','Kannada',
    'Bengali','Gujarati','Malayalam','Punjabi','Urdu','Odia','Assamese',
  ];

  List<String> get _citiesForState =>
      _selectedState == null ? [] : (_stateCities[_selectedState] ?? []);

  /// Resolves the current user from every available source.
  /// Since supabase_service.signUp now guarantees a session before navigation,
  /// this will virtually always return non-null immediately.
  User? get _currentUser =>
      _supabase.auth.currentUser ?? _supabase.auth.currentSession?.user;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _licenseCtrl.dispose();
    _hospitalCtrl.dispose();
    _experienceCtrl.dispose();
    _feeCtrl.dispose();
    _addressCtrl.dispose();
    _aboutCtrl.dispose();
    _educationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    final user = _currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final row = await _supabase
          .from('doctors')
          .select()
          .eq('profile_id', user.id)
          .maybeSingle();

      if (row != null && mounted) {
        setState(() {
          _existingDoctorId = row['id'] as String?;
          _nameCtrl.text      = (row['name']          ?? '') as String;
          _licenseCtrl.text   = (row['license_number'] ?? '') as String;
          _hospitalCtrl.text  = (row['hospital_name']  ?? '') as String;
          _addressCtrl.text   = (row['address']         ?? '') as String;
          _aboutCtrl.text     = (row['about']           ?? '') as String;
          _educationCtrl.text = (row['education']       ?? '') as String;
          final years = row['experience_years'];
          _experienceCtrl.text = years == null ? '' : years.toString();
          final fee = row['consultation_fee'];
          _feeCtrl.text = fee == null ? '' : fee.toString();
          _availableOnline = (row['available_online'] ?? false) as bool;
          _selectedSpec  = _matchSpec(row['specialization'] as String?);
          _selectedState = row['state'] as String?;
          _selectedCity  = row['city']  as String?;
          final langs = row['languages'];
          if (langs is List) _selectedLanguages.addAll(langs.whereType<String>());
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile: $e'),
              backgroundColor: AppColors.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _matchSpec(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in _specializations) {
      if (s.toLowerCase() == raw.toLowerCase()) return s;
    }
    return 'Other';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not signed in. Please sign in again.'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    setState(() => _saving = true);

    try {
      // ── Step A: upsert profiles FIRST (satisfies the FK constraint) ─────
      // profiles.email is NOT NULL — this was the silent failure before.
      await _supabase.from('profiles').upsert(
        {
          'id':        user.id,
          'email':     user.email ?? '',   // ← NOT NULL in your schema
          'full_name': _nameCtrl.text.trim(),
          'role':      'doctor',
        },
        onConflict: 'id',
      );

      // ── Step B: now safe to upsert doctors ───────────────────────────────
      final payload = <String, dynamic>{
        'profile_id':       user.id,
        'name':             _nameCtrl.text.trim(),
        'specialization':   _selectedSpec,
        'license_number':   _t(_licenseCtrl),
        'hospital_name':    _t(_hospitalCtrl),
        'experience_years': _int(_experienceCtrl),
        'state':            _selectedState,
        'city':             _selectedCity,
        'address':          _t(_addressCtrl),
        'about':            _t(_aboutCtrl),
        'education':        _t(_educationCtrl),
        'consultation_fee': _int(_feeCtrl),
        'available_online': _availableOnline,
        'languages': _selectedLanguages.isEmpty
            ? null
            : _selectedLanguages.toList(),
      };

      await _supabase.from('doctors').upsert(
          payload, onConflict: 'profile_id');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile saved ✓'),
            backgroundColor: AppColors.success),
      );

      if (widget.isEditing) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: $e'),
              backgroundColor: AppColors.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _t(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();
  int?    _int(TextEditingController c) => int.tryParse(c.text.trim());

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Setting up your profile…',
                  style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final isNew = _existingDoctorId == null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _EditHeader(
                    isNew: isNew,
                    showBack: widget.isEditing,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionLabel('IDENTITY'),
                          const SizedBox(height: 10),
                          _Card(children: [
                            _Field(controller: _nameCtrl,
                                label: 'Full name',
                                hint: 'Dr. Jane Doe',
                                icon: Icons.person_outline_rounded,
                                validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Name is required'
                                    : null),
                            const _FieldDivider(),
                            _SpecPicker(
                                value: _selectedSpec,
                                options: _specializations,
                                onChanged: (v) =>
                                    setState(() => _selectedSpec = v)),
                            const _FieldDivider(),
                            _Field(controller: _licenseCtrl,
                                label: 'License number',
                                hint: 'Medical Council registration ID',
                                icon: Icons.badge_outlined),
                            const _FieldDivider(),
                            _Field(controller: _educationCtrl,
                                label: 'Education',
                                hint: 'e.g. MBBS, MD, DNB – AIIMS',
                                icon: Icons.school_outlined),
                          ]),

                          const SizedBox(height: 14),
                          _SectionLabel('PRACTICE'),
                          const SizedBox(height: 10),
                          _Card(children: [
                            _Field(controller: _hospitalCtrl,
                                label: 'Hospital / Clinic',
                                hint: 'Where you currently practice',
                                icon: Icons.local_hospital_outlined),
                            const _FieldDivider(),
                            Row(children: [
                              Expanded(child: _Field(
                                  controller: _experienceCtrl,
                                  label: 'Experience (yrs)',
                                  hint: 'e.g. 8',
                                  icon: Icons.timeline_outlined,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return null;
                                    if (int.tryParse(v.trim()) == null) return 'Invalid';
                                    return null;
                                  })),
                              const SizedBox(width: 12),
                              Expanded(child: _Field(
                                  controller: _feeCtrl,
                                  label: 'Fee (₹)',
                                  hint: 'e.g. 500',
                                  icon: Icons.currency_rupee_rounded,
                                  keyboardType: TextInputType.number)),
                            ]),
                            const _FieldDivider(),
                            _OnlineToggle(
                                value: _availableOnline,
                                onChanged: (v) =>
                                    setState(() => _availableOnline = v)),
                          ]),

                          const SizedBox(height: 14),
                          _SectionLabel('LOCATION'),
                          const SizedBox(height: 10),
                          _Card(children: [
                            _OptionPicker<String>(
                                label: 'State',
                                hint: 'Select state',
                                value: _selectedState,
                                icon: Icons.map_outlined,
                                options: _stateCities.keys.toList(),
                                onChanged: (v) => setState(() {
                                  _selectedState = v;
                                  _selectedCity  = null;
                                })),
                            const _FieldDivider(),
                            _OptionPicker<String>(
                                label: 'City',
                                hint: _selectedState == null
                                    ? 'Select a state first'
                                    : 'Select city',
                                value: _selectedCity,
                                icon: Icons.location_city_outlined,
                                options: _citiesForState,
                                enabled: _selectedState != null,
                                onChanged: (v) =>
                                    setState(() => _selectedCity = v)),
                            const _FieldDivider(),
                            _Field(controller: _addressCtrl,
                                label: 'Clinic address',
                                hint: 'Building, street, area',
                                icon: Icons.location_on_outlined),
                          ]),

                          const SizedBox(height: 14),
                          _SectionLabel('ABOUT'),
                          const SizedBox(height: 10),
                          _Card(children: [
                            _Field(controller: _aboutCtrl,
                                label: 'Bio',
                                hint: 'Briefly describe your expertise',
                                icon: Icons.info_outline_rounded,
                                maxLines: 4),
                          ]),

                          const SizedBox(height: 14),
                          _SectionLabel('LANGUAGES SPOKEN'),
                          const SizedBox(height: 10),
                          _LanguageSelector(
                              selected: _selectedLanguages,
                              options: _languages,
                              onToggle: (lang) => setState(() {
                                if (_selectedLanguages.contains(lang)) {
                                  _selectedLanguages.remove(lang);
                                } else {
                                  _selectedLanguages.add(lang);
                                }
                              })),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sticky save bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                  color: AppColors.primary.withOpacity(0.07),
                  blurRadius: 18, offset: const Offset(0, -6))],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54)),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    isNew ? 'Continue to dashboard' : 'Save changes',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────

class _EditHeader extends StatelessWidget {
  final bool isNew;
  final bool showBack;
  final VoidCallback? onBack;
  const _EditHeader({required this.isNew, required this.showBack, this.onBack});

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
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -50, top: 10,
              child: Container(width: 180, height: 180,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBack)
                  InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2))),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    ),
                  ),
                SizedBox(height: showBack ? 14 : 0),
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.22))),
                    alignment: Alignment.center,
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isNew ? 'Complete your profile' : 'Edit profile',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white, fontSize: 22,
                              fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                      const SizedBox(height: 4),
                      Text(
                        isNew
                            ? 'Patients will see this when deciding to connect'
                            : 'Keep your profile up to date for patients',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 13, height: 1.35),
                      ),
                    ],
                  )),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form helpers (all identical to before) ────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800,
          color: AppColors.textTertiary, letterSpacing: 1.4));
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, thickness: 1, color: AppColors.border));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  const _Field({required this.controller, required this.label,
    required this.icon, this.hint, this.keyboardType,
    this.validator, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11.5,
          fontWeight: FontWeight.w700, color: AppColors.textTertiary,
          letterSpacing: 0.3)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        style: GoogleFonts.plusJakartaSans(fontSize: 14.5, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary, fontSize: 14),
          prefixIcon: Padding(padding: const EdgeInsets.only(right: 8),
              child: Icon(icon, color: AppColors.textTertiary, size: 18)),
          prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          isDense: true,
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    ],
  );
}

class _SpecPicker extends StatelessWidget {
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _SpecPicker({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Specialization', style: GoogleFonts.plusJakartaSans(
          fontSize: 11.5, fontWeight: FontWeight.w700,
          color: AppColors.textTertiary, letterSpacing: 0.3)),
      const SizedBox(height: 6),
      InkWell(
        onTap: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _OptionsSheet(title: 'Specialization', options: options,
              selected: value, onSelect: (v) { onChanged(v); Navigator.pop(context); }),
        ),
        child: Row(children: [
          const Icon(Icons.healing_outlined, color: AppColors.textTertiary, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(value ?? 'Select specialization',
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5,
                  color: value == null ? AppColors.textTertiary : AppColors.textPrimary))),
          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textTertiary, size: 18),
        ]),
      ),
    ],
  );
}

class _OptionPicker<T> extends StatelessWidget {
  final String label;
  final String hint;
  final T? value;
  final IconData icon;
  final List<T> options;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  const _OptionPicker({required this.label, required this.hint,
    required this.value, required this.icon, required this.options,
    required this.onChanged, this.enabled = true});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11.5,
          fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.3)),
      const SizedBox(height: 6),
      Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: InkWell(
          onTap: enabled
              ? () => showModalBottomSheet(
            context: context, isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _OptionsSheet(
              title: label,
              options: options.map((e) => e.toString()).toList(),
              selected: value?.toString(),
              onSelect: (v) {
                onChanged(options.firstWhere((e) => e.toString() == v,
                    orElse: () => options.first) as T);
                Navigator.pop(context);
              },
            ),
          )
              : null,
          child: Row(children: [
            Icon(icon, color: AppColors.textTertiary, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(value?.toString() ?? hint,
                style: GoogleFonts.plusJakartaSans(fontSize: 14.5,
                    color: value == null ? AppColors.textTertiary : AppColors.textPrimary))),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textTertiary, size: 18),
          ]),
        ),
      ),
    ],
  );
}

class _OnlineToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _OnlineToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: value ? AppColors.success.withOpacity(0.1) : AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.videocam_outlined,
            color: value ? AppColors.success : AppColors.primary, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Available online', style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text('Patients can request a video consultation', style: GoogleFonts.plusJakartaSans(
            fontSize: 12, color: AppColors.textSecondary)),
      ])),
      Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppColors.success),
    ],
  );
}

class _LanguageSelector extends StatelessWidget {
  final Set<String> selected;
  final List<String> options;
  final ValueChanged<String> onToggle;
  const _LanguageSelector({required this.selected, required this.options, required this.onToggle});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('LANGUAGES SPOKEN', style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: AppColors.textTertiary, letterSpacing: 1.4)),
          const SizedBox(width: 8),
          Text('(select all that apply)', style: GoogleFonts.plusJakartaSans(
              fontSize: 11, color: AppColors.textTertiary)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: options.map((lang) {
          final sel = selected.contains(lang);
          return InkWell(
            onTap: () => onToggle(lang),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.primary : AppColors.border),
              ),
              child: Text(lang, style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textSecondary)),
            ),
          );
        }).toList()),
      ],
    ),
  );
}

class _OptionsSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _OptionsSheet({required this.title, required this.options,
    required this.selected, required this.onSelect});

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((o) => o.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        children: [
          Container(width: 44, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: AppColors.border,
                  borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Expanded(child: Text(widget.title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 18,
                      fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
              IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                filled: true, fillColor: AppColors.surface,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) {
                final opt = filtered[i];
                final sel = opt == widget.selected;
                return InkWell(
                  onTap: () => widget.onSelect(opt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(children: [
                      Expanded(child: Text(opt, style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? AppColors.primary : AppColors.textPrimary))),
                      if (sel) const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 20),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
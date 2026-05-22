import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medichain_beta/services/supabase_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Edit Profile screen — loads from `profiles` + `patients` tables and
/// writes back via update + upsert. Returns `true` on successful save so
/// the caller can refresh.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  String _email = '';
  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  late final AnimationController _entranceCtrl;
  late final AnimationController _avatarPulse;
  late final AnimationController _shakeCtrl;

  static const _genderOptions = <String>[
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  static const _bloodGroupOptions = <String>[
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
    'Unknown',
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _avatarPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _nameCtrl.addListener(_clearErrorOnEdit);
    _addressCtrl.addListener(_clearErrorOnEdit);
    _emergencyCtrl.addListener(_clearErrorOnEdit);

    _load();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _avatarPulse.dispose();
    _shakeCtrl.dispose();
    _nameCtrl.removeListener(_clearErrorOnEdit);
    _addressCtrl.removeListener(_clearErrorOnEdit);
    _emergencyCtrl.removeListener(_clearErrorOnEdit);
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  void _clearErrorOnEdit() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
    parent: _entranceCtrl,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  Future<void> _load() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final results = await Future.wait([
        Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle(),
        Supabase.instance.client
            .from('patients')
            .select()
            .eq('profile_id', user.id)
            .maybeSingle(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final patient = results[1] as Map<String, dynamic>?;

      if (!mounted) return;
      setState(() {
        _nameCtrl.text = (profile?['full_name'] as String?) ?? '';
        _email = (profile?['email'] as String?) ?? user.email ?? '';

        if (patient != null) {
          final dobStr = patient['date_of_birth'] as String?;
          if (dobStr != null && dobStr.isNotEmpty) {
            _dob = DateTime.tryParse(dobStr);
          }
          final g = patient['gender'] as String?;
          if (g != null && _genderOptions.contains(g)) _gender = g;
          final bg = patient['blood_group'] as String?;
          if (bg != null && _bloodGroupOptions.contains(bg)) _bloodGroup = bg;
          _addressCtrl.text = (patient['address'] as String?) ?? '';
          _emergencyCtrl.text =
              (patient['emergency_contact'] as String?) ?? '';
        }
        _loading = false;
      });
      _entranceCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _friendlyError(e);
      });
      _entranceCtrl.forward();
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final user = SupabaseService.currentUser;
      if (user == null) throw Exception('Not signed in');

      final newName = _nameCtrl.text.trim();

      // 1. profiles row
      await Supabase.instance.client
          .from('profiles')
          .update({'full_name': newName}).eq('id', user.id);

      // 2. auth metadata (so the dashboard greeting stays in sync)
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'full_name': newName}),
        );
      } catch (_) {
        // non-fatal — profile already updated above
      }

      // 3. patients row (upsert on unique profile_id)
      String? dobIso;
      if (_dob != null) {
        final y = _dob!.year.toString().padLeft(4, '0');
        final m = _dob!.month.toString().padLeft(2, '0');
        final d = _dob!.day.toString().padLeft(2, '0');
        dobIso = '$y-$m-$d';
      }

      await Supabase.instance.client.from('patients').upsert(
        {
          'profile_id': user.id,
          'date_of_birth': dobIso,
          'gender': _gender,
          'blood_group': _bloodGroup,
          'address':
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          'emergency_contact': _emergencyCtrl.text.trim().isEmpty
              ? null
              : _emergencyCtrl.text.trim(),
        },
        onConflict: 'profile_id',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Profile updated',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _shakeCtrl.forward(from: 0);
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection') ||
        msg.contains('timeout')) {
      return "Couldn't reach our servers. Check your internet and try again.";
    }
    if (msg.contains('not signed in')) {
      return 'You need to sign in again to save changes.';
    }
    if (msg.contains('foreign key') ||
        msg.contains('violates') ||
        msg.contains('constraint')) {
      return 'Some details look off. Please double-check your entries.';
    }
    return "We couldn't save your profile. Please try again.";
  }

  String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _FadeSlideIn(
                  animation: _stage(0.0, 0.4),
                  child: _Header(
                    name: _nameCtrl.text,
                    email: _email,
                    avatarPulse: _avatarPulse,
                    initial: _initial(_nameCtrl.text),
                    onBack: () => Navigator.pop(context),
                  ),
                ),
              ),

              // Error banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SizeTransition(
                          sizeFactor: anim,
                          axisAlignment: -1,
                          child: child,
                        ),
                      ),
                      child: _errorMessage == null
                          ? const SizedBox(
                        key: ValueKey('no-error'),
                        width: double.infinity,
                      )
                          : Padding(
                        key: const ValueKey('error'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ErrorBanner(
                          message: _errorMessage!,
                          onDismiss: () => setState(
                                  () => _errorMessage = null),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Personal section
              SliverToBoxAdapter(
                child: _FadeSlideIn(
                  animation: _stage(0.15, 0.55),
                  child: const _SectionLabel('PERSONAL'),
                ),
              ),
              SliverToBoxAdapter(
                child: _FadeSlideIn(
                  animation: _stage(0.20, 0.60),
                  child: _ShakeWrap(
                    ctrl: _shakeCtrl,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: _Card(
                        children: [
                          _LabeledField(
                            label: 'Full name',
                            icon: Icons.person_outline_rounded,
                            controller: _nameCtrl,
                            hint: 'Your name as on records',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              if (v.trim().length < 2) {
                                return 'Name is too short';
                              }
                              return null;
                            },
                          ),
                          const _CardDivider(),
                          _ReadOnlyField(
                            label: 'Email',
                            icon: Icons.mail_outline_rounded,
                            value: _email.isEmpty ? '—' : _email,
                            hint: 'Linked to your account',
                          ),
                          const _CardDivider(),
                          _DateField(
                            label: 'Date of birth',
                            value: _dob,
                            onTap: _pickDate,
                          ),
                          const _CardDivider(),
                          _DropdownField<String>(
                            label: 'Gender',
                            icon: Icons.wc_outlined,
                            value: _gender,
                            hint: 'Select',
                            items: _genderOptions,
                            onChanged: (v) =>
                                setState(() => _gender = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Health section
              SliverToBoxAdapter(
                child: _FadeSlideIn(
                  animation: _stage(0.32, 0.72),
                  child: const _SectionLabel('HEALTH'),
                ),
              ),
              SliverToBoxAdapter(
                child: _FadeSlideIn(
                  animation: _stage(0.36, 0.76),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: _Card(
                      children: [
                        _DropdownField<String>(
                          label: 'Blood group',
                          icon: Icons.bloodtype_outlined,
                          value: _bloodGroup,
                          hint: 'Select',
                          items: _bloodGroupOptions,
                          onChanged: (v) =>
                              setState(() => _bloodGroup = v),
                          accent: const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Contact section
              SliverToBoxAdapter(
                child: _FadeSlideIn(
                  animation: _stage(0.46, 0.84),
                  child: const _SectionLabel('CONTACT'),
                ),
              ),
              SliverToBoxAdapter(
                child: _FadeSlideIn(
                  animation: _stage(0.50, 0.88),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: _Card(
                      children: [
                        _LabeledField(
                          label: 'Address',
                          icon: Icons.location_on_outlined,
                          controller: _addressCtrl,
                          hint: 'Where you live (optional)',
                          maxLines: 3,
                        ),
                        const _CardDivider(),
                        _LabeledField(
                          label: 'Emergency contact',
                          icon: Icons.contact_emergency_outlined,
                          controller: _emergencyCtrl,
                          hint: 'Name and phone',
                          keyboardType: TextInputType.text,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _FadeSlideIn(
                  animation: _stage(0.62, 1.0),
                  child: Padding(
                    padding:
                    const EdgeInsets.fromLTRB(20, 6, 20, 28),
                    child: _SaveButton(
                      saving: _saving,
                      onTap: _save,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final String name;
  final String email;
  final String initial;
  final AnimationController avatarPulse;
  final VoidCallback onBack;

  const _Header({
    required this.name,
    required this.email,
    required this.initial,
    required this.avatarPulse,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), AppColors.primary, Color(0xFF1E40AF)],
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
            right: -30,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onBack,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.22)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Edit Profile',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 22),
              // Avatar with pulse ring
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: avatarPulse,
                      builder: (context, _) {
                        final t = avatarPulse.value;
                        final size = 80 + 30 * t;
                        final opacity = (1.0 - t) * 0.32;
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(opacity),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                          width: 2.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name.isEmpty ? 'Your details' : name,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Keep your info up to date',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section label
// ═══════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textTertiary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Card container
// ═══════════════════════════════════════════════════════════════════════════
class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Divider(height: 1, thickness: 1, color: AppColors.border),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Labeled text field
// ═══════════════════════════════════════════════════════════════════════════
class _LabeledField extends StatefulWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType keyboardType;
  final FormFieldValidator<String>? validator;

  const _LabeledField({
    required this.label,
    required this.icon,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  bool _focused = false;
  final _node = FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(() {
      setState(() => _focused = _node.hasFocus);
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _focused
                  ? AppColors.primary.withOpacity(0.14)
                  : AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon,
                color: AppColors.primary,
                size: _focused ? 20 : 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                TextFormField(
                  controller: widget.controller,
                  focusNode: _node,
                  maxLines: widget.maxLines,
                  keyboardType: widget.keyboardType,
                  validator: widget.validator,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                    errorStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.accentRed,
                      fontWeight: FontWeight.w600,
                    ),
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
// Read-only field (for email)
// ═══════════════════════════════════════════════════════════════════════════
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String? hint;

  const _ReadOnlyField({
    required this.label,
    required this.icon,
    required this.value,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child:
            Icon(icon, color: AppColors.textTertiary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded,
              size: 16, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Date field
// ═══════════════════════════════════════════════════════════════════════════
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  String _format(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.cake_outlined,
                    color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value == null ? 'Select date' : _format(value!),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: value == null
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Dropdown field
// ═══════════════════════════════════════════════════════════════════════════
class _DropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final String hint;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final Color? accent;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: tint, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    isExpanded: true,
                    isDense: true,
                    hint: Text(
                      hint,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    items: items
                        .map((e) => DropdownMenuItem<T>(
                      value: e,
                      child: Text(e.toString()),
                    ))
                        .toList(),
                    onChanged: onChanged,
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
// Save button — morphing pill
// ═══════════════════════════════════════════════════════════════════════════
class _SaveButton extends StatefulWidget {
  final bool saving;
  final VoidCallback onTap;
  const _SaveButton({required this.saving, required this.onTap});

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final fullWidth = c.maxWidth;
        return Align(
          alignment: Alignment.center,
          child: GestureDetector(
            onTapDown: widget.saving
                ? null
                : (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.saving
                ? null
                : () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: widget.saving ? 56 : fullWidth,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), AppColors.primary, Color(0xFF1E40AF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                  BorderRadius.circular(widget.saving ? 32 : 16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: widget.saving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor:
                    AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Save Changes',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Error banner (same blue inline style as login)
// ═══════════════════════════════════════════════════════════════════════════
class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 18,
              iconSize: 18,
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textTertiary),
              onPressed: onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shake wrapper for validation feedback
// ═══════════════════════════════════════════════════════════════════════════
class _ShakeWrap extends StatelessWidget {
  final AnimationController ctrl;
  final Widget child;
  const _ShakeWrap({required this.ctrl, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, c) {
        final t = ctrl.value;
        final dx = t == 0 ? 0.0 : _sin(t * 12.5) * 9 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: c);
      },
      child: child,
    );
  }

  // Inlined to avoid pulling dart:math
  double _sin(double x) {
    // Simple sin approximation via Taylor — good enough for shake.
    x = x % (2 * 3.14159265358979);
    if (x > 3.14159265) x -= 2 * 3.14159265358979;
    final x2 = x * x;
    return x * (1 - x2 / 6 * (1 - x2 / 20));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Fade + slide entrance
// ═══════════════════════════════════════════════════════════════════════════
class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _FadeSlideIn({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, c) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}
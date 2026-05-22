import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';

import 'doctor_profile_view_screen.dart';

/// Screen shown when the user taps a specialty tile on the dashboard.
/// Fetches doctors filtered by [specialty] from Supabase, then lets the user
/// further filter by state and city. Mirrors the visual language of
/// FindDoctorsScreen so the two screens feel like part of the same family.
class SpecialtyDoctorsScreen extends StatefulWidget {
  final String specialty;
  final IconData icon;
  final Color color;

  const SpecialtyDoctorsScreen({
    super.key,
    required this.specialty,
    required this.icon,
    required this.color,
  });

  @override
  State<SpecialtyDoctorsScreen> createState() => _SpecialtyDoctorsScreenState();
}

class _SpecialtyDoctorsScreenState extends State<SpecialtyDoctorsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  String _query = '';
  String _selectedState = 'All';
  String _selectedCity = 'All';

  late Future<_SpecialtyData> _future;
  _SpecialtyData? _cached;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchCtrl.addListener(() {
      if (_query != _searchCtrl.text) {
        setState(() => _query = _searchCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────
  Future<_SpecialtyData> _load() async {
    final user = _supabase.auth.currentUser;

    final results = await Future.wait([
      _supabase
          .from('doctors')
          .select(
        'id, name, specialization, hospital_name, experience_years, '
            'license_number, state, city, address, about, education, '
            'languages, consultation_fee, available_online, profiles(full_name)',
      )
          .ilike('specialization', '%${widget.specialty}%')
          .order('name', ascending: true),
      if (user != null)
        _supabase
            .from('doctor_requests')
            .select('doctor_id, status')
            .eq('patient_id', user.id)
      else
        Future.value(<dynamic>[]),
    ]);

    final doctors = (results[0] as List).cast<Map<String, dynamic>>();
    final requests = (results[1] as List).cast<Map<String, dynamic>>();

    final statusByDoctor = <String, String>{
      for (final r in requests)
        r['doctor_id'] as String: (r['status'] ?? 'pending') as String,
    };

    final data =
    _SpecialtyData(doctors: doctors, statusByDoctor: statusByDoctor);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _cached = data);
    });
    return data;
  }

  void _refresh() => setState(() {
    _future = _load();
    _cached = null;
  });

  // ── Dynamic filter lists from live data ─────────────────────────────────
  List<String> get _states {
    final s = <String>{'All'};
    for (final d in _cached?.doctors ?? const []) {
      final v = d['state'] as String?;
      if (v != null && v.isNotEmpty) s.add(v);
    }
    return s.toList()
      ..sort((a, b) => a == 'All' ? -1 : b == 'All' ? 1 : a.compareTo(b));
  }

  List<String> get _cities {
    final c = <String>{'All'};
    for (final d in _cached?.doctors ?? const []) {
      if (_selectedState != 'All' && d['state'] != _selectedState) continue;
      final v = d['city'] as String?;
      if (v != null && v.isNotEmpty) c.add(v);
    }
    return c.toList()
      ..sort((a, b) => a == 'All' ? -1 : b == 'All' ? 1 : a.compareTo(b));
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    return all.where((d) {
      if (_selectedState != 'All' && d['state'] != _selectedState) return false;
      if (_selectedCity != 'All' && d['city'] != _selectedCity) return false;
      if (_query.trim().isNotEmpty) {
        final q = _query.trim().toLowerCase();
        return _doctorName(d).toLowerCase().contains(q) ||
            (d['hospital_name'] ?? '').toString().toLowerCase().contains(q) ||
            (d['city'] ?? '').toString().toLowerCase().contains(q) ||
            (d['state'] ?? '').toString().toLowerCase().contains(q) ||
            (d['education'] ?? '').toString().toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  void _openStateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatePickerSheet(
        states: _states,
        selected: _selectedState,
        accent: widget.color,
        onSelect: (s) {
          setState(() {
            _selectedState = s;
            _selectedCity = 'All';
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FutureBuilder<_SpecialtyData>(
        future: _future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final data = snapshot.data ?? _SpecialtyData.empty();
          final filtered = _applyFilters(data.doctors);

          return Column(
            children: [
              _SpecialtyTopHeader(
                specialty: widget.specialty,
                icon: widget.icon,
                accent: widget.color,
                searchCtrl: _searchCtrl,
                query: _query,
                selectedState: _selectedState,
                onClearSearch: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                onStateTap: _cached != null ? _openStateSheet : null,
                doctorCount: data.doctors.length,
              ),
              _CityChipStrip(
                cities: _cities,
                selected: _selectedCity,
                accent: widget.color,
                onChanged: (c) => setState(() => _selectedCity = c),
              ),
              Expanded(
                child: loading
                    ? Center(
                    child:
                    CircularProgressIndicator(color: widget.color))
                    : snapshot.hasError
                    ? _FullError(
                    message: '${snapshot.error}', onRetry: _refresh)
                    : filtered.isEmpty
                    ? _EmptyView(
                  icon: widget.icon,
                  accent: widget.color,
                  title: data.doctors.isEmpty
                      ? 'No ${widget.specialty} doctors yet'
                      : 'No doctors match your filters',
                  subtitle: data.doctors.isEmpty
                      ? "We couldn't find any registered "
                      '${widget.specialty.toLowerCase()} specialists.'
                      : 'Try clearing the city or search filter.',
                )
                    : RefreshIndicator(
                  color: widget.color,
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        16, 16, 16, 28),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final doc = filtered[i];
                      return StaggeredAppear(
                        index: i,
                        delayMsPerIndex: 40,
                        child: _DoctorCard(
                          doctor: doc,
                          accent: widget.color,
                          status: data.statusByDoctor[
                          doc['id']] ??
                              '',
                          onTap: () async {
                            final id = doc['id'] as String?;
                            if (id == null) return;
                            final result = await Navigator.of(
                                context)
                                .push<String>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DoctorProfileViewScreen(
                                        doctorId: id),
                              ),
                            );
                            if (result != null) _refresh();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Top header — themed to specialty color, structurally same as Find Doctors
// ═══════════════════════════════════════════════════════════════════════════
class _SpecialtyTopHeader extends StatelessWidget {
  final String specialty;
  final IconData icon;
  final Color accent;
  final TextEditingController searchCtrl;
  final String query;
  final String selectedState;
  final VoidCallback? onStateTap;
  final VoidCallback onClearSearch;
  final int doctorCount;

  const _SpecialtyTopHeader({
    required this.specialty,
    required this.icon,
    required this.accent,
    required this.searchCtrl,
    required this.query,
    required this.selectedState,
    required this.onStateTap,
    required this.onClearSearch,
    required this.doctorCount,
  });

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: mediaTop),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.92), accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
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
                      border:
                      Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 19),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '$doctorCount doctor${doctorCount == 1 ? '' : 's'}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onStateTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border:
                      Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(
                            selectedState == 'All'
                                ? 'All India'
                                : selectedState,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          onStateTap != null
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.hourglass_empty_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: searchCtrl,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Doctors, hospitals, cities…',
                  hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.textTertiary, fontSize: 14),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: Icon(Icons.search_rounded,
                        color: AppColors.textTertiary, size: 22),
                  ),
                  prefixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textTertiary),
                    onPressed: onClearSearch,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// City chip strip (themed)
// ═══════════════════════════════════════════════════════════════════════════
class _CityChipStrip extends StatelessWidget {
  final List<String> cities;
  final String selected;
  final Color accent;
  final ValueChanged<String> onChanged;

  const _CityChipStrip({
    required this.cities,
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.location_city_rounded,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'City',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              itemCount: cities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final city = cities[i];
                final sel = city == selected;
                return _CityChip(
                  label: city == 'All' ? 'All cities' : city,
                  icon:
                  city == 'All' ? Icons.public_rounded : Icons.place_rounded,
                  selected: sel,
                  accent: accent,
                  onTap: () => onChanged(city),
                );
              },
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.border),
        ],
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _CityChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? accent : accent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : accent.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: accent.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13, color: selected ? Colors.white : accent),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : accent,
                  height: 1.1,
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
// Doctor card — visually mirrors find_doctors_screen._DoctorCard
// ═══════════════════════════════════════════════════════════════════════════
class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final Color accent;
  final String status;
  final VoidCallback onTap;

  const _DoctorCard({
    required this.doctor,
    required this.accent,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = _doctorName(doctor);
    final spec = doctor['specialization'] as String?;
    final hosp = doctor['hospital_name'] as String?;
    final years = doctor['experience_years'];
    final city = doctor['city'] as String?;
    final state = doctor['state'] as String?;
    final fee = doctor['consultation_fee'] as int?;
    final online = (doctor['available_online'] ?? false) as bool;
    final edu = doctor['education'] as String?;
    final initials = _initials(name);

    final locationStr = [
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
    ].join(', ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent.withOpacity(0.85), accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              'Dr. $name',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (online) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const PulseDot(
                                      color: AppColors.success, size: 6),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Online',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ]),
                        if (spec != null && spec.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              spec,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                        if (edu != null && edu.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            edu,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (hosp != null && hosp.isNotEmpty) ...[
                      const Icon(Icons.local_hospital_outlined,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hosp,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (years != null) ...[
                      const SizedBox(width: 8),
                      _Badge('$years yrs', const Color(0xFF8B5CF6)),
                    ],
                    if (fee != null) ...[
                      const SizedBox(width: 6),
                      _Badge('₹$fee', AppColors.success),
                    ],
                  ],
                ),
              ),
              if (locationStr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label, IconData icon) = switch (status) {
      'accepted' => (
      AppColors.success.withOpacity(0.1),
      AppColors.success,
      'Connected',
      Icons.check_circle_rounded
      ),
      'pending' => (
      AppColors.warning.withOpacity(0.12),
      AppColors.warning,
      'Pending',
      Icons.hourglass_top_rounded
      ),
      'rejected' => (
      AppColors.accentRed.withOpacity(0.1),
      AppColors.accentRed,
      'Declined',
      Icons.cancel_outlined
      ),
      _ => (
      AppColors.primary.withOpacity(0.1),
      AppColors.primary,
      'Request',
      Icons.person_add_alt_rounded
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// State picker sheet
// ═══════════════════════════════════════════════════════════════════════════
class _StatePickerSheet extends StatefulWidget {
  final List<String> states;
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelect;

  const _StatePickerSheet({
    required this.states,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  @override
  State<_StatePickerSheet> createState() => _StatePickerSheetState();
}

class _StatePickerSheetState extends State<_StatePickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.states
        .where((s) => s.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        Container(
          width: 44,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.accent.withOpacity(0.85), widget.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.map_outlined,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select State',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Filter doctors by location',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textTertiary),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: GoogleFonts.plusJakartaSans(fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'Search state…',
              hintStyle:
              GoogleFonts.plusJakartaSans(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textTertiary, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: widget.accent, width: 1.6),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) {
              final state = filtered[i];
              final sel = state == widget.selected;
              return InkWell(
                onTap: () => widget.onSelect(state),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    if (state != 'All') ...[
                      const Icon(Icons.location_on_outlined,
                          size: 16, color: AppColors.textTertiary),
                      const SizedBox(width: 10),
                    ] else ...[
                      Icon(Icons.public_rounded,
                          size: 16, color: widget.accent),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        state,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? widget.accent : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (sel)
                      Icon(Icons.check_circle_rounded,
                          color: widget.accent, size: 20),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty / error states
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  const _EmptyView({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 38, color: accent),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FullError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _FullError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 52, color: AppColors.accentRed),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────
String _doctorName(Map<String, dynamic> d) {
  String? raw = d['name'] as String?;
  if (raw == null || raw.trim().isEmpty) {
    final profile = d['profiles'] as Map<String, dynamic>?;
    raw = profile?['full_name'] as String?;
  }
  if (raw == null || raw.trim().isEmpty) return 'Doctor';

  final cleaned = raw
      .trim()
      .replaceFirst(RegExp(r'^dr\.?\s+', caseSensitive: false), '')
      .trim();

  return cleaned.isEmpty ? 'Doctor' : cleaned;
}

String _initials(String name) {
  if (name.trim().isEmpty) return 'DR';
  return name
      .trim()
      .split(RegExp(r'\s+'))
      .map((p) => p.isEmpty ? '' : p[0])
      .take(2)
      .join()
      .toUpperCase();
}

class _SpecialtyData {
  final List<Map<String, dynamic>> doctors;
  final Map<String, String> statusByDoctor;
  _SpecialtyData({required this.doctors, required this.statusByDoctor});
  factory _SpecialtyData.empty() =>
      _SpecialtyData(doctors: const [], statusByDoctor: const {});
}
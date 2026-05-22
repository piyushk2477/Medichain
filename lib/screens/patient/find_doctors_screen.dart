import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';

import 'doctor_profile_view_screen.dart';
import 'send_records_screen.dart';

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

  String _query         = '';
  String _selectedState = 'All';
  String _selectedCity  = 'All';
  String _selectedSpec  = 'All';
  bool _showAllSpecs    = false;

  late Future<_DoctorsData> _future;
  _DoctorsData? _cached;

  // Static specialty descriptions for the grid cards
  static const Map<String, (IconData, String)> _specInfo = {
    'General Physician':       (Icons.medical_services_outlined,    'Primary care & common ailments'),
    'Cardiology':              (Icons.favorite_outline_rounded,     'Heart & cardiovascular'),
    'Dermatology':             (Icons.face_outlined,                'Skin, hair & nails'),
    'Pediatrics':              (Icons.child_care_outlined,          'Child health'),
    'Orthopedics':             (Icons.accessibility_new_outlined,   'Bones, joints, muscles'),
    'Neurology':               (Icons.psychology_outlined,          'Brain & nervous system'),
    'Dentistry':               (Icons.mood_outlined,                'Dental & oral health'),
    'Gynecology & Obstetrics': (Icons.pregnant_woman_outlined,      "Women's health"),
    'Psychiatry':              (Icons.self_improvement_outlined,    'Mental health'),
    'Ophthalmology':           (Icons.remove_red_eye_outlined,      'Eye care & vision'),
    'ENT (Ear, Nose, Throat)': (Icons.hearing_outlined,             'Ear, nose & throat'),
    'Gastroenterology':        (Icons.medical_information_outlined, 'Digestive system'),
    'Oncology':                (Icons.biotech_outlined,             'Cancer care'),
    'Endocrinology':           (Icons.monitor_outlined,             'Hormones & metabolism'),
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _future = _load();
    _tab.addListener(() => setState(() {}));
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

  // ── Data loading (unchanged) ───────────────────────────────────────────

  Future<_DoctorsData> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return _DoctorsData.empty();

    final results = await Future.wait([
      _supabase
          .from('doctors')
          .select(
        'id, name, specialization, hospital_name, experience_years, '
            'license_number, state, city, address, about, education, '
            'languages, consultation_fee, available_online, profiles(full_name)',
      )
          .order('name', ascending: true),
      _supabase
          .from('doctor_requests')
          .select('doctor_id, status')
          .eq('patient_id', user.id),
    ]);

    final doctors  = (results[0] as List).cast<Map<String, dynamic>>();
    final requests = (results[1] as List).cast<Map<String, dynamic>>();

    final statusByDoctor = <String, String>{
      for (final r in requests)
        r['doctor_id'] as String: (r['status'] ?? 'pending') as String,
    };

    final data = _DoctorsData(doctors: doctors, statusByDoctor: statusByDoctor);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _cached = data);
    });
    return data;
  }

  void _refresh() => setState(() { _future = _load(); _cached = null; });

  // ── Dynamic filter lists from live data ────────────────────────────────

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

  List<String> get _specs {
    final s = <String>{};
    for (final d in _cached?.doctors ?? const []) {
      if (_selectedState != 'All' && d['state'] != _selectedState) continue;
      if (_selectedCity != 'All' && d['city'] != _selectedCity) continue;
      final v = d['specialization'] as String?;
      if (v != null && v.isNotEmpty) s.add(v);
    }
    return s.toList()..sort();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    return all.where((d) {
      if (_selectedState != 'All' && d['state'] != _selectedState) return false;
      if (_selectedCity  != 'All' && d['city']  != _selectedCity)  return false;
      if (_selectedSpec  != 'All') {
        final spec = (d['specialization'] ?? '').toString();
        if (!spec.toLowerCase().contains(_selectedSpec.toLowerCase())) return false;
      }
      if (_query.trim().isNotEmpty) {
        final q = _query.trim().toLowerCase();
        return _doctorName(d).toLowerCase().contains(q) ||
            (d['specialization'] ?? '').toString().toLowerCase().contains(q) ||
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
        onSelect: (s) {
          setState(() {
            _selectedState = s;
            _selectedCity  = 'All';
            _selectedSpec  = 'All';
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
      body: FutureBuilder<_DoctorsData>(
        future: _future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final data    = snapshot.data ?? _DoctorsData.empty();
          final filtered = _applyFilters(data.doctors);
          final accepted = data.doctors
              .where((d) => data.statusByDoctor[d['id']] == 'accepted')
              .toList();

          return Column(
            children: [
              _TopHeader(
                searchCtrl: _searchCtrl,
                query: _query,
                tab: _tab,
                selectedState: _selectedState,
                onClearSearch: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                onStateTap: _cached != null ? _openStateSheet : null,
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : snapshot.hasError
                    ? _FullError(message: '${snapshot.error}', onRetry: _refresh)
                    : TabBarView(
                  controller: _tab,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _BrowseBody(
                      cached: _cached,
                      cities: _cities,
                      specs: _specs,
                      specInfo: _specInfo,
                      selectedCity: _selectedCity,
                      selectedSpec: _selectedSpec,
                      showAllSpecs: _showAllSpecs,
                      filtered: filtered,
                      statusByDoctor: data.statusByDoctor,
                      hasSearch: _query.isNotEmpty || _selectedSpec != 'All',
                      onCityChanged: (c) => setState(() {
                        _selectedCity = c;
                        _selectedSpec = 'All';
                      }),
                      onSpecChanged: (s) => setState(() {
                        _selectedSpec = _selectedSpec == s ? 'All' : s;
                      }),
                      onToggleSpecs: () =>
                          setState(() => _showAllSpecs = !_showAllSpecs),
                      onRefresh: _refresh,
                      onDoctorTap: (id) async {
                        final result = await Navigator.of(context)
                            .push<String>(MaterialPageRoute(
                          builder: (_) => DoctorProfileViewScreen(doctorId: id),
                        ));
                        if (result != null) _refresh();
                      },
                    ),
                    _MyDoctorsBody(
                      accepted: accepted,
                      onRefresh: _refresh,
                      onSend: (id) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SendRecordsScreen(presetDoctorId: id),
                        ),
                      ),
                      onView: (id) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DoctorProfileViewScreen(doctorId: id),
                        ),
                      ),
                    ),
                  ],
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
// Top gradient header
// ═══════════════════════════════════════════════════════════════════════════

class _TopHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String query;
  final TabController tab;
  final String selectedState;
  final VoidCallback? onStateTap;
  final VoidCallback onClearSearch;

  const _TopHeader({
    required this.searchCtrl,
    required this.query,
    required this.tab,
    required this.selectedState,
    required this.onStateTap,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: mediaTop),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), AppColors.primary, Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
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
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 19),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Find Doctors',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                ),
                InkWell(
                  onTap: onStateTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            selectedState == 'All' ? 'All India' : selectedState,
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white, fontSize: 12.5,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          onStateTap != null
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.hourglass_empty_rounded,
                          color: Colors.white, size: 14,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1),
                      blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: searchCtrl,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Doctors, specialties, hospitals…',
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
                      onPressed: onClearSearch),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          // Tab bar
          TabBar(
            controller: tab,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.55),
            labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 14.5),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w500, fontSize: 14.5),
            tabs: const [Tab(text: 'Browse'), Tab(text: 'My Doctors')],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Browse body
// ═══════════════════════════════════════════════════════════════════════════

class _BrowseBody extends StatelessWidget {
  final _DoctorsData? cached;
  final List<String> cities;
  final List<String> specs;
  final Map<String, (IconData, String)> specInfo;
  final String selectedCity;
  final String selectedSpec;
  final bool showAllSpecs;
  final List<Map<String, dynamic>> filtered;
  final Map<String, String> statusByDoctor;
  final bool hasSearch;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onSpecChanged;
  final VoidCallback onToggleSpecs;
  final VoidCallback onRefresh;
  final ValueChanged<String> onDoctorTap;

  const _BrowseBody({
    required this.cached,
    required this.cities,
    required this.specs,
    required this.specInfo,
    required this.selectedCity,
    required this.selectedSpec,
    required this.showAllSpecs,
    required this.filtered,
    required this.statusByDoctor,
    required this.hasSearch,
    required this.onCityChanged,
    required this.onSpecChanged,
    required this.onToggleSpecs,
    required this.onRefresh,
    required this.onDoctorTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cached == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    final visibleSpecs = showAllSpecs ? specs : specs.take(6).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── MODERN CITY CHIP STRIP ────────────────────────────────────
          if (cities.length > 1)
            SliverToBoxAdapter(
              child: _CityChipStrip(
                cities: cities,
                selected: selectedCity,
                onChanged: onCityChanged,
              ),
            ),

          // ── SPECIALTIES SECTION ───────────────────────────────────────
          if (specs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Row(
                  children: [
                    Text('Specialties',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary, letterSpacing: -0.3)),
                    const SizedBox(width: 8),
                    if (selectedSpec != 'All')
                      InkWell(
                        onTap: () => onSpecChanged('All'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close_rounded,
                                  size: 11, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(selectedSpec,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5, fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (specs.length > 6)
                      InkWell(
                        onTap: onToggleSpecs,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            showAllSpecs ? 'Show less' : 'View all',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5, fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  // Slightly taller to give descriptions breathing room
                  childAspectRatio: 2.05,
                ),
                itemCount: visibleSpecs.length,
                itemBuilder: (_, i) {
                  final spec = visibleSpecs[i];
                  final (icon, desc) = specInfo[spec] ??
                      (Icons.medical_services_outlined, 'Specialist care');
                  final selected = selectedSpec == spec;
                  return _SpecCard(
                    icon: icon,
                    name: spec,
                    description: desc,
                    selected: selected,
                    onTap: () => onSpecChanged(spec),
                  );
                },
              ),
            ),
          ],

          // ── DOCTORS SECTION ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
              child: Row(
                children: [
                  Text('Doctors',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary, letterSpacing: -0.3)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${filtered.length} found',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                  const Spacer(),
                  if (selectedSpec != 'All' || hasSearch)
                    InkWell(
                      onTap: () => onSpecChanged('All'),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_off_rounded,
                              size: 14, color: AppColors.accentRed),
                          const SizedBox(width: 4),
                          Text('Clear',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5, fontWeight: FontWeight.w700,
                                  color: AppColors.accentRed)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyView(
                icon: Icons.search_off_rounded,
                title: 'No doctors found',
                subtitle: hasSearch
                    ? 'Try different filters or search terms.'
                    : 'Doctors will appear here once they register.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => StaggeredAppear(
                  index: i,
                  child: _DoctorCard(
                    doctor: filtered[i],
                    status: statusByDoctor[filtered[i]['id']] ?? 'none',
                    onTap: () => onDoctorTap(filtered[i]['id'] as String),
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
// 🆕 City CHIP strip — modern pill chips replacing the old underline tabs
// (Fixes the 4.5px overflow + aligns with the rest of the app's pill aesthetic)
// ═══════════════════════════════════════════════════════════════════════════

class _CityChipStrip extends StatelessWidget {
  final List<String> cities;
  final String selected;
  final ValueChanged<String> onChanged;
  const _CityChipStrip({
    required this.cities, required this.selected, required this.onChanged,
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
                Text('City',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5, fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary, letterSpacing: 0.5)),
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
                final sel  = city == selected;
                return _CityChip(
                  label: city == 'All' ? 'All cities' : city,
                  icon: city == 'All'
                      ? Icons.public_rounded
                      : Icons.place_rounded,
                  selected: sel,
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
  final VoidCallback onTap;
  const _CityChip({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.primary.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color: selected ? Colors.white : AppColors.primary),
              const SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.primary,
                    height: 1.1,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Specialty card
// ═══════════════════════════════════════════════════════════════════════════

class _SpecCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  const _SpecCard({
    required this.icon, required this.name, required this.description,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon,
                    color: selected ? Colors.white : AppColors.primary,
                    size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            height: 1.15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(description,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                            height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
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
// My Doctors body
// ═══════════════════════════════════════════════════════════════════════════

class _MyDoctorsBody extends StatelessWidget {
  final List<Map<String, dynamic>> accepted;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onView;

  const _MyDoctorsBody({
    required this.accepted, required this.onRefresh,
    required this.onSend, required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    if (accepted.isEmpty) {
      return const _EmptyView(
        icon: Icons.handshake_outlined,
        title: 'No connected doctors yet',
        subtitle:
        'Go to Browse and send a connection request. Once accepted, they appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: accepted.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final d = accepted[i];
          return StaggeredAppear(
            index: i,
            child: _ConnectedDoctorCard(
              doctor: d,
              onSendData: () => onSend(d['id'] as String),
              onView: () => onView(d['id'] as String),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Doctor card (Browse)
// ═══════════════════════════════════════════════════════════════════════════

class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final String status;
  final VoidCallback onTap;
  const _DoctorCard({required this.doctor, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name     = _doctorName(doctor);
    final spec     = doctor['specialization'] as String?;
    final hosp     = doctor['hospital_name'] as String?;
    final years    = doctor['experience_years'];
    final city     = doctor['city'] as String?;
    final state    = doctor['state'] as String?;
    final fee      = doctor['consultation_fee'] as int?;
    final online   = (doctor['available_online'] ?? false) as bool;
    final edu      = doctor['education'] as String?;
    final initials = _initials(name);

    final locationStr = [
      if (city  != null && city.isNotEmpty)  city,
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
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(initials,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.w800,
                            fontSize: 17)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(child: Text('Dr. $name',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.5, fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (online) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const PulseDot(color: AppColors.success, size: 6),
                                const SizedBox(width: 4),
                                Text('Online',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10, fontWeight: FontWeight.w700,
                                        color: AppColors.success)),
                              ]),
                            ),
                          ],
                        ]),
                        if (spec != null && spec.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(spec,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ),
                        ],
                        if (edu != null && edu.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(edu,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    if (hosp != null && hosp.isNotEmpty) ...[
                      const Icon(Icons.local_hospital_outlined,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(child: Text(hosp,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                  Text(locationStr,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5, color: AppColors.textSecondary)),
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
        borderRadius: BorderRadius.circular(6)),
    child: Text(label,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Connected doctor card (My Doctors)
// ═══════════════════════════════════════════════════════════════════════════

class _ConnectedDoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onSendData;
  final VoidCallback onView;
  const _ConnectedDoctorCard({
    required this.doctor, required this.onSendData, required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final name     = _doctorName(doctor);
    final spec     = doctor['specialization'] as String?;
    final hosp     = doctor['hospital_name'] as String?;
    final city     = doctor['city'] as String?;
    final online   = (doctor['available_online'] ?? false) as bool;
    final initials = _initials(name);

    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.success.withOpacity(0.3))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF059669)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: Text(initials, style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text('Dr. $name',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, color: AppColors.success, size: 15),
                  if (online) ...[
                    const SizedBox(width: 4),
                    const PulseDot(color: AppColors.success, size: 7),
                  ],
                ]),
                if (spec != null && spec.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(spec, style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5, color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
                ],
                if (hosp != null || city != null)
                  Text([if (hosp != null) hosp, if (city != null) city].join(' · '),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            InkWell(
              onTap: onView,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 18),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: ElevatedButton.icon(
            onPressed: onSendData,
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text('Send Records', style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 14)),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// State picker bottom sheet
// ═══════════════════════════════════════════════════════════════════════════

class _StatePickerSheet extends StatefulWidget {
  final List<String> states;
  final String selected;
  final ValueChanged<String> onSelect;
  const _StatePickerSheet({
    required this.states, required this.selected, required this.onSelect,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        Container(width: 44, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: AppColors.border,
                borderRadius: BorderRadius.circular(4))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), AppColors.primary],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: const Icon(Icons.map_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Select State', style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
              Text('Filter doctors by location', style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5, color: AppColors.textSecondary)),
            ])),
            IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: GoogleFonts.plusJakartaSans(fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'Search state…',
              hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textTertiary, size: 20),
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
              final state = filtered[i];
              final sel   = state == widget.selected;
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
                      const Icon(Icons.public_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: Text(state,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? AppColors.primary : AppColors.textPrimary))),
                    if (sel)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 20),
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
// Status badge, empty, error
// ═══════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label, IconData icon) = switch (status) {
      'accepted' => (AppColors.success.withOpacity(0.1), AppColors.success,
      'Connected', Icons.check_circle_rounded),
      'pending' => (AppColors.warning.withOpacity(0.12), AppColors.warning,
      'Pending', Icons.hourglass_top_rounded),
      'rejected' => (AppColors.accentRed.withOpacity(0.1), AppColors.accentRed,
      'Declined', Icons.cancel_outlined),
      _ => (AppColors.primary.withOpacity(0.1), AppColors.primary,
      'Request', Icons.person_add_alt_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyView({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 88, height: 88,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 38, color: AppColors.primary)),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
      ]),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 52, color: AppColors.accentRed),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    ),
  );
}

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Returns the doctor's display name WITHOUT a leading "Dr." / "Dr " prefix,
/// since callers always prepend "Dr. " themselves. This prevents
/// "Dr. Dr. Pranav B" when the DB row already contains "Dr. Pranav B".
String _doctorName(Map<String, dynamic> d) {
  String? raw = d['name'] as String?;
  if (raw == null || raw.trim().isEmpty) {
    final profile = d['profiles'] as Map<String, dynamic>?;
    raw = profile?['full_name'] as String?;
  }
  if (raw == null || raw.trim().isEmpty) return 'Doctor';

  // Strip any leading "Dr.", "Dr ", "DR.", "dr.", etc.
  final cleaned = raw
      .trim()
      .replaceFirst(RegExp(r'^dr\.?\s+', caseSensitive: false), '')
      .trim();

  return cleaned.isEmpty ? 'Doctor' : cleaned;
}

String _initials(String name) {
  if (name.trim().isEmpty) return 'DR';
  return name.trim().split(RegExp(r'\s+')).map((p) => p.isEmpty ? '' : p[0])
      .take(2).join().toUpperCase();
}

class _DoctorsData {
  final List<Map<String, dynamic>> doctors;
  final Map<String, String> statusByDoctor;
  _DoctorsData({required this.doctors, required this.statusByDoctor});
  factory _DoctorsData.empty() =>
      _DoctorsData(doctors: const [], statusByDoctor: const {});
}
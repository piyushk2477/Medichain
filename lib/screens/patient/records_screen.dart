import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';

import 'package:medichain_beta/services/records_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';

import 'audit_log_screen.dart';
import 'send_records_screen.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen>
    with TickerProviderStateMixin {
  late Future<List<MedicalRecord>> _future;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String _filter = 'All';
  bool _searchFocused = false;

  late final AnimationController _entranceCtrl;
  late final AnimationController _fabPulse;

  static const _filterToCategory = <String, String?>{
    'All': null,
    'Lab Reports': 'Lab Report',
    'Prescriptions': 'Prescription',
    'Scans': 'Scan / Imaging',
    'Bills': 'Invoice / Bill',
  };

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
    _fabPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _future = RecordsService.listMyRecords();
    _searchCtrl.addListener(() {
      if (_query != _searchCtrl.text) {
        setState(() => _query = _searchCtrl.text);
      }
    });
    _searchFocus.addListener(() {
      if (_searchFocused != _searchFocus.hasFocus) {
        setState(() => _searchFocused = _searchFocus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _entranceCtrl.dispose();
    _fabPulse.dispose();
    super.dispose();
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
    parent: _entranceCtrl,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  void _refresh() =>
      setState(() => _future = RecordsService.listMyRecords());

  List<MedicalRecord> _applyFilters(List<MedicalRecord> all) {
    Iterable<MedicalRecord> result = all;
    final cat = _filterToCategory[_filter];
    if (cat != null) result = result.where((r) => r.category == cat);
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      result = result.where((r) =>
      r.title.toLowerCase().contains(q) ||
          (r.filename ?? '').toLowerCase().contains(q) ||
          (r.category ?? '').toLowerCase().contains(q));
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FutureBuilder<List<MedicalRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final loading =
              snapshot.connectionState == ConnectionState.waiting;
          final all = snapshot.data ?? [];
          final filtered = _applyFilters(all);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: BrandHeader(
                    title: 'My Records',
                    subtitle: 'All your medical documents in one place',
                    top: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.22)),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.folder_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        if (!loading)
                          _FadeSlideIn(
                            animation: _stage(0.0, 0.35),
                            slide: 8,
                            child: _CountBadge(count: all.length),
                          ),
                      ],
                    ),
                    trailing: HeaderIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: _refresh,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                // ── Search bar (animated focus) ──────────────────────
                SliverToBoxAdapter(
                  child: _FadeSlideIn(
                    animation: _stage(0.05, 0.40),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(
                                  _searchFocused ? 0.18 : 0.0),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search records…',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: AppColors.textTertiary,
                              fontSize: 14.5,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(
                                  left: 14, right: 8),
                              child: Icon(
                                Icons.search_rounded,
                                color: _searchFocused
                                    ? AppColors.primary
                                    : AppColors.textTertiary,
                                size: 22,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                                minWidth: 44, minHeight: 44),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.textTertiary),
                              onPressed: () => _searchCtrl.clear(),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                              BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 1.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // ── Filter chips (safe AnimatedContainer) ────────────
                SliverToBoxAdapter(
                  child: _FadeSlideIn(
                    animation: _stage(0.10, 0.45),
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                        children: _filterToCategory.keys.map((label) {
                          final selected = label == _filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: label,
                              selected: selected,
                              onTap: () =>
                                  setState(() => _filter = label),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Body ─────────────────────────────────────────────
                if (loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorView(
                        message: '${snapshot.error}', onRetry: _refresh),
                  )
                else if (all.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        onUpload: () => Navigator.pushReplacementNamed(
                            context, '/patient/upload'),
                      ),
                    )
                  else if (filtered.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NoMatches(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        sliver: SliverList.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                          itemBuilder: (context, i) => _FadeSlideIn(
                            animation: _stage(
                              (0.15 + i * 0.05).clamp(0.0, 0.85),
                              ((0.15 + i * 0.05) + 0.30).clamp(0.0, 1.0),
                            ),
                            slide: 12,
                            child: _RecordCard(
                              record: filtered[i],
                              onChanged: _refresh,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _PulsingFab(
        pulse: _fabPulse,
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SendRecordsScreen()),
          );
          _refresh();
        },
      ),
      bottomNavigationBar: const PatientBottomNav(currentIndex: 2),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Animated count badge in the header
// ═══════════════════════════════════════════════════════════════════════════
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined,
              size: 13, color: Colors.white),
          const SizedBox(width: 5),
          _AnimatedCount(
            value: count,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            count == 1 ? 'record' : 'records',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedCount extends StatefulWidget {
  final int value;
  final TextStyle style;
  const _AnimatedCount({required this.value, required this.style});

  @override
  State<_AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<_AnimatedCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<int> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _anim = IntTween(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Text('${_anim.value}', style: widget.style),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Filter chip — safe AnimatedContainer (only color/border lerp, no
// gradient/shadow null switches)
// ═══════════════════════════════════════════════════════════════════════════
class _FilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected
                  ? AppColors.primary
                  : AppColors.border,
            ),
            // Always-present shadow (opacity 0 when unselected)
            boxShadow: [
              BoxShadow(
                color: AppColors.primary
                    .withOpacity(widget.selected ? 0.25 : 0.0),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              color: widget.selected
                  ? Colors.white
                  : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Pulsing FAB
// ═══════════════════════════════════════════════════════════════════════════
class _PulsingFab extends StatelessWidget {
  final AnimationController pulse;
  final VoidCallback onPressed;
  const _PulsingFab({required this.pulse, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color:
                AppColors.primary.withOpacity(0.35 + 0.18 * (1 - t)),
                blurRadius: 16 + 14 * t,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            icon: const Icon(Icons.send_rounded),
            label: Text(
              'Send to doctor',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, fontSize: 14),
            ),
            onPressed: onPressed,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Record card (logic preserved) + press-scale animation
// ═══════════════════════════════════════════════════════════════════════════
class _RecordCard extends StatefulWidget {
  final MedicalRecord record;
  final VoidCallback onChanged;
  const _RecordCard({required this.record, required this.onChanged});

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  bool _opening = false;
  bool _pressed = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final file = await RecordsService.decryptToTempFile(widget.record);
      if (!mounted) return;
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open: $e')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete record?',
            style:
            GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'This removes "${widget.record.title}" from your records. The IPFS pin will remain unless you also remove it from Pinata.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RecordsService.deleteRecord(widget.record.id);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final (icon, tint) = _iconFor(r.category);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: _open,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: tint.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tint.withOpacity(0.18),
                      tint.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: _opening
                    ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: tint),
                )
                    : Icon(icon, color: tint, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (r.category != null) r.category!,
                        if (r.createdAt != null) _shortDate(r.createdAt!),
                        if (r.sizeBytes != null) _formatSize(r.sizeBytes!),
                      ].join(' · '),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: AppColors.textTertiary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (v) {
                  switch (v) {
                    case 'open':
                      _open();
                      break;
                    case 'share':
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SendRecordsScreen(
                            preselectedRecordIds: {r.id}),
                      ));
                      break;
                    case 'audit':
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AuditLogScreen(
                            recordId: r.id, recordTitle: r.title),
                      ));
                      break;
                    case 'delete':
                      _delete();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  _menu('open', Icons.open_in_new_rounded, 'Open'),
                  _menu('share', Icons.send_rounded, 'Send to doctor'),
                  _menu('audit', Icons.history_rounded, 'Access Log',
                      tint: AppColors.primary),
                  _menu('delete', Icons.delete_outline_rounded, 'Delete',
                      tint: AppColors.accentRed),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menu(String value, IconData icon, String label,
      {Color? tint}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint ?? AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tint ?? AppColors.textPrimary,
              )),
        ],
      ),
    );
  }

  (IconData, Color) _iconFor(String? category) {
    switch (category) {
      case 'Lab Report':
        return (Icons.science_outlined, AppColors.primary);
      case 'Prescription':
        return (Icons.medication_outlined, const Color(0xFF059669));
      case 'Scan / Imaging':
        return (Icons.monitor_heart_outlined, AppColors.accentRed);
      case 'Invoice / Bill':
        return (Icons.receipt_long_outlined, AppColors.warning);
      default:
        return (Icons.description_outlined, const Color(0xFF8B5CF6));
    }
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty / error / no-match states
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatefulWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final t = _pulse.value;
                      final size = 100 + 30 * t;
                      final op = (1 - t) * 0.30;
                      return Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(op),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x6633AAFF),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.folder_open_rounded,
                        size: 44, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No records yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload your first medical document\nto see it here',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onUpload,
              icon: const Icon(Icons.cloud_upload_rounded, size: 20),
              label: Text('Upload now',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.search_off_rounded,
                  size: 36, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 14),
            Text(
              'No matching records',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search or filter',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.error_outline,
                  size: 42, color: AppColors.accentRed),
            ),
            const SizedBox(height: 14),
            Text(
              'Could not load records',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 26, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Retry',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final double slide;
  const _FadeSlideIn({
    required this.animation,
    required this.child,
    this.slide = 18,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, c) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, slide * (1 - t)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:medichain_beta/services/sharing_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';

import 'secure_record_viewer.dart';

/// Doctor's view of records a specific patient has shared with them.
/// Only shows actively shared (non-revoked) records.
class PatientRecordsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientRecordsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientRecordsScreen> createState() => _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends State<PatientRecordsScreen> {
  late Future<List<SharedRecord>> _future;
  String _filter = 'All';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = SharingService.recordsSharedWithMe(patientId: widget.patientId);
  }

  void _refresh() {
    setState(() {
      _future = SharingService.recordsSharedWithMe(patientId: widget.patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<SharedRecord>>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final all = snapshot.data ?? [];
            final categories = <String>{'All'};
            for (final s in all) {
              if (s.record.category != null && s.record.category!.isNotEmpty) {
                categories.add(s.record.category!);
              }
            }

            // Apply filter + search
            var items = _filter == 'All'
                ? all
                : all.where((s) => s.record.category == _filter).toList();
            if (_search.isNotEmpty) {
              items = items
                  .where((s) => s.record.title.toLowerCase().contains(_search.toLowerCase()))
                  .toList();
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Branded header ────────────────────────────────────────
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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                widget.patientName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loading
                                    ? 'Loading records…'
                                    : '${all.length} record${all.length == 1 ? '' : 's'} shared with you',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.82),
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                // ── Search ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search records…',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 14, right: 8),
                          child: Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 22),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                // ── Category chips ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: categories.map((c) {
                        final selected = _filter == c;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setState(() => _filter = c),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? AppColors.primary : AppColors.border,
                                ),
                              ),
                              child: Text(
                                c,
                                style: TextStyle(
                                  color: selected ? Colors.white : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                // ── List / empty / loading ────────────────────────────────
                if (loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('${snapshot.error}', textAlign: TextAlign.center),
                      ),
                    ),
                  )
                else if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _RecordsEmptyState(
                        isAllEmpty: all.isEmpty,
                        patientName: widget.patientName,
                        filter: _filter,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _SharedRecordCard(item: items[i]),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecordsEmptyState extends StatelessWidget {
  final bool isAllEmpty;
  final String patientName;
  final String filter;
  const _RecordsEmptyState({
    required this.isAllEmpty,
    required this.patientName,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.folder_open_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              isAllEmpty ? 'No records yet' : 'No records in "$filter"',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAllEmpty
                  ? "$patientName hasn't shared any records with you yet."
                  : 'Try a different category.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedRecordCard extends StatefulWidget {
  final SharedRecord item;
  const _SharedRecordCard({required this.item});

  @override
  State<_SharedRecordCard> createState() => _SharedRecordCardState();
}

class _SharedRecordCardState extends State<_SharedRecordCard> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SecureRecordViewer(record: widget.item.record),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open: $e'), backgroundColor: AppColors.accentRed),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.item.record;
    final (IconData icon, Color tint) = _iconFor(r.category);
    final subtitle = [
      if (r.category != null) r.category!,
      if (widget.item.sharedAt != null) 'Shared ${_friendlyDate(widget.item.sharedAt!)}',
      if (widget.item.expiresAt != null) 'expires ${_friendlyExpiry(widget.item.expiresAt!)}',
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _opening ? null : _open,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: _opening
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
                    : Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _iconFor(String? category) {
    switch (category) {
      case 'Lab Report':
        return (Icons.science_outlined, const Color(0xFFE0E9FF));
      case 'Prescription':
        return (Icons.medication_outlined, const Color(0xFFDCFCE7));
      case 'Scan / Imaging':
        return (Icons.monitor_heart_outlined, const Color(0xFFFEE2E2));
      case 'Invoice / Bill':
        return (Icons.receipt_long_outlined, const Color(0xFFFEF3C7));
      default:
        return (Icons.description_outlined, const Color(0xFFEEF3FF));
    }
  }

  String _friendlyDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _friendlyExpiry(DateTime d) {
    final diff = d.difference(DateTime.now());
    if (diff.isNegative) return 'expired';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      return 'in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    }
    if (diff.inDays < 30) {
      return 'in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    }
    return 'on ${d.day}/${d.month}/${d.year}';
  }
}
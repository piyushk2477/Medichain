import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medichain_beta/services/records_service.dart';
import 'package:medichain_beta/services/sharing_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/faucet_dialog.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';

/// Two-step share flow — LOGIC UNCHANGED:
///   1. Pick which records to share (checkbox tiles)
///   2. Pick which connected doctor to share them with (bottom sheet)
class SendRecordsScreen extends StatefulWidget {
  final Set<String>? preselectedRecordIds;
  final String? presetDoctorId;

  const SendRecordsScreen({
    super.key,
    this.preselectedRecordIds,
    this.presetDoctorId,
  });

  @override
  State<SendRecordsScreen> createState() => _SendRecordsScreenState();
}

class _SendRecordsScreenState extends State<SendRecordsScreen> {
  final _supabase = Supabase.instance.client;

  late Future<_PickerData> _future;
  final Set<String> _selected = {};
  bool _sending = false;

  Duration? _expiryDuration = const Duration(days: 7);
  DateTime? _customExpiryAt;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedRecordIds != null) {
      _selected.addAll(widget.preselectedRecordIds!);
    }
    _future = _load();
  }

  // ── LOGIC PRESERVED EXACTLY ─────────────────────────────────────────────
  Future<_PickerData> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return _PickerData(records: [], doctors: []);

    final records = await RecordsService.listMyRecords();
    final requestRows = (await _supabase
        .from('doctor_requests')
        .select('doctor_id, status')
        .eq('patient_id', user.id)) as List;

    final requests = requestRows
        .cast<Map<String, dynamic>>()
        .where((r) => r['status'] == 'accepted')
        .toList();

    if (requests.isEmpty) {
      return _PickerData(records: records, doctors: []);
    }

    final doctorIds = requests.map((r) => r['doctor_id'] as String).toList();

    final doctorRows = await _supabase
        .from('doctors')
        .select('id, name, specialization, hospital_name')
        .inFilter('id', doctorIds);

    final doctors = (doctorRows as List).cast<Map<String, dynamic>>();
    return _PickerData(records: records, doctors: doctors);
  }

  Future<void> _proceedToDoctorPicker(_PickerData data) async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one record')),
      );
      return;
    }

    String? doctorId = widget.presetDoctorId;

    if (doctorId == null) {
      if (data.doctors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have no connected doctors yet')),
        );
        return;
      }
      doctorId = await _pickDoctor(data.doctors);
      if (doctorId == null) return;
    }

    await _share(doctorId);
  }

  Future<String?> _pickDoctor(List<Map<String, dynamic>> doctors) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DoctorPickerSheet(
        doctors: doctors,
        selectedCount: _selected.length,
      ),
    );
  }

  Future<void> _share(String doctorId) async {
    setState(() => _sending = true);
    try {
      final DateTime? expiresAt = _customExpiryAt ??
          (_expiryDuration == null
              ? null
              : DateTime.now().add(_expiryDuration!));

      final count = await SharingService.shareRecords(
        recordIds: _selected.toList(),
        doctorId: doctorId,
        expiresAt: expiresAt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text('Shared $count record${count == 1 ? '' : 's'}'),
          ]),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      if (isGasError(e)) {
        await showFaucetDialog(context, isError: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e'),
              backgroundColor: AppColors.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<DateTime?> _pickCustomExpiry() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _selectAll(List<MedicalRecord> records) {
    setState(() {
      _selected.addAll(records.map((r) => r.id));
    });
  }

  void _clearAll() => setState(() => _selected.clear());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FutureBuilder<_PickerData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return _ErrorBody(error: '${snapshot.error}');
          }
          final data = snapshot.data ?? _PickerData(records: [], doctors: []);

          if (data.records.isEmpty) {
            return _EmptyBody(
              icon: Icons.folder_open_rounded,
              title: 'No records to share',
              subtitle: 'Upload a document first, then come back to share it.',
              actionLabel: 'Go to Upload',
              onAction: () =>
                  Navigator.pushReplacementNamed(context, '/patient/upload'),
            );
          }
          if (data.doctors.isEmpty && widget.presetDoctorId == null) {
            return _EmptyBody(
              icon: Icons.handshake_outlined,
              title: 'No connected doctors',
              subtitle:
              'Connect with a doctor first — they need to accept your request before you can share records.',
              actionLabel: 'Find Doctors',
              onAction: () => Navigator.pop(context),
            );
          }

          return Column(
            children: [
              _SendHeader(
                selectedCount: _selected.length,
                total: data.records.length,
                onSelectAll: () => _selectAll(data.records),
                onClearAll: _clearAll,
              ),
              // Expiry row
              _ExpiryRow(
                duration: _expiryDuration,
                customAt: _customExpiryAt,
                onPreset: (d) => setState(() {
                  _expiryDuration = d;
                  _customExpiryAt = null;
                }),
                onCustom: () async {
                  final picked = await _pickCustomExpiry();
                  if (picked != null) {
                    setState(() {
                      _customExpiryAt = picked;
                      _expiryDuration = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  itemCount: data.records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = data.records[i];
                    final selected = _selected.contains(r.id);
                    return StaggeredAppear(
                      index: i,
                      child: _RecordPickTile(
                        record: r,
                        selected: selected,
                        onTap: () => setState(() {
                          if (selected) {
                            _selected.remove(r.id);
                          } else {
                            _selected.add(r.id);
                          }
                        }),
                      ),
                    );
                  },
                ),
              ),
              // Sticky send button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: ElevatedButton.icon(
                      onPressed: (_sending || _selected.isEmpty)
                          ? null
                          : () => _proceedToDoctorPicker(data),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textTertiary,
                      ),
                      icon: _sending
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _selected.isEmpty
                            ? 'Select records to send'
                            : 'Send ${_selected.length} record${_selected.length == 1 ? '' : 's'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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

// ─── Header ────────────────────────────────────────────────────────────────

class _SendHeader extends StatelessWidget {
  final int selectedCount;
  final int total;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  const _SendHeader({
    required this.selectedCount,
    required this.total,
    required this.onSelectAll,
    required this.onClearAll,
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
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Padding(
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
                      border:
                      Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 19),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Send Records',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selectedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$selectedCount selected',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border:
                Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Records are decrypted only for the doctor you choose.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: selectedCount == total
                        ? onClearAll
                        : onSelectAll,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selectedCount == total ? 'Clear' : 'All',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Expiry row ────────────────────────────────────────────────────────────

class _ExpiryRow extends StatelessWidget {
  final Duration? duration;
  final DateTime? customAt;
  final ValueChanged<Duration?> onPreset;
  final VoidCallback onCustom;

  const _ExpiryRow({
    required this.duration,
    required this.customAt,
    required this.onPreset,
    required this.onCustom,
  });

  static const _presets = [
    ('Forever', null),
    ('1 hr', Duration(hours: 1)),
    ('24 hrs', Duration(hours: 24)),
    ('7 days', Duration(days: 7)),
    ('30 days', Duration(days: 30)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.schedule_rounded,
                    color: AppColors.primary, size: 15),
              ),
              const SizedBox(width: 8),
              Text(
                'Access expires',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customAt != null
                      ? '· ${_fmt(customAt!)}'
                      : (duration == null
                      ? '· no expiry'
                      : '· in ${_humanize(duration!)}'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._presets.map((p) {
                  final (label, dur) = p;
                  final selected = customAt == null && duration == dur;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ExpiryChip(
                        label: label, selected: selected, onTap: () => onPreset(dur)),
                  );
                }),
                _ExpiryChip(
                  label: customAt == null ? 'Custom…' : 'Custom ✎',
                  selected: customAt != null,
                  onTap: onCustom,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _humanize(Duration d) {
    if (d.inDays >= 1) return '${d.inDays} day${d.inDays == 1 ? '' : 's'}';
    if (d.inHours >= 1) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
    return '${d.inMinutes} min';
  }

  static String _fmt(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mn = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} $hh:$mn';
  }
}

class _ExpiryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ExpiryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Record pick tile ──────────────────────────────────────────────────────

class _RecordPickTile extends StatelessWidget {
  final MedicalRecord record;
  final bool selected;
  final VoidCallback onTap;
  const _RecordPickTile({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = _iconFor(record.category);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.borderStrong,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: tint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (record.category != null) record.category!,
                        if (record.createdAt != null)
                          _shortDate(record.createdAt!),
                      ].join(' · '),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _iconFor(String? category) {
    switch (category) {
      case 'Lab Report': return (Icons.science_outlined, AppColors.primary);
      case 'Prescription': return (Icons.medication_outlined, const Color(0xFF059669));
      case 'Scan / Imaging': return (Icons.monitor_heart_outlined, AppColors.accentRed);
      case 'Invoice / Bill': return (Icons.receipt_long_outlined, AppColors.warning);
      default: return (Icons.description_outlined, const Color(0xFF7C8DB5));
    }
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─── Doctor picker bottom sheet ────────────────────────────────────────────

class _DoctorPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> doctors;
  final int selectedCount;
  const _DoctorPickerSheet({
    required this.doctors,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send to which doctor?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$selectedCount record${selectedCount == 1 ? '' : 's'} selected',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: doctors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final d = doctors[i];
                final id = d['id'] as String;
                final name = (d['name'] as String?) ?? 'Doctor';
                final spec = d['specialization'] as String?;
                final initials = name.isEmpty
                    ? 'DR'
                    : name
                    .trim()
                    .split(RegExp(r'\s+'))
                    .map((p) => p.isEmpty ? '' : p[0])
                    .take(2)
                    .join()
                    .toUpperCase();
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(id),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF34D399), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Dr. $name',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified_rounded,
                                        color: AppColors.success, size: 14),
                                  ],
                                ),
                                if (spec != null && spec.isNotEmpty)
                                  Text(
                                    spec,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.arrow_forward_rounded,
                                color: AppColors.primary, size: 16),
                          ),
                        ],
                      ),
                    ),
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

// ─── Empty / error bodies ──────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  const _EmptyBody({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 16),
                Text(
                  'Send Records',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, size: 38, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(title,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String error;
  const _ErrorBody({required this.error});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(error, textAlign: TextAlign.center),
      ),
    );
  }
}

// ─── Models ─────────────────────────────────────────────────────────────────

class _PickerData {
  final List<MedicalRecord> records;
  final List<Map<String, dynamic>> doctors;
  _PickerData({required this.records, required this.doctors});
}
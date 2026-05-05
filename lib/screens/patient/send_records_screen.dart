import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medichain_beta/services/records_service.dart';
import 'package:medichain_beta/services/sharing_service.dart';

/// Two-step flow:
///   1. Pick which records to share (with checkboxes)
///   2. Pick which connected doctor to share them with
///
/// If only one connected doctor exists, step 2 is auto-skipped.
/// Already-shared records show a "Shared" pill so the patient knows.
class SendRecordsScreen extends StatefulWidget {
  /// Optional: open with these records already ticked (used when
  /// invoking from a single record's "Send to doctor" menu).
  final Set<String>? preselectedRecordIds;

  /// Optional: open going straight to step 2 with this doctor.
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

  @override
  void initState() {
    super.initState();
    if (widget.preselectedRecordIds != null) {
      _selected.addAll(widget.preselectedRecordIds!);
    }
    _future = _load();
  }

  Future<_PickerData> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return _PickerData(records: [], doctors: []);

    // Two parallel-ish queries kept separate so the types stay clean.
    final recordsFuture = RecordsService.listMyRecords();
    final doctorsFuture = _supabase
        .from('doctor_requests')
        .select(
        'doctor:doctors!fk_doctor(id, name, specialization, hospital_name, profiles(full_name))')
        .eq('patient_id', user.id)
        .eq('status', 'accepted');

    final records = await recordsFuture;
    final docRows = (await doctorsFuture as List).cast<Map<String, dynamic>>();

    final doctors = docRows
        .map((r) => r['doctor'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .toList();

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
          const SnackBar(
              content: Text('You have no connected doctors yet')),
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
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Send to which doctor?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 4),
            Text(
              '${_selected.length} record${_selected.length == 1 ? '' : 's'} selected',
              style:
              TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: doctors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = doctors[i];
                  final id = d['id'] as String;
                  final name = (d['name'] as String?) ??
                      ((d['profiles']
                      as Map<String, dynamic>?)?['full_name']
                      as String?) ??
                      'Doctor';
                  final spec = d['specialization'] as String?;
                  return Material(
                    color: const Color(0xFFF5F5FA),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(ctx).pop(id),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BFA6)
                                    .withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.verified,
                                  color: Color(0xFF00BFA6)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A2E))),
                                  if (spec != null && spec.isNotEmpty)
                                    Text(spec,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios,
                                size: 14, color: Colors.grey[500]),
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
      ),
    );
  }

  Future<void> _share(String doctorId) async {
    setState(() => _sending = true);
    try {
      final count = await SharingService.shareRecords(
        recordIds: _selected.toList(),
        doctorId: doctorId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Shared $count record${count == 1 ? '' : 's'} with the doctor'),
          backgroundColor: const Color(0xFF00BFA6),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5FA),
        elevation: 0,
        title: const Text('Send to doctor',
            style: TextStyle(
                color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      body: FutureBuilder<_PickerData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final data = snapshot.data ?? _PickerData(records: [], doctors: []);

          if (data.records.isEmpty) {
            return _emptyMessage(
              icon: Icons.folder_open,
              title: 'No records to share',
              subtitle: 'Upload a document first, then come back to share it.',
              actionLabel: 'Go to Upload',
              onAction: () => Navigator.pushReplacementNamed(
                  context, '/patient/upload'),
            );
          }
          if (data.doctors.isEmpty && widget.presetDoctorId == null) {
            return _emptyMessage(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFF6C63FF), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pick records to share. The doctor will be able to decrypt and view them.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: data.records.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = data.records[i];
                    final isSelected = _selected.contains(r.id);
                    return _RecordPickTile(
                      record: r,
                      selected: isSelected,
                      onTap: () => setState(() {
                        if (isSelected) {
                          _selected.remove(r.id);
                        } else {
                          _selected.add(r.id);
                        }
                      }),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<_PickerData>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data;
              return ElevatedButton.icon(
                onPressed: (_sending || data == null || _selected.isEmpty)
                    ? null
                    : () => _proceedToDoctorPicker(data),
                icon: _sending
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.send_rounded),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _selected.isEmpty
                        ? 'Select records to send'
                        : 'Send ${_selected.length} record${_selected.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _emptyMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final color = selected ? const Color(0xFF6C63FF) : Colors.grey[400]!;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF6C63FF) : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: color,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                            fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (record.category != null) record.category!,
                        if (record.createdAt != null)
                          _shortDate(record.createdAt!),
                      ].join(' · '),
                      style:
                      TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _PickerData {
  final List<MedicalRecord> records;
  final List<Map<String, dynamic>> doctors;
  _PickerData({required this.records, required this.doctors});
}
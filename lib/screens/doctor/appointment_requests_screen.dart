import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:medichain_beta/services/appointment_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';

class AppointmentRequestsScreen extends StatefulWidget {
  final String doctorName;
  final String? hospital;
  const AppointmentRequestsScreen({
    super.key,
    required this.doctorName,
    this.hospital,
  });

  @override
  State<AppointmentRequestsScreen> createState() =>
      _AppointmentRequestsScreenState();
}

class _AppointmentRequestsScreenState
    extends State<AppointmentRequestsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      setState(() => _future = AppointmentService.getPendingRequests());

  // ── Confirm ───────────────────────────────────────────────────────────────

  Future<void> _confirm(Map<String, dynamic> req) async {
    final patient = req['patient'] as Map<String, dynamic>? ?? {};
    final patientName  = (patient['full_name'] as String?) ?? 'Patient';
    final patientEmail = (patient['email']     as String?) ?? '';

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        patientName:   patientName,
        preferredDate: req['preferred_date'] as String? ?? '',
        preferredTime: req['preferred_time'] as String? ?? '',
      ),
    );

    if (result == null || !mounted) return;

    final processing = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: const [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 10),
          Text('Sending confirmation email…'),
        ]),
        duration: const Duration(seconds: 30),
        backgroundColor: AppColors.primary,
      ),
    );

    try {
      await AppointmentService.confirmAppointment(
        requestId:     req['id'] as String,
        patientEmail:  patientEmail,
        patientName:   patientName,
        doctorName:    widget.doctorName,
        hospital:      widget.hospital,
        confirmedDate: result['date'] as DateTime,
        confirmedTime: result['time'] as String,
      );

      if (!mounted) return;
      processing.close();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.mark_email_read_outlined, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('Confirmed! Email sent to patient.')),
          ]),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      processing.close();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.accentRed),
      );
    }
  }

  // ── Decline ───────────────────────────────────────────────────────────────

  Future<void> _decline(String requestId, String patientName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Decline request',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
            "Decline $patientName's appointment request? This cannot be undone.",
            style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await AppointmentService.declineAppointment(requestId);
    _reload();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _Header(onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                final list = snap.data ?? [];
                if (list.isEmpty) return _EmptyState();
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                    itemBuilder: (_, i) => StaggeredAppear(
                      index: i,
                      child: _RequestCard(
                        request: list[i],
                        onConfirm: () => _confirm(list[i]),
                        onDecline: () {
                          final patient =
                              list[i]['patient'] as Map? ?? {};
                          _decline(
                            list[i]['id'] as String,
                            (patient['full_name'] as String?) ?? 'Patient',
                          );
                        },
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

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Row(children: [
          InkWell(
            onTap: onBack,
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
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appointment Requests',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text('Confirm or decline patient requests',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12.5)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Request card ────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;
  const _RequestCard({
    required this.request,
    required this.onConfirm,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final patient     = request['patient'] as Map<String, dynamic>? ?? {};
    final name        = (patient['full_name'] as String?) ?? 'Patient';
    final email       = (patient['email']     as String?) ?? '';
    final prefDate    = request['preferred_date'] as String? ?? '';
    final prefTime    = request['preferred_time'] as String? ?? '';
    final notes       = request['notes'] as String?;

    String displayDate = prefDate;
    try {
      displayDate =
          DateFormat('EEE, d MMM yyyy').format(DateTime.parse(prefDate));
    } catch (_) {}

    final initials = name.trim().isEmpty
        ? 'P'
        : name.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(email,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('PENDING',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: AppColors.warning, letterSpacing: 0.8)),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + time
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _Chip(icon: Icons.calendar_today_outlined,
                        label: displayDate, color: AppColors.primary),
                    _Chip(icon: Icons.schedule_outlined,
                        label: prefTime, color: const Color(0xFF8B5CF6)),
                  ],
                ),
                // Notes
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded,
                            size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(notes,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Action buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDecline,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text('Decline',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentRed,
                        side: const BorderSide(color: AppColors.accentRed),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text('Confirm & Email',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
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
            child: const Icon(Icons.event_available_rounded,
                size: 38, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text('No appointment requests',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('New requests from patients will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4)),
        ],
      ),
    ),
  );
}

// ─── Confirm bottom sheet ─────────────────────────────────────────────────

class _ConfirmSheet extends StatefulWidget {
  final String patientName;
  final String preferredDate;
  final String preferredTime;
  const _ConfirmSheet({
    required this.patientName,
    required this.preferredDate,
    required this.preferredTime,
  });

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  late DateTime _date;
  String? _time;

  static const _slots = [
    '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
    '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',  '3:00 PM', '3:30 PM',
    '4:00 PM', '5:00 PM', '5:30 PM', '6:00 PM',  '6:30 PM', '7:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    try { _date = DateTime.parse(widget.preferredDate); }
    catch (_) { _date = DateTime.now().add(const Duration(days: 1)); }
    _time = widget.preferredTime;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 44, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Sheet header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.event_available_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Confirm Appointment',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    Text('for ${widget.patientName}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: AppColors.textSecondary)),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient preference banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 15, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Patient preferred: ${widget.preferredDate}'
                              ' at ${widget.preferredTime}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ),
                    ]),
                  ),
                  Text('Confirmed Date',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: CalendarDatePicker(
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                      onDateChanged: (d) => setState(() => _date = d),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Confirmed Time',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _slots.map((s) {
                      final sel = s == _time;
                      return InkWell(
                        onTap: () => setState(() => _time = s),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? AppColors.primary : AppColors.border,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(s,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : AppColors.textSecondary)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _time == null
                        ? null
                        : () => Navigator.pop(
                      context,
                      {'date': _date, 'time': _time},
                    ),
                    icon: const Icon(Icons.mark_email_read_outlined,
                        size: 18),
                    label: Text('Confirm & Send Email',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
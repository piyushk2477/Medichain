import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:medichain_beta/services/appointment_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';

class BookAppointmentScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String? specialization;
  final String? hospital;

  const BookAppointmentScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    this.specialization,
    this.hospital,
  });

  @override
  State<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DateTime _selectedDate =
  DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  static const _morning = [
    '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM'
  ];
  static const _afternoon = [
    '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
    '3:00 PM', '3:30 PM', '4:00 PM', '4:30 PM'
  ];
  static const _evening = [
    '5:00 PM', '5:30 PM', '6:00 PM', '6:30 PM', '7:00 PM'
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await AppointmentService.requestAppointment(
        doctorId:      widget.doctorId,
        preferredDate: _selectedDate,
        preferredTime: _selectedTime!,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop('booked');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Appointment request sent!'),
          ]),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.accentRed),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _BookHeader(
            doctorName: widget.doctorName,
            specialization: widget.specialization,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date picker ──────────────────────────────────────
                  _SectionTitle(icon: Icons.calendar_month_rounded,
                      title: 'Select Date'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: CalendarDatePicker(
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                      onDateChanged: (d) => setState(() {
                        _selectedDate = d;
                        _selectedTime = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Time slots ───────────────────────────────────────
                  _SectionTitle(icon: Icons.schedule_rounded,
                      title: 'Select Time'),
                  const SizedBox(height: 12),
                  _TimeSlotGroup(
                    label: 'Morning',
                    icon: Icons.wb_sunny_outlined,
                    color: AppColors.warning,
                    slots: _morning,
                    selected: _selectedTime,
                    onSelect: (t) => setState(() => _selectedTime = t),
                  ),
                  const SizedBox(height: 10),
                  _TimeSlotGroup(
                    label: 'Afternoon',
                    icon: Icons.wb_cloudy_outlined,
                    color: AppColors.primary,
                    slots: _afternoon,
                    selected: _selectedTime,
                    onSelect: (t) => setState(() => _selectedTime = t),
                  ),
                  const SizedBox(height: 10),
                  _TimeSlotGroup(
                    label: 'Evening',
                    icon: Icons.nights_stay_outlined,
                    color: const Color(0xFF8B5CF6),
                    slots: _evening,
                    selected: _selectedTime,
                    onSelect: (t) => setState(() => _selectedTime = t),
                  ),
                  const SizedBox(height: 24),

                  // ── Notes ────────────────────────────────────────────
                  _SectionTitle(icon: Icons.notes_rounded,
                      title: 'Notes (optional)'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 4,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText:
                        'Describe your symptoms or reason for visit…',
                        hintStyle: GoogleFonts.plusJakartaSans(
                            color: AppColors.textTertiary, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  // ── Summary ──────────────────────────────────────────
                  if (_selectedTime != null) ...[
                    const SizedBox(height: 20),
                    _SummaryCard(
                      doctorName: widget.doctorName,
                      hospital: widget.hospital,
                      date: _selectedDate,
                      time: _selectedTime!,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // ── Sticky submit ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.07),
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
                  onPressed:
                  (_submitting || _selectedTime == null) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textTertiary,
                  ),
                  icon: _submitting
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                      : const Icon(Icons.event_available_rounded),
                  label: Text(
                    _selectedTime == null
                        ? 'Select a time to continue'
                        : 'Request Appointment',
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

class _BookHeader extends StatelessWidget {
  final String doctorName;
  final String? specialization;
  const _BookHeader(
      {required this.doctorName, this.specialization});

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
          Positioned(
            right: -40, top: 0,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2)),
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
                        Text('Book Appointment',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white, fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3)),
                        Text('with Dr. $doctorName',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ]),
                if (specialization != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.healing_outlined,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 6),
                        Text(specialization!,
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section title ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.primary, size: 17),
    ),
    const SizedBox(width: 10),
    Text(title,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 17, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary, letterSpacing: -0.2)),
  ]);
}

// ─── Time slot group ────────────────────────────────────────────────────────

class _TimeSlotGroup extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<String> slots;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _TimeSlotGroup({
    required this.label, required this.icon, required this.color,
    required this.slots, required this.selected, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: slots.map((s) {
            final sel = s == selected;
            return InkWell(
              onTap: () => onSelect(s),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? color : color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? color : color.withOpacity(0.2),
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(s,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : color)),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

// ─── Summary card ──────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String doctorName;
  final String? hospital;
  final DateTime date;
  final String time;
  const _SummaryCard({
    required this.doctorName, this.hospital,
    required this.date, required this.time,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.success.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.success.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.event_available_rounded,
              color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Text('Your request summary',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.success)),
        ]),
        const SizedBox(height: 12),
        _Row(icon: Icons.person_outline_rounded,
            label: 'Doctor', value: 'Dr. $doctorName'),
        _Row(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: DateFormat('EEE, d MMM yyyy').format(date)),
        _Row(icon: Icons.schedule_outlined, label: 'Time', value: time),
        if (hospital != null)
          _Row(icon: Icons.local_hospital_outlined,
              label: 'Location', value: hospital!, isLast: true),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  const _Row({required this.icon, required this.label,
    required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
    child: Row(children: [
      Icon(icon, size: 13, color: AppColors.textTertiary),
      const SizedBox(width: 7),
      Text('$label  ',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: AppColors.textSecondary)),
      Expanded(
        child: Text(value,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ),
    ]),
  );
}
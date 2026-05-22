import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppointmentService {
  static final _supabase = Supabase.instance.client;

  // ── Patient: request appointment ──────────────────────────────────────────

  static Future<void> requestAppointment({
    required String doctorId,
    required DateTime preferredDate,
    required String preferredTime,
    String? notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    await _supabase.from('appointment_requests').insert({
      'patient_id':     user.id,
      'doctor_id':      doctorId,
      'preferred_date': DateFormat('yyyy-MM-dd').format(preferredDate),
      'preferred_time': preferredTime,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'status':         'pending',
    });
  }

  /// Returns true if the patient already has a pending request with this doctor.
  static Future<bool> hasExistingRequest(String doctorId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final row = await _supabase
        .from('appointment_requests')
        .select('id')
        .eq('patient_id', user.id)
        .eq('doctor_id', doctorId)
        .eq('status', 'pending')
        .maybeSingle();
    return row != null;
  }

  // ── Doctor: get pending requests ──────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final doctor = await _supabase
        .from('doctors')
        .select('id, name, hospital_name')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (doctor == null) return [];

    final rows = await _supabase
        .from('appointment_requests')
        .select(
      'id, preferred_date, preferred_time, notes, created_at, '
          'patient:profiles!appt_fk_patient(id, full_name, email)',
    )
        .eq('doctor_id', doctor['id'] as String)
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  // Convenience: just get count for badge
  static Future<int> getPendingCount() async {
    try {
      final list = await getPendingRequests();
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  // ── Doctor: confirm appointment ───────────────────────────────────────────

  /// Sends confirmation email (via Edge Function with mailto fallback)
  /// then deletes the request.
  static Future<void> confirmAppointment({
    required String requestId,
    required String patientEmail,
    required String patientName,
    required String doctorName,
    required String? hospital,
    required DateTime confirmedDate,
    required String confirmedTime,
  }) async {
    final formattedDate =
    DateFormat('EEEE, d MMMM yyyy').format(confirmedDate);
    final hospitalStr = hospital ?? 'the clinic';
    bool emailSent = false;

    // Try automatic email via Supabase Edge Function (Resend)
    try {
      await _supabase.functions.invoke('send-appointment-email', body: {
        'patientEmail': patientEmail,
        'patientName':  patientName,
        'doctorName':   doctorName,
        'hospital':     hospitalStr,
        'date':         formattedDate,
        'time':         confirmedTime,
      });
      emailSent = true;
    } catch (_) {
      // Edge function not configured — fall through to mailto
    }

    // Fallback: open device email client with pre-filled content
    if (!emailSent) {
      final body = 'Dear $patientName,\n\n'
          'Your appointment with Dr. $doctorName has been confirmed.\n\n'
          'Date: $formattedDate\n'
          'Time: $confirmedTime\n'
          'Location: $hospitalStr\n\n'
          'Please arrive 10 minutes before your scheduled time.\n\n'
          'MediChain Team';
      final uri = Uri(
        scheme: 'mailto',
        path: patientEmail,
        queryParameters: {
          'subject': 'Appointment Confirmed — Dr. $doctorName',
          'body': body,
        },
      );
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }

    // UPDATE to 'confirmed' so patients can see their appointment.
    // (Was DELETE — changed so the row is preserved for patient view.)
    await _supabase.from('appointment_requests').update({
      'status':         'confirmed',
      'confirmed_date': DateFormat('yyyy-MM-dd').format(confirmedDate),
      'confirmed_time': confirmedTime,
    }).eq('id', requestId);
  }

  // ── Doctor: decline request ───────────────────────────────────────────────

  static Future<void> declineAppointment(String requestId) async {
    await _supabase
        .from('appointment_requests')
        .delete()
        .eq('id', requestId);
  }
}
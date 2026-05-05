import 'package:supabase_flutter/supabase_flutter.dart';

import 'records_service.dart';

class SharingService {
  static final _supabase = Supabase.instance.client;

  /// Share the given record IDs with the given doctor.
  /// Idempotent — if a share already exists (active or revoked), it's
  /// reactivated rather than creating a duplicate (the unique constraint
  /// on (record_id, doctor_id) would otherwise fail).
  static Future<int> shareRecords({
    required List<String> recordIds,
    required String doctorId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    if (recordIds.isEmpty) return 0;

    final rows = recordIds
        .map((rid) => {
      'record_id': rid,
      'patient_id': user.id,
      'doctor_id': doctorId,
      // Reset revoked_at in case this share was previously revoked.
      'revoked_at': null,
    })
        .toList();

    // upsert on the unique constraint, so re-sharing is fine.
    await _supabase.from('shared_records').upsert(
      rows,
      onConflict: 'record_id,doctor_id',
    );
    return rows.length;
  }

  /// Revoke a single share. Sets revoked_at instead of deleting so the
  /// patient retains an audit trail of "this was once shared".
  static Future<void> revokeShare({
    required String recordId,
    required String doctorId,
  }) async {
    await _supabase
        .from('shared_records')
        .update({'revoked_at': DateTime.now().toIso8601String()})
        .eq('record_id', recordId)
        .eq('doctor_id', doctorId);
  }

  /// IDs of records the patient has already shared with this doctor.
  /// Used to pre-tick checkboxes on the share screen.
  static Future<Set<String>> sharedRecordIdsFor(String doctorId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};

    final rows = await _supabase
        .from('shared_records')
        .select('record_id')
        .eq('patient_id', user.id)
        .eq('doctor_id', doctorId)
        .filter('revoked_at', 'is', null);

    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['record_id'] as String)
        .toSet();
  }

  /// Records that have been shared *with* the currently-logged-in doctor,
  /// optionally scoped to a single patient. Used by the doctor dashboard.
  static Future<List<SharedRecord>> recordsSharedWithMe({
    String? patientId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // Look up the doctor's id from their profile
    final doctor = await _supabase
        .from('doctors')
        .select('id')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (doctor == null) return [];
    final doctorId = doctor['id'] as String;

    var query = _supabase
        .from('shared_records')
        .select('id, shared_at, patient_id, '
        'record:medical_records!record_id(*)')
        .eq('doctor_id', doctorId)
        .filter('revoked_at', 'is', null);

    if (patientId != null) {
      query = query.eq('patient_id', patientId);
    }

    final rows = await query.order('shared_at', ascending: false);

    return (rows as List)
        .map((r) => SharedRecord.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}

/// Wraps a `shared_records` row joined to the underlying medical_records row.
class SharedRecord {
  final String shareId;
  final DateTime? sharedAt;
  final String patientId;
  final MedicalRecord record;

  SharedRecord({
    required this.shareId,
    required this.sharedAt,
    required this.patientId,
    required this.record,
  });

  factory SharedRecord.fromMap(Map<String, dynamic> m) {
    return SharedRecord(
      shareId: m['id'] as String,
      sharedAt: m['shared_at'] == null
          ? null
          : DateTime.tryParse(m['shared_at'] as String),
      patientId: m['patient_id'] as String,
      record: MedicalRecord.fromMap(m['record'] as Map<String, dynamic>),
    );
  }
}
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contract_service.dart';
import 'records_service.dart';
import 'supabase_service.dart';

class SharingService {
  static final _supabase = Supabase.instance.client;

  /// Share the given record IDs with the given doctor.
  /// Idempotent — if a share already exists (active or revoked), it's
  /// reactivated rather than creating a duplicate (the unique constraint
  /// on (record_id, doctor_id) would otherwise fail).
  ///
  /// [expiresAt] — optional wall-clock cutoff. After this moment the doctor
  /// will no longer see the record (filtered out by [recordsSharedWithMe]).
  /// `null` means no expiry (permanent access until revoked).
  static Future<int> shareRecords({
    required List<String> recordIds,
    required String doctorId,
    DateTime? expiresAt,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    if (recordIds.isEmpty) return 0;

    final expiresAtIso = expiresAt?.toUtc().toIso8601String();

    final rows = recordIds
        .map((rid) => {
      'record_id': rid,
      'patient_id': user.id,
      'doctor_id': doctorId,
      // Reset revoked_at in case this share was previously revoked.
      'revoked_at': null,
      'expires_at': expiresAtIso,
    })
        .toList();

    // upsert on the unique constraint, so re-sharing is fine.
    await _supabase.from('shared_records').upsert(
      rows,
      onConflict: 'record_id,doctor_id',
    );

    // ── Blockchain: grant on-chain access for each record ─────────────────
    // Best-effort — a node outage must never block the patient from sharing.
    _grantBlockchainAccess(
      recordIds: recordIds,
      doctorId: doctorId,
      expiresAt: expiresAt,
    ).catchError((e) {
      debugPrint('[SharingService] blockchain grantAccess failed (non-fatal): $e');
    });

    return rows.length;
  }

  /// Fire-and-forget blockchain grant.  Fetches the doctor's wallet address
  /// once, then calls [ContractService.grantAccess] for each record.
  static Future<void> _grantBlockchainAccess({
    required List<String> recordIds,
    required String doctorId,
    DateTime? expiresAt,
  }) async {
    final doctorWallet =
        await SupabaseService.getDoctorWalletAddress(doctorId);
    if (doctorWallet == null || doctorWallet.isEmpty) {
      debugPrint('[SharingService] doctor has no wallet address — skipping blockchain grant');
      return;
    }

    for (final recordId in recordIds) {
      try {
        // Fetch AES key + IV from Supabase medical_records
        final row = await _supabase
            .from('medical_records')
            .select('encrypted_key, iv')
            .eq('id', recordId)
            .maybeSingle();

        if (row == null) {
          debugPrint('[SharingService] record $recordId not found — skipping');
          continue;
        }

        // Format: "keyBase64|ivBase64"  (MVP — not ECDH-encrypted)
        final encryptedKeyForDoctor =
            '${row['encrypted_key']}|${row['iv']}';

        // Convert expiresAt to Unix seconds; 0 = no expiry on-chain.
        final expiresAtUnix = expiresAt == null
            ? 0
            : (expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000);

        await ContractService.grantAccess(
          doctorAddress:          doctorWallet,
          recordUuid:             recordId,
          encryptedKeyForDoctor:  encryptedKeyForDoctor,
          expiresAt:              expiresAtUnix,
        );
        debugPrint('[SharingService] blockchain grantAccess OK for record $recordId');
      } catch (e) {
        // Contract may revert if access was already granted.  Skip and continue.
        debugPrint('[SharingService] grantAccess for $recordId failed: $e');
      }
    }
  }

  /// Revoke a single share.
  ///
  /// Sets `revoked_at` in Supabase (soft-delete for audit trail), then calls
  /// [ContractService.revokeAccess] on the blockchain so the doctor's
  /// encrypted key is wiped on-chain too.
  static Future<void> revokeShare({
    required String recordId,
    required String doctorId,
  }) async {
    // 1️⃣  Supabase soft-delete
    await _supabase
        .from('shared_records')
        .update({'revoked_at': DateTime.now().toIso8601String()})
        .eq('record_id', recordId)
        .eq('doctor_id', doctorId);

    // 2️⃣  Blockchain revoke — best-effort
    _revokeBlockchainAccess(recordId: recordId, doctorId: doctorId)
        .catchError((e) {
      debugPrint('[SharingService] blockchain revokeAccess failed (non-fatal): $e');
    });
  }

  /// Fire-and-forget blockchain revoke.
  static Future<void> _revokeBlockchainAccess({
    required String recordId,
    required String doctorId,
  }) async {
    final doctorWallet =
        await SupabaseService.getDoctorWalletAddress(doctorId);
    if (doctorWallet == null || doctorWallet.isEmpty) {
      debugPrint('[SharingService] doctor has no wallet — skipping blockchain revoke');
      return;
    }

    await ContractService.revokeAccess(
      doctorAddress: doctorWallet,
      recordUuid:    recordId,
    );
    debugPrint('[SharingService] blockchain revokeAccess OK for record $recordId');
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
        .select('id, shared_at, patient_id, expires_at, '
        'record:medical_records!record_id(*)')
        .eq('doctor_id', doctorId)
        .filter('revoked_at', 'is', null);

    if (patientId != null) {
      query = query.eq('patient_id', patientId);
    }

    final rows = await query.order('shared_at', ascending: false);

    final now = DateTime.now().toUtc();
    return (rows as List)
        .map((r) => SharedRecord.fromMap(r as Map<String, dynamic>))
        // Filter out shares whose expires_at has already passed.
        .where((s) => s.expiresAt == null || s.expiresAt!.isAfter(now))
        .toList();
  }
}

/// Wraps a `shared_records` row joined to the underlying medical_records row.
class SharedRecord {
  final String shareId;
  final DateTime? sharedAt;
  final DateTime? expiresAt;
  final String patientId;
  final MedicalRecord record;

  SharedRecord({
    required this.shareId,
    required this.sharedAt,
    required this.expiresAt,
    required this.patientId,
    required this.record,
  });

  factory SharedRecord.fromMap(Map<String, dynamic> m) {
    return SharedRecord(
      shareId: m['id'] as String,
      sharedAt: m['shared_at'] == null
          ? null
          : DateTime.tryParse(m['shared_at'] as String),
      expiresAt: m['expires_at'] == null
          ? null
          : DateTime.tryParse(m['expires_at'] as String),
      patientId: m['patient_id'] as String,
      record: MedicalRecord.fromMap(m['record'] as Map<String, dynamic>),
    );
  }
}
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web3dart/crypto.dart';

import 'contract_service.dart';
import 'records_service.dart';
import 'supabase_service.dart';
import 'wallet_service.dart';

class SharingService {
  static final _supabase = Supabase.instance.client;

  /// Share records with a doctor — blockchain only.
  static Future<int> shareRecords({
    required List<String> recordIds,
    required String doctorId,
    DateTime? expiresAt,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    if (recordIds.isEmpty) return 0;

    final doctorWallet =
        await SupabaseService.getDoctorWalletAddress(doctorId);
    if (doctorWallet == null || doctorWallet.isEmpty) {
      throw Exception(
          'Doctor has no wallet address. They must sign up and set up their wallet first.');
    }

    final myWallet = await WalletService.getAddress();
    if (myWallet != null &&
        myWallet.toLowerCase() == doctorWallet.toLowerCase()) {
      throw Exception(
          'You and this doctor are using the same wallet address. '
          'Use different wallets for patient and doctor accounts.');
    }

    final expiresAtUnix = expiresAt == null
        ? 0
        : (expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000);

    int shared = 0;
    for (final recordId in recordIds) {
      final row = await _supabase
          .from('medical_records')
          .select('encrypted_key, iv')
          .eq('id', recordId)
          .maybeSingle();

      if (row == null) {
        debugPrint('[SharingService] record $recordId not found — skipping');
        continue;
      }

      final encryptedKeyForDoctor = '${row['encrypted_key']}|${row['iv']}';

      await ContractService.grantAccess(
        doctorAddress: doctorWallet,
        recordUuid: recordId,
        encryptedKeyForDoctor: encryptedKeyForDoctor,
        expiresAt: expiresAtUnix,
      );
      debugPrint('[SharingService] blockchain grantAccess OK for $recordId');
      shared++;
    }

    return shared;
  }

  /// Revoke a doctor's access — blockchain only.
  static Future<void> revokeShare({
    required String recordId,
    required String doctorId,
  }) async {
    final doctorWallet =
        await SupabaseService.getDoctorWalletAddress(doctorId);
    if (doctorWallet == null || doctorWallet.isEmpty) {
      throw Exception('Doctor has no wallet address.');
    }

    await ContractService.revokeAccess(
      doctorAddress: doctorWallet,
      recordUuid: recordId,
    );
    debugPrint('[SharingService] blockchain revokeAccess OK for $recordId');
  }

  /// IDs of records the patient has already shared with this doctor.
  static Future<Set<String>> sharedRecordIdsFor(String doctorId) async {
    final doctorWallet =
        await SupabaseService.getDoctorWalletAddress(doctorId);
    if (doctorWallet == null || doctorWallet.isEmpty) return {};

    final myRecords = await RecordsService.listMyRecords();
    final shared = <String>{};

    for (final record in myRecords) {
      final has = await ContractService.hasAccess(
        doctorAddress: doctorWallet,
        recordUuid: record.id,
      );
      if (has) shared.add(record.id);
    }

    return shared;
  }

  /// Records shared with the currently-logged-in doctor.
  /// Queries blockchain for active records, matches with Supabase metadata.
  static Future<List<SharedRecord>> recordsSharedWithMe({
    String? patientId,
  }) async {
    final walletAddress = await WalletService.getAddress();
    if (walletAddress == null) return [];

    final activeRecordHashes =
        await ContractService.getActiveRecordsForDoctor(walletAddress);
    if (activeRecordHashes.isEmpty) return [];

    // Fetch medical_records from Supabase to match hashes
    List<dynamic> rawRows;
    if (patientId != null) {
      rawRows = await _supabase
          .from('medical_records')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);
    } else {
      rawRows = await _supabase
          .from('medical_records')
          .select()
          .order('created_at', ascending: false);
    }

    // Build hash → record map
    final hashToRecord = <String, MedicalRecord>{};
    for (final row in rawRows) {
      final record = MedicalRecord.fromMap(row as Map<String, dynamic>);
      final hash = bytesToHex(WalletService.recordIdToBytes32(record.id));
      hashToRecord[hash] = record;
    }

    // Match on-chain hashes to records
    final results = <SharedRecord>[];
    for (final recordHash in activeRecordHashes) {
      final hexHash = bytesToHex(recordHash);
      final record = hashToRecord[hexHash];
      if (record == null) continue;
      if (patientId != null && record.patientId != patientId) continue;

      results.add(SharedRecord(
        shareId: record.id,
        sharedAt: null,
        expiresAt: null,
        patientId: record.patientId,
        record: record,
      ));
    }

    return results;
  }
}

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
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'encryption_service.dart';
import 'pinata_service.dart';

/// Where the orchestrator currently is — drives the progress UI.
enum UploadStage {
  reading,
  encrypting,
  hashing,
  uploading,
  savingMetadata,
  done,
  failed,
}

class UploadProgress {
  final UploadStage stage;
  final String message;
  final double progress; // 0.0 .. 1.0

  /// Populated only when [stage] == done.
  final UploadResult? result;

  /// Populated only when [stage] == failed.
  final String? error;

  const UploadProgress({
    required this.stage,
    required this.message,
    required this.progress,
    this.result,
    this.error,
  });
}

class UploadResult {
  final String recordId; // Supabase row id
  final String cid;
  final String sha256;
  final int sizeBytes;
  UploadResult({
    required this.recordId,
    required this.cid,
    required this.sha256,
    required this.sizeBytes,
  });
}

/// End-to-end pipeline: pick → read → encrypt → hash → upload → save metadata.
/// The screen subscribes to the returned Stream to show progress.
class UploadService {
  static final _supabase = Supabase.instance.client;

  /// Drives the whole pipeline. Yields a sequence of [UploadProgress] events.
  ///
  /// On success the final event has stage == done and a populated [result].
  /// On any failure, stage == failed with an [error] message.
  static Stream<UploadProgress> uploadFile({
    required File file,
    required String title,
    required String category,
  }) async* {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        yield const UploadProgress(
          stage: UploadStage.failed,
          message: 'Not signed in',
          progress: 0,
          error: 'You must be signed in to upload.',
        );
        return;
      }

      // 1. Read file bytes
      yield const UploadProgress(
        stage: UploadStage.reading,
        message: 'Reading file…',
        progress: 0.1,
      );
      final bytes = await file.readAsBytes();
      final filename = file.path.split(Platform.pathSeparator).last;

      // 2. Encrypt
      yield const UploadProgress(
        stage: UploadStage.encrypting,
        message: 'Encrypting with AES-256…',
        progress: 0.25,
      );
      // Run encryption — for very large files you'd want compute() to keep
      // the UI thread free. For typical medical PDFs/images this is fine.
      final encrypted = EncryptionService.encryptBytes(bytes);

      // 3. Hash already happened inside encryptBytes; just surface that step.
      yield UploadProgress(
        stage: UploadStage.hashing,
        message: 'Generating SHA-256…',
        progress: 0.4,
      );

      // 4. Upload to Pinata
      yield const UploadProgress(
        stage: UploadStage.uploading,
        message: 'Uploading to IPFS…',
        progress: 0.55,
      );
      final pinResult = await PinataService.uploadBytes(
        bytes: encrypted.ciphertext,
        // We deliberately don't send the original filename to Pinata — the
        // dashboard would show it, and that leaks PII. Use a random-ish ID.
        filename: 'medichain_${DateTime.now().millisecondsSinceEpoch}.bin',
        keyValues: {
          'patient_id': user.id,
          'category': category,
        },
      );

      // 5. Save metadata to Supabase
      yield const UploadProgress(
        stage: UploadStage.savingMetadata,
        message: 'Saving record…',
        progress: 0.85,
      );

      final inserted = await _supabase
          .from('medical_records')
          .insert({
        'patient_id': user.id,
        'title': title,
        'category': category,
        'filename': filename,
        'mime_type': _guessMimeType(filename),
        'file_size_bytes': bytes.length,
        'cid': pinResult.cid,
        'sha256': encrypted.sha256Hex,
        'encrypted_key': encrypted.keyBase64,
        'iv': encrypted.ivBase64,
      })
          .select('id')
          .single();

      final recordId = inserted['id'] as String;

      yield UploadProgress(
        stage: UploadStage.done,
        message: 'Done',
        progress: 1.0,
        result: UploadResult(
          recordId: recordId,
          cid: pinResult.cid,
          sha256: encrypted.sha256Hex,
          sizeBytes: bytes.length,
        ),
      );
    } catch (e) {
      yield UploadProgress(
        stage: UploadStage.failed,
        message: 'Upload failed',
        progress: 0,
        error: e.toString(),
      );
    }
  }

  /// Reverse pipeline — fetch from IPFS, verify hash, decrypt.
  /// Use this when displaying a record.
  static Future<Uint8List> downloadAndDecrypt({
    required String cid,
    required String expectedSha256,
    required String keyBase64,
    required String ivBase64,
  }) async {
    final ciphertext = await PinataService.downloadByCid(cid);

    if (!EncryptionService.verifyHash(ciphertext, expectedSha256)) {
      throw Exception(
        'Integrity check failed: hash mismatch. The file may have been tampered with.',
      );
    }

    return EncryptionService.decryptBytes(
      ciphertext: ciphertext,
      keyBase64: keyBase64,
      ivBase64: ivBase64,
    );
  }

  static String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'application/octet-stream';
  }
}
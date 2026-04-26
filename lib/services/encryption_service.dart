import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// Result of an encryption operation.
class EncryptionResult {
  /// Encrypted bytes — this is what gets uploaded to IPFS.
  final Uint8List ciphertext;

  /// Base64-encoded AES-256 key used to encrypt this specific file.
  /// Store in Supabase so the file can be decrypted later.
  /// In production this should itself be encrypted with a per-user master key.
  final String keyBase64;

  /// Base64-encoded initialization vector (16 bytes for AES-CBC).
  final String ivBase64;

  /// SHA-256 of the *encrypted* bytes — for integrity checks.
  /// Goes on-chain in Cycle 3.
  final String sha256Hex;

  EncryptionResult({
    required this.ciphertext,
    required this.keyBase64,
    required this.ivBase64,
    required this.sha256Hex,
  });
}

class EncryptionService {
  /// Encrypts the given bytes with AES-256-CBC using a fresh random key + IV.
  ///
  /// Each file gets its own key. This means revoking access to one file
  /// doesn't compromise the others.
  static EncryptionResult encryptBytes(Uint8List plaintext) {
    // 32 bytes = 256-bit key
    final key = Key.fromSecureRandom(32);
    // 16 bytes = AES block size
    final iv = IV.fromSecureRandom(16);

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plaintext, iv: iv);

    final ciphertext = Uint8List.fromList(encrypted.bytes);
    final hash = sha256.convert(ciphertext).toString();

    return EncryptionResult(
      ciphertext: ciphertext,
      keyBase64: base64Encode(key.bytes),
      ivBase64: base64Encode(iv.bytes),
      sha256Hex: hash,
    );
  }

  /// Reverses encryption. Used when the patient (or an authorised doctor)
  /// fetches a record from IPFS and needs to view it.
  static Uint8List decryptBytes({
    required Uint8List ciphertext,
    required String keyBase64,
    required String ivBase64,
  }) {
    final key = Key(base64Decode(keyBase64));
    final iv = IV(base64Decode(ivBase64));

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(
      Encrypted(ciphertext),
      iv: iv,
    );
    return Uint8List.fromList(decrypted);
  }

  /// Verify that downloaded ciphertext matches what we uploaded.
  /// Tamper detection — if bytes were modified, the hash won't match.
  static bool verifyHash(Uint8List ciphertext, String expectedSha256Hex) {
    final actual = sha256.convert(ciphertext).toString();
    return actual.toLowerCase() == expectedSha256Hex.toLowerCase();
  }
}

/// Tiny helper used internally — kept here in case you want fresh randomness
/// elsewhere without pulling in encrypt's `Key.fromSecureRandom`.
@Deprecated('Use Key.fromSecureRandom from package:encrypt')
Uint8List _secureRandom(int length) {
  final rand = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => rand.nextInt(256)),
  );
}
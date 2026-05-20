import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

/// Manages the user's local Ethereum wallet.
///
/// The private key is persisted in [FlutterSecureStorage] using Android
/// Keystore-backed EncryptedSharedPreferences — hardware-protected and
/// wiped only on app uninstall (acceptable for MVP).
///
/// Usage:
///   final address = await WalletService.generateWallet();   // on signup
///   final creds   = await WalletService.loadCredentials();  // before signing txs
///   final bytes32 = WalletService.recordIdToBytes32(uuid);  // link UUID → bytes32
class WalletService {
  // ── Storage ───────────────────────────────────────────────────────────────

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _kPrivateKey = 'eth_private_key';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Generate a brand-new secp256k1 Ethereum wallet and persist the private key.
  ///
  /// Returns the **checksummed EIP-55** wallet address (with 0x prefix).
  /// Safe to call multiple times — a later call overwrites the previous key.
  static Future<String> generateWallet() async {
    final credentials = EthPrivateKey.createRandom(Random.secure());
    await _storage.write(
      key: _kPrivateKey,
      value: _toHex(credentials),
    );
    return credentials.address.hexEip55;
  }

  /// Load the stored [EthPrivateKey] from secure storage.
  ///
  /// Returns `null` if no wallet has been created on this device yet.
  static Future<EthPrivateKey?> loadCredentials() async {
    final hex = await _storage.read(key: _kPrivateKey);
    if (hex == null || hex.isEmpty) return null;
    return EthPrivateKey.fromHex(hex);
  }

  /// Get the stored wallet address (checksummed EIP-55, with 0x prefix).
  ///
  /// Returns `null` if no wallet exists yet.
  static Future<String?> getAddress() async {
    final creds = await loadCredentials();
    return creds?.address.hexEip55;
  }

  /// `true` if a wallet private key is already stored on this device.
  static Future<bool> hasWallet() async {
    final hex = await _storage.read(key: _kPrivateKey);
    return hex != null && hex.isNotEmpty;
  }

  /// Convert a Supabase record UUID (String) to a 32-byte [Uint8List] using
  /// `keccak256(utf8.encode(uuid))`.
  ///
  /// This is the exact `bytes32 recordId` value the MediAccessControl contract
  /// stores and looks up.  The same computation runs in Solidity as:
  ///   `keccak256(abi.encodePacked(bytes(supabaseUUID)))`
  static Uint8List recordIdToBytes32(String uuid) {
    return keccak256(Uint8List.fromList(utf8.encode(uuid)));
  }

  // ── Private ───────────────────────────────────────────────────────────────

  /// Serialize private key as a 64-char lowercase hex string (no 0x prefix).
  static String _toHex(EthPrivateKey creds) {
    return bytesToHex(creds.privateKey, include0x: false).padLeft(64, '0');
  }
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import 'supabase_service.dart';

/// Manages per-user Ethereum wallets.
///
/// Private keys are stored locally in secure storage AND synced to
/// Supabase so they persist across devices and login sessions.
class WalletService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String get _storageKey {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return 'eth_private_key';
    return 'eth_private_key_$email';
  }

  static String get _legacyStorageKey {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return 'eth_private_key';
    return 'eth_private_key_$uid';
  }

  /// Generate a brand-new secp256k1 Ethereum wallet and persist the private key.
  static Future<String> generateWallet() async {
    final credentials = EthPrivateKey.createRandom(Random.secure());
    final hex = _toHex(credentials);
    final address = credentials.address.hexEip55;

    await _storage.write(key: _storageKey, value: hex);
    await SupabaseService.saveWalletData(
      walletAddress: address,
      privateKey: hex,
    );

    return address;
  }

  /// Import an existing wallet from a private key hex string.
  /// Returns the derived wallet address.
  static Future<String> importWallet(String privateKeyHex) async {
    final clean = privateKeyHex.trim().replaceFirst('0x', '');
    if (clean.length != 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      throw Exception('Invalid private key. Must be 64 hex characters.');
    }
    final credentials = EthPrivateKey.fromHex(clean);
    final address = credentials.address.hexEip55;

    await _storage.write(key: _storageKey, value: clean);
    await SupabaseService.saveWalletData(
      walletAddress: address,
      privateKey: clean,
    );

    return address;
  }

  /// Load the stored [EthPrivateKey] from secure storage.
  /// Falls back to Supabase if not found locally.
  static Future<EthPrivateKey?> loadCredentials() async {
    // 1. Try current email-based key
    var hex = await _storage.read(key: _storageKey);

    // 2. Try legacy userId-based key
    if (hex == null || hex.isEmpty) {
      hex = await _storage.read(key: _legacyStorageKey);
    }

    // 3. Try bare key from very old versions
    if (hex == null || hex.isEmpty) {
      hex = await _storage.read(key: 'eth_private_key');
    }

    // 4. Fetch from Supabase as last resort
    if (hex == null || hex.isEmpty) {
      try {
        final data = await SupabaseService.getWalletData();
        if (data != null) {
          hex = data['private_key'];
        }
      } catch (e) {
        debugPrint('[WalletService] Failed to fetch from Supabase: $e');
      }
    }

    // Migrate to current key if found from fallback
    if (hex != null && hex.isNotEmpty) {
      await _storage.write(key: _storageKey, value: hex);
      return EthPrivateKey.fromHex(hex);
    }

    return null;
  }

  /// Get the stored wallet address.
  static Future<String?> getAddress() async {
    final creds = await loadCredentials();
    return creds?.address.hexEip55;
  }

  /// `true` if a wallet private key is stored for the current user.
  static Future<bool> hasWallet() async {
    final creds = await loadCredentials();
    return creds != null;
  }

  /// Convert a Supabase record UUID to bytes32 via keccak256.
  static Uint8List recordIdToBytes32(String uuid) {
    return keccak256(Uint8List.fromList(utf8.encode(uuid)));
  }

  static String _toHex(EthPrivateKey creds) {
    return bytesToHex(creds.privateKey, include0x: false).padLeft(64, '0');
  }
}

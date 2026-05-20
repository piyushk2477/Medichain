import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import 'wallet_service.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

/// Maps the Solidity `ActionType` enum (GRANTED=0, REVOKED=1, VIEWED=2, DOWNLOADED=3).
enum OnChainAction { granted, revoked, viewed, downloaded }

/// One entry from the on-chain access log for a medical record.
class AccessLogEntry {
  final String doctorAddress;   // checksummed EIP-55, includes 0x
  final String patientAddress;  // checksummed EIP-55, includes 0x
  final String recordIdHex;     // 0x + 64 hex chars
  final OnChainAction action;
  final DateTime timestamp;
  final int blockNumber;

  const AccessLogEntry({
    required this.doctorAddress,
    required this.patientAddress,
    required this.recordIdHex,
    required this.action,
    required this.timestamp,
    required this.blockNumber,
  });

  /// Human-readable action label.
  String get actionLabel {
    switch (action) {
      case OnChainAction.granted:    return 'Access Granted';
      case OnChainAction.revoked:    return 'Access Revoked';
      case OnChainAction.viewed:     return 'Record Viewed';
      case OnChainAction.downloaded: return 'Record Downloaded';
    }
  }

  @override
  String toString() =>
      'AccessLogEntry(action: $actionLabel, doctor: $doctorAddress, '
      'at: $timestamp, block: $blockNumber)';
}

// ─── ContractService ─────────────────────────────────────────────────────────

/// Interacts with the deployed `MediAccessControl` smart contract.
///
/// Network config (local Hardhat on Android emulator):
///   RPC URL  : http://10.0.2.2:8545  (emulator loopback → host 127.0.0.1)
///   Chain ID : 31337
///   Contract : 0x5FbDB2315678afecb367f032d93F642f64180aa3
///
/// All write methods (grantAccess, revokeAccess, logView, logDownload) sign
/// with the wallet stored in [WalletService].
///
/// All read methods (hasAccess, getAccessLog, …) are free `eth_call` queries.
class ContractService {
  // ── Network / contract config ─────────────────────────────────────────────

  /// RPC URL for the current development network.
  /// Android emulator maps `10.0.2.2` to the host machine's `127.0.0.1`.
  static const String _rpcUrl = 'http://10.0.2.2:8545';

  /// EIP-155 chain ID — 31337 for local Hardhat.
  static const int _chainId = 31337;

  /// Address where MediAccessControl is deployed.
  static const String _contractAddress =
      '0x5FbDB2315678afecb367f032d93F642f64180aa3';

  // ── ABI ───────────────────────────────────────────────────────────────────

  /// Only the functions actually called by this service are listed.
  /// Extracted from blockchain/artifacts/contracts/MediAccessControl.sol/MediAccessControl.json
  static const String _abiJson = r'''[
    {
      "inputs":[
        {"internalType":"address","name":"doctor","type":"address"},
        {"internalType":"bytes32","name":"recordId","type":"bytes32"},
        {"internalType":"string","name":"encryptedKeyForDoctor","type":"string"},
        {"internalType":"uint256","name":"expiresAt","type":"uint256"}
      ],
      "name":"grantAccess","outputs":[],"stateMutability":"nonpayable","type":"function"
    },
    {
      "inputs":[
        {"internalType":"address","name":"doctor","type":"address"},
        {"internalType":"bytes32","name":"recordId","type":"bytes32"}
      ],
      "name":"revokeAccess","outputs":[],"stateMutability":"nonpayable","type":"function"
    },
    {
      "inputs":[{"internalType":"bytes32","name":"recordId","type":"bytes32"}],
      "name":"getEncryptedKey",
      "outputs":[{"internalType":"string","name":"","type":"string"}],
      "stateMutability":"view","type":"function"
    },
    {
      "inputs":[{"internalType":"bytes32","name":"recordId","type":"bytes32"}],
      "name":"logView","outputs":[],"stateMutability":"nonpayable","type":"function"
    },
    {
      "inputs":[{"internalType":"bytes32","name":"recordId","type":"bytes32"}],
      "name":"logDownload","outputs":[],"stateMutability":"nonpayable","type":"function"
    },
    {
      "inputs":[
        {"internalType":"address","name":"doctor","type":"address"},
        {"internalType":"bytes32","name":"recordId","type":"bytes32"}
      ],
      "name":"hasAccess",
      "outputs":[{"internalType":"bool","name":"","type":"bool"}],
      "stateMutability":"view","type":"function"
    },
    {
      "inputs":[{"internalType":"bytes32","name":"recordId","type":"bytes32"}],
      "name":"getAccessLog",
      "outputs":[{
        "components":[
          {"internalType":"address","name":"doctor","type":"address"},
          {"internalType":"address","name":"patient","type":"address"},
          {"internalType":"bytes32","name":"recordId","type":"bytes32"},
          {"internalType":"enum MediAccessControl.ActionType","name":"action","type":"uint8"},
          {"internalType":"uint256","name":"timestamp","type":"uint256"},
          {"internalType":"uint256","name":"blockNumber","type":"uint256"}
        ],
        "internalType":"struct MediAccessControl.AccessLog[]","name":"","type":"tuple[]"
      }],
      "stateMutability":"view","type":"function"
    },
    {
      "inputs":[{"internalType":"bytes32","name":"recordId","type":"bytes32"}],
      "name":"getDoctorsWithAccess",
      "outputs":[{"internalType":"address[]","name":"","type":"address[]"}],
      "stateMutability":"view","type":"function"
    },
    {
      "inputs":[{"internalType":"address","name":"doctor","type":"address"}],
      "name":"getActiveRecordsForDoctor",
      "outputs":[{"internalType":"bytes32[]","name":"","type":"bytes32[]"}],
      "stateMutability":"view","type":"function"
    },
    {
      "inputs":[{"internalType":"bytes32","name":"recordId","type":"bytes32"}],
      "name":"getRecordOwner",
      "outputs":[{"internalType":"address","name":"","type":"address"}],
      "stateMutability":"view","type":"function"
    },
    {
      "inputs":[],"name":"getMySharedRecords",
      "outputs":[{"internalType":"bytes32[]","name":"","type":"bytes32[]"}],
      "stateMutability":"view","type":"function"
    }
  ]''';

  // ── Private factory helpers ────────────────────────────────────────────────

  /// Create a fresh [Web3Client].  Always dispose after use.
  static Web3Client _newClient() => Web3Client(_rpcUrl, http.Client());

  /// Build the [DeployedContract] handle (stateless, cheap to create).
  static DeployedContract get _contract => DeployedContract(
        ContractAbi.fromJson(_abiJson, 'MediAccessControl'),
        EthereumAddress.fromHex(_contractAddress),
      );

  // ── Patient: Grant Access ─────────────────────────────────────────────────

  /// Grant [doctorAddress] access to the record identified by [recordUuid].
  ///
  /// [encryptedKeyForDoctor] — AES key material in the format `"keyBase64|ivBase64"`.
  ///   For this MVP the key is not ECDH-encrypted; blockchain access control
  ///   guards who can retrieve it via [getEncryptedKey].
  ///
  /// [expiresAt] — Unix timestamp (seconds).  Pass 0 for permanent access.
  ///
  /// Returns the **transaction hash** on success.
  /// Throws if no wallet is loaded, or if the contract call reverts.
  static Future<String> grantAccess({
    required String doctorAddress,
    required String recordUuid,
    required String encryptedKeyForDoctor,
    int expiresAt = 0,
  }) async {
    final credentials = await _requireCredentials();
    final recordId    = WalletService.recordIdToBytes32(recordUuid);

    final client = _newClient();
    try {
      final txHash = await client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: _contract,
          function: _contract.function('grantAccess'),
          parameters: [
            EthereumAddress.fromHex(doctorAddress),
            recordId,
            encryptedKeyForDoctor,
            BigInt.from(expiresAt),
          ],
          maxGas: 300000,
        ),
        chainId: _chainId,
      );
      debugPrint('[ContractService] grantAccess tx: $txHash');
      return txHash;
    } finally {
      client.dispose();
    }
  }

  // ── Patient: Revoke Access ────────────────────────────────────────────────

  /// Revoke [doctorAddress]'s access to [recordUuid].
  ///
  /// The contract wipes the stored encrypted key immediately.
  /// Subsequent [getEncryptedKey] calls from that doctor will revert.
  ///
  /// Returns the transaction hash on success.
  static Future<String> revokeAccess({
    required String doctorAddress,
    required String recordUuid,
  }) async {
    final credentials = await _requireCredentials();
    final recordId    = WalletService.recordIdToBytes32(recordUuid);

    final client = _newClient();
    try {
      final txHash = await client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: _contract,
          function: _contract.function('revokeAccess'),
          parameters: [
            EthereumAddress.fromHex(doctorAddress),
            recordId,
          ],
          maxGas: 200000,
        ),
        chainId: _chainId,
      );
      debugPrint('[ContractService] revokeAccess tx: $txHash');
      return txHash;
    } finally {
      client.dispose();
    }
  }

  // ── Doctor: Retrieve Encrypted Key ───────────────────────────────────────

  /// Doctor retrieves the AES key string stored on-chain for [recordUuid].
  ///
  /// The call is sent FROM the doctor's wallet address so the contract's
  /// `hasValidAccess` modifier can verify the caller.
  ///
  /// Returns `"keyBase64|ivBase64"`, or `null` if access is not active /
  /// no wallet is loaded / RPC call fails.
  static Future<String?> getEncryptedKey(String recordUuid) async {
    final credentials = await WalletService.loadCredentials();
    if (credentials == null) return null;

    final recordId = WalletService.recordIdToBytes32(recordUuid);
    final client   = _newClient();
    try {
      final result = await client.call(
        sender:   credentials.address,
        contract: _contract,
        function: _contract.function('getEncryptedKey'),
        params:   [recordId],
      );
      return result.isNotEmpty ? result[0] as String : null;
    } catch (e) {
      debugPrint('[ContractService] getEncryptedKey error: $e');
      return null;
    } finally {
      client.dispose();
    }
  }

  // ── Doctor: Audit-Log Actions ─────────────────────────────────────────────

  /// Doctor logs that they **viewed** a record.
  ///
  /// Best-effort — errors are logged but never rethrown, so the UI
  /// does not break if the node is unreachable.
  static Future<void> logView(String recordUuid) async {
    await _sendLogAction(recordUuid, 'logView');
  }

  /// Doctor logs that they **downloaded** a record.
  static Future<void> logDownload(String recordUuid) async {
    await _sendLogAction(recordUuid, 'logDownload');
  }

  // ── Query Functions ───────────────────────────────────────────────────────

  /// Returns `true` if [doctorAddress] currently has valid (active, non-expired)
  /// access to [recordUuid].
  static Future<bool> hasAccess({
    required String doctorAddress,
    required String recordUuid,
  }) async {
    final recordId = WalletService.recordIdToBytes32(recordUuid);
    final client   = _newClient();
    try {
      final result = await client.call(
        contract: _contract,
        function: _contract.function('hasAccess'),
        params: [
          EthereumAddress.fromHex(doctorAddress),
          recordId,
        ],
      );
      return result.isNotEmpty ? result[0] as bool : false;
    } catch (e) {
      debugPrint('[ContractService] hasAccess error: $e');
      return false;
    } finally {
      client.dispose();
    }
  }

  /// Fetch the full chronological on-chain access log for [recordUuid].
  ///
  /// Contains every GRANT, REVOKE, VIEW, DOWNLOAD event — immutable
  /// and tamper-proof once written.  Returns an empty list on error.
  static Future<List<AccessLogEntry>> getAccessLog(String recordUuid) async {
    final recordId = WalletService.recordIdToBytes32(recordUuid);
    final client   = _newClient();
    try {
      final result = await client.call(
        contract: _contract,
        function: _contract.function('getAccessLog'),
        params:   [recordId],
      );
      if (result.isEmpty) return [];

      final rawList = result[0] as List;
      return rawList.map((raw) {
        final t = raw as List;
        return AccessLogEntry(
          doctorAddress:  (t[0] as EthereumAddress).hexEip55,
          patientAddress: (t[1] as EthereumAddress).hexEip55,
          recordIdHex:    '0x${bytesToHex(t[2] as Uint8List)}',
          action:         OnChainAction.values[(t[3] as BigInt).toInt()],
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (t[4] as BigInt).toInt() * 1000,
          ),
          blockNumber: (t[5] as BigInt).toInt(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[ContractService] getAccessLog error: $e');
      return [];
    } finally {
      client.dispose();
    }
  }

  /// All doctor wallet addresses ever granted access to [recordUuid].
  /// (Includes revoked doctors — use [hasAccess] to filter active ones.)
  static Future<List<String>> getDoctorsWithAccess(String recordUuid) async {
    final recordId = WalletService.recordIdToBytes32(recordUuid);
    final client   = _newClient();
    try {
      final result = await client.call(
        contract: _contract,
        function: _contract.function('getDoctorsWithAccess'),
        params:   [recordId],
      );
      if (result.isEmpty) return [];
      return (result[0] as List)
          .map((a) => (a as EthereumAddress).hexEip55)
          .toList();
    } catch (e) {
      debugPrint('[ContractService] getDoctorsWithAccess error: $e');
      return [];
    } finally {
      client.dispose();
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Load credentials or throw a user-friendly error.
  static Future<EthPrivateKey> _requireCredentials() async {
    final creds = await WalletService.loadCredentials();
    if (creds == null) {
      throw Exception(
        'No Ethereum wallet found on this device. '
        'Please sign out and register again to generate one.',
      );
    }
    return creds;
  }

  /// Send a logView / logDownload transaction.  Errors are swallowed so
  /// audit-log failures never break the main UX flow.
  static Future<void> _sendLogAction(
    String recordUuid,
    String functionName,
  ) async {
    final credentials = await WalletService.loadCredentials();
    if (credentials == null) {
      debugPrint('[ContractService] $functionName skipped — no wallet');
      return;
    }

    final recordId = WalletService.recordIdToBytes32(recordUuid);
    final client   = _newClient();
    try {
      final txHash = await client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract:   _contract,
          function:   _contract.function(functionName),
          parameters: [recordId],
          maxGas:     200000,
        ),
        chainId: _chainId,
      );
      debugPrint('[ContractService] $functionName tx: $txHash');
    } catch (e) {
      debugPrint('[ContractService] $functionName error (non-fatal): $e');
    } finally {
      client.dispose();
    }
  }
}

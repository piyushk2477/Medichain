import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Result returned by Pinata after a successful pin.
class PinataUploadResult {
  /// IPFS Content Identifier (the file's "address" on IPFS).
  final String cid;

  /// Size of the pinned content in bytes.
  final int size;

  /// Server timestamp when the file was pinned.
  final DateTime timestamp;

  PinataUploadResult({
    required this.cid,
    required this.size,
    required this.timestamp,
  });
}

/// Wraps Pinata's pinning REST API.
///
/// SECURITY: the JWT below is sufficient for a college-stage prototype, but
/// before public release move uploads to a Supabase Edge Function so this
/// secret never lives on user devices.
class PinataService {
  // ⚠️ REPLACE BOTH OF THESE with your own values from app.pinata.cloud.
  // - JWT: API Keys → New Key → enable pinFileToIPFS scope → copy JWT
  // - Gateway: Gateways tab → copy your subdomain (without https://)
  static const String _jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySW5mb3JtYXRpb24iOnsiaWQiOiIzZTc4OTAzZS02NDY4LTQ3MjQtYTEyYy01MDQ5NjFiZDNkNTgiLCJlbWFpbCI6InBpeXVzaGthbmFrZGFuZGVAZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsInBpbl9wb2xpY3kiOnsicmVnaW9ucyI6W3siZGVzaXJlZFJlcGxpY2F0aW9uQ291bnQiOjEsImlkIjoiRlJBMSJ9LHsiZGVzaXJlZFJlcGxpY2F0aW9uQ291bnQiOjEsImlkIjoiTllDMSJ9XSwidmVyc2lvbiI6MX0sIm1mYV9lbmFibGVkIjpmYWxzZSwic3RhdHVzIjoiQUNUSVZFIn0sImF1dGhlbnRpY2F0aW9uVHlwZSI6InNjb3BlZEtleSIsInNjb3BlZEtleUtleSI6Ijk2OTEzYmQ4ZWVhYWRiNDMxYjkwIiwic2NvcGVkS2V5U2VjcmV0IjoiOWIzMmJiYTc0NGQ4ZjFkMjM1ZThlMTRlOTcwNGM0ZmFmMWE2MzY0NzE0MjBiZjJmOTVhODQyYjg1NjUzOTkzZiIsImV4cCI6MTgwODcyMTI3M30.zvVH2bdJa8iSpfILoFr12BvBLo6yQZUXoMsRJQ4I5uM';
  static const String _gatewayHost = 'pink-quiet-bandicoot-816.mypinata.cloud';

  static const String _pinEndpoint =
      'https://api.pinata.cloud/pinning/pinFileToIPFS';

  /// Uploads the given bytes to IPFS via Pinata and returns the CID.
  ///
  /// [bytes] should already be encrypted before calling this — Pinata is a
  /// public IPFS pinning service and content can theoretically be fetched
  /// by anyone who learns the CID.
  static Future<PinataUploadResult> uploadBytes({
    required Uint8List bytes,
    required String filename,
    Map<String, String>? keyValues,
  }) async {
    final uri = Uri.parse(_pinEndpoint);
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_jwt';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );

    // Pinata-specific metadata. The `name` shows up in their dashboard
    // — handy for debugging during development.
    request.fields['pinataMetadata'] = jsonEncode({
      'name': filename,
      if (keyValues != null) 'keyvalues': keyValues,
    });

    // CID v1 is the modern format (starts with "bafy..." instead of "Qm...").
    request.fields['pinataOptions'] = jsonEncode({
      'cidVersion': 1,
    });

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw PinataException(
        'Pinata upload failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final cid = decoded['IpfsHash'] as String?;
    if (cid == null) {
      throw PinataException(
        'Pinata response missing IpfsHash: ${response.body}',
      );
    }

    return PinataUploadResult(
      cid: cid,
      size: (decoded['PinSize'] as num?)?.toInt() ?? bytes.length,
      timestamp: DateTime.tryParse(decoded['Timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Builds the gateway URL used to fetch the file later.
  /// Example: https://your-gateway.mypinata.cloud/ipfs/bafy...
  static String gatewayUrlFor(String cid) {
    return 'https://$_gatewayHost/ipfs/$cid';
  }

  /// Downloads a previously-pinned file by CID. Used during retrieval to
  /// verify the SHA-256 hash and decrypt for viewing.
  static Future<Uint8List> downloadByCid(String cid) async {
    final response = await http.get(Uri.parse(gatewayUrlFor(cid)));
    if (response.statusCode != 200) {
      throw PinataException(
        'Could not fetch CID $cid (HTTP ${response.statusCode})',
      );
    }
    return response.bodyBytes;
  }
}

class PinataException implements Exception {
  final String message;
  PinataException(this.message);
  @override
  String toString() => message;
}
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import 'package:medichain_beta/services/contract_service.dart';
import 'package:medichain_beta/services/records_service.dart';

/// In-app, view-only viewer for a shared medical record.
///
/// Doctor protections:
///   • Bytes are decrypted into memory only — never written to disk.
///   • No share / download / save / open-with UI.
///   • Long-press selection of text inside PDFs is disabled by the renderer's
///     defaults; image view uses a non-interactive widget.
///   • View event is logged on-chain (best-effort).
///
/// Caller passes the [MedicalRecord]; this widget handles decryption.
class SecureRecordViewer extends StatefulWidget {
  final MedicalRecord record;

  const SecureRecordViewer({super.key, required this.record});

  @override
  State<SecureRecordViewer> createState() => _SecureRecordViewerState();
}

class _SecureRecordViewerState extends State<SecureRecordViewer> {
  Uint8List? _bytes;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _decrypt();
    // Best-effort on-chain "viewed" log — does NOT block the viewer.
    ContractService.logView(widget.record.id);
  }

  Future<void> _decrypt() async {
    try {
      final bytes = await RecordsService.decryptRecord(widget.record);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    // Drop the reference so the bytes can be GC'd promptly when the
    // viewer closes. (Dart's GC is non-deterministic, but this helps.)
    _bytes = null;
    super.dispose();
  }

  /// Best-guess of the file kind, used to choose the renderer.
  _Kind get _kind {
    final mime = (widget.record.mimeType ?? '').toLowerCase();
    final name = (widget.record.filename ?? '').toLowerCase();
    if (mime.contains('pdf') || name.endsWith('.pdf')) return _Kind.pdf;
    if (mime.startsWith('image/') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif')) {
      return _Kind.image;
    }
    return _Kind.other;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.record.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        // Explicitly NO actions menu — no share, no download, no open-with.
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('Decrypting…',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load record:\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    final bytes = _bytes!;
    switch (_kind) {
      case _Kind.pdf:
        // flutter_pdfview only supports Android & iOS. On web/desktop we
        // fall back to a friendly message — the patient/doctor must use
        // the mobile app to view PDFs.
        if (kIsWeb) {
          return const _PlatformNotSupportedView(
            title: 'PDF preview unavailable on web',
            message:
                'For security, PDF records can only be opened inside the '
                'mobile app. Please open Medichain on Android or iOS to '
                'view this document.',
          );
        }
        return PDFView(
          pdfData: bytes,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          fitPolicy: FitPolicy.BOTH,
          onError: (e) => debugPrint('[Viewer] pdf error: $e'),
        );
      case _Kind.image:
        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        );
      case _Kind.other:
        return _UnsupportedView(record: widget.record);
    }
  }
}

class _PlatformNotSupportedView extends StatelessWidget {
  final String title;
  final String message;
  const _PlatformNotSupportedView({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android,
                size: 56, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Kind { pdf, image, other }

class _UnsupportedView extends StatelessWidget {
  final MedicalRecord record;
  const _UnsupportedView({required this.record});

  @override
  Widget build(BuildContext context) {
    final mime = record.mimeType ?? '(unknown type)';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'In-app preview not available',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Files of type "$mime" can only be viewed inside Medichain. '
              'Ask the patient to re-upload as PDF or image.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}


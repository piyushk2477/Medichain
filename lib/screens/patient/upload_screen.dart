import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:medichain_beta/services/upload_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  static const _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  static const _categories = <_Category>[
    _Category(
      icon: Icons.science_outlined,
      label: 'Lab Report',
      subtitle: 'Blood tests, urine tests, etc.',
      color: Color(0xFF6C63FF),
    ),
    _Category(
      icon: Icons.medication_outlined,
      label: 'Prescription',
      subtitle: 'Doctor prescriptions & medications',
      color: Color(0xFF00BFA6),
    ),
    _Category(
      icon: Icons.monitor_heart_outlined,
      label: 'Scan / Imaging',
      subtitle: 'X-ray, MRI, CT scan, ultrasound',
      color: Color(0xFFFF6B6B),
    ),
    _Category(
      icon: Icons.receipt_long_outlined,
      label: 'Invoice / Bill',
      subtitle: 'Hospital bills & insurance claims',
      color: Color(0xFFFFB347),
    ),
    _Category(
      icon: Icons.description_outlined,
      label: 'Other',
      subtitle: 'Any other medical document',
      color: Color(0xFF7C8DB5),
    ),
  ];

  _Category? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Upload',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add your medical documents securely',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 28),

              // Upload Area
              GestureDetector(
                onTap: _onUploadAreaTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 48, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withAlpha(80),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_rounded,
                          size: 48,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _selectedCategory == null
                            ? 'Select a document type below'
                            : 'Tap to upload a file',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PDF, JPG, PNG up to 10MB · Encrypted before upload',
                        style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Categories
              const Text(
                'Document Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 14),
              for (final c in _categories) ...[
                _CategoryTile(
                  category: c,
                  selected: _selectedCategory == c,
                  onTap: () => setState(() => _selectedCategory = c),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, 1),
    );
  }

  Future<void> _onUploadAreaTap() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a document type first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final pickedFile = picked.files.first;
    final path = pickedFile.path;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected file')),
      );
      return;
    }
    if ((pickedFile.size) > _maxFileSizeBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File is larger than 10MB')),
      );
      return;
    }

    final file = File(path);
    final title = await _askForTitle(defaultText: pickedFile.name);
    if (title == null || title.trim().isEmpty) return;

    if (!mounted) return;
    final result = await showDialog<UploadResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UploadProgressDialog(
        file: file,
        title: title.trim(),
        category: _selectedCategory!.label,
      ),
    );

    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Uploaded and encrypted'),
        backgroundColor: const Color(0xFF00BFA6),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/patient/records'),
        ),
      ),
    );
  }

  Future<String?> _askForTitle({required String defaultText}) async {
    final controller = TextEditingController(text: defaultText);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this record'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Blood test - Apr 2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  static Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.grey[400],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          final routes = [
            '/patient/dashboard',
            '/patient/upload',
            '/patient/records',
            '/patient/profile',
          ];
          Navigator.pushReplacementNamed(context, routes[index]);
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.cloud_upload_rounded), label: 'Upload'),
          BottomNavigationBarItem(
              icon: Icon(Icons.folder_rounded), label: 'Records'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category model + tile
// ---------------------------------------------------------------------------

class _Category {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  const _Category({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
  });
}

class _CategoryTile extends StatelessWidget {
  final _Category category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? category.color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: category.color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(category.icon, color: category.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.subtitle,
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: selected ? category.color : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upload progress dialog — subscribes to UploadService stream
// ---------------------------------------------------------------------------

class _UploadProgressDialog extends StatefulWidget {
  final File file;
  final String title;
  final String category;

  const _UploadProgressDialog({
    required this.file,
    required this.title,
    required this.category,
  });

  @override
  State<_UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<_UploadProgressDialog> {
  StreamSubscription<UploadProgress>? _sub;
  UploadProgress _current = const UploadProgress(
    stage: UploadStage.reading,
    message: 'Starting…',
    progress: 0,
  );

  @override
  void initState() {
    super.initState();
    final stream = UploadService.uploadFile(
      file: widget.file,
      title: widget.title,
      category: widget.category,
    );
    _sub = stream.listen((p) {
      if (!mounted) return;
      setState(() => _current = p);
      if (p.stage == UploadStage.done) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Navigator.of(context).pop(p.result);
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFailed = _current.stage == UploadStage.failed;
    final isDone = _current.stage == UploadStage.done;

    return AlertDialog(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFailed)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: Color(0xFFFF6B6B), size: 32),
            )
          else if (isDone)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA6).withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF00BFA6), size: 36),
            )
          else
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Color(0xFF6C63FF),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            isFailed
                ? 'Upload failed'
                : isDone
                ? 'All set!'
                : _current.message,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (!isFailed && !isDone)
            _StageIndicator(stage: _current.stage)
          else if (isFailed)
            Text(
              _current.error ?? 'Something went wrong',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            )
          else if (isDone && _current.result != null)
              _DoneSummary(result: _current.result!),
          const SizedBox(height: 16),
          if (!isFailed && !isDone)
            LinearProgressIndicator(
              value: _current.progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF6C63FF).withAlpha(30),
              valueColor:
              const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
            ),
        ],
      ),
      actions: [
        if (isFailed || isDone)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(isDone ? _current.result : null),
            child: Text(
              isDone ? 'OK' : 'Close',
              style: const TextStyle(color: Color(0xFF6C63FF)),
            ),
          ),
      ],
    );
  }
}

class _StageIndicator extends StatelessWidget {
  final UploadStage stage;
  const _StageIndicator({required this.stage});

  static const _stages = [
    (UploadStage.reading, Icons.file_open_outlined, 'Read'),
    (UploadStage.encrypting, Icons.lock_outline, 'Encrypt'),
    (UploadStage.hashing, Icons.fingerprint, 'Hash'),
    (UploadStage.uploading, Icons.cloud_upload_outlined, 'IPFS'),
    (UploadStage.savingMetadata, Icons.save_outlined, 'Save'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _stages.indexWhere((s) => s.$1 == stage);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_stages.length, (i) {
        final done = i < currentIdx;
        final active = i == currentIdx;
        final color = done || active
            ? const Color(0xFF6C63FF)
            : Colors.grey[400]!;
        return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done
                    ? const Color(0xFF6C63FF)
                    : active
                    ? const Color(0xFF6C63FF).withAlpha(40)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(
                done ? Icons.check : _stages[i].$2,
                size: 14,
                color: done ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _stages[i].$3,
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        );
      }),
    );
  }
}

class _DoneSummary extends StatelessWidget {
  final UploadResult result;
  const _DoneSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final shortCid = result.cid.length > 20
        ? '${result.cid.substring(0, 10)}…${result.cid.substring(result.cid.length - 6)}'
        : result.cid;
    return Column(
      children: [
        Text(
          'Encrypted, pinned to IPFS, and saved to your records.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'CID: $shortCid',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFF6C63FF),
            ),
          ),
        ),
      ],
    );
  }
}
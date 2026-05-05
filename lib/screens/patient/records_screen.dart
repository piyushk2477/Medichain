import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'package:medichain_beta/services/records_service.dart';

import 'send_records_screen.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  late Future<List<MedicalRecord>> _future;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'All';

  // Map screen labels → category strings used at upload time.
  static const _filterToCategory = <String, String?>{
    'All': null,
    'Lab Reports': 'Lab Report',
    'Prescriptions': 'Prescription',
    'Scans': 'Scan / Imaging',
    'Bills': 'Invoice / Bill',
  };

  @override
  void initState() {
    super.initState();
    _future = RecordsService.listMyRecords();
    _searchCtrl.addListener(() {
      if (_query != _searchCtrl.text) {
        setState(() => _query = _searchCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _future = RecordsService.listMyRecords());
  }

  List<MedicalRecord> _applyFilters(List<MedicalRecord> all) {
    Iterable<MedicalRecord> result = all;
    final cat = _filterToCategory[_filter];
    if (cat != null) {
      result = result.where((r) => r.category == cat);
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      result = result.where((r) =>
      r.title.toLowerCase().contains(q) ||
          (r.filename ?? '').toLowerCase().contains(q) ||
          (r.category ?? '').toLowerCase().contains(q));
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Records',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh,
                            color: Color(0xFF6C63FF)),
                        onPressed: _refresh,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All your medical documents in one place',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 18),
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: Colors.grey[400]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Search records...',
                              hintStyle: TextStyle(
                                  color: Colors.grey[400], fontSize: 15),
                              border: InputBorder.none,
                              contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey[500]),
                            onPressed: () => _searchCtrl.clear(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
            // Filter chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _filterToCategory.keys.map((label) {
                  final selected = label == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = label),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF6C63FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: selected
                            ? null
                            : [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey[600],
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<List<MedicalRecord>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF)),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ErrorView(
                      message: '${snapshot.error}',
                      onRetry: _refresh,
                    );
                  }
                  final all = snapshot.data ?? [];
                  if (all.isEmpty) return _emptyState();
                  final filtered = _applyFilters(all);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No matching records.',
                          style:
                          TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: const Color(0xFF6C63FF),
                    onRefresh: () async => _refresh(),
                    child: ListView.separated(
                      padding:
                      const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                      itemBuilder: (context, i) => _RecordCard(
                        record: filtered[i],
                        onChanged: _refresh,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.send_rounded),
        label: const Text('Send to doctor'),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SendRecordsScreen(),
            ),
          );
          _refresh();
        },
      ),
      bottomNavigationBar: _buildBottomNav(context, 2),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 56,
              color: Colors.grey[350],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No records yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your first medical document\nto see it here',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.grey[400], height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(
                context, '/patient/upload'),
            icon: const Icon(Icons.cloud_upload_rounded, size: 20),
            label: const Text('Upload Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
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
// Record card with tap-to-open and overflow menu
// ---------------------------------------------------------------------------

class _RecordCard extends StatefulWidget {
  final MedicalRecord record;
  final VoidCallback onChanged;
  const _RecordCard({required this.record, required this.onChanged});

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final file = await RecordsService.decryptToTempFile(widget.record);
      if (!mounted) return;
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open: $e')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
            'This removes "${widget.record.title}" from your records. The IPFS pin will remain unless you also remove it from Pinata.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RecordsService.deleteRecord(widget.record.id);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final (IconData icon, Color color) = _iconFor(r.category);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _opening
                    ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF6C63FF)),
                  ),
                )
                    : Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (r.category != null) r.category!,
                        if (r.createdAt != null) _shortDate(r.createdAt!),
                        if (r.sizeBytes != null) _formatSize(r.sizeBytes!),
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[500]),
                onSelected: (v) {
                  switch (v) {
                    case 'open':
                      _open();
                      break;
                    case 'share':
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SendRecordsScreen(
                            preselectedRecordIds: {r.id},
                          ),
                        ),
                      );
                      break;
                    case 'delete':
                      _delete();
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'open',
                    child: ListTile(
                      leading: Icon(Icons.open_in_new),
                      title: Text('Open'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.send),
                      title: Text('Send to doctor'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading:
                      Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
                      title: Text('Delete',
                          style: TextStyle(color: Color(0xFFFF6B6B))),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _iconFor(String? category) {
    switch (category) {
      case 'Lab Report':
        return (Icons.science_outlined, const Color(0xFF6C63FF));
      case 'Prescription':
        return (Icons.medication_outlined, const Color(0xFF00BFA6));
      case 'Scan / Imaging':
        return (Icons.monitor_heart_outlined, const Color(0xFFFF6B6B));
      case 'Invoice / Bill':
        return (Icons.receipt_long_outlined, const Color(0xFFFFB347));
      default:
        return (Icons.description_outlined, const Color(0xFF7C8DB5));
    }
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
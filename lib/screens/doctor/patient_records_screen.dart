import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'package:medichain_beta/services/records_service.dart';
import 'package:medichain_beta/services/sharing_service.dart';

/// Doctor's view of records a specific patient has shared with them.
/// Only shows actively shared (non-revoked) records.
class PatientRecordsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientRecordsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientRecordsScreen> createState() => _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends State<PatientRecordsScreen> {
  late Future<List<SharedRecord>> _future;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _future = SharingService.recordsSharedWithMe(patientId: widget.patientId);
  }

  void _refresh() {
    setState(() {
      _future = SharingService.recordsSharedWithMe(
          patientId: widget.patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: FutureBuilder<List<SharedRecord>>(
            future: _future,
            builder: (context, snap) {
              final cats = <String>{'All'};
              for (final s in snap.data ?? const <SharedRecord>[]) {
                if (s.record.category != null &&
                    s.record.category!.isNotEmpty) {
                  cats.add(s.record.category!);
                }
              }
              return SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: cats
                      .map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _filter == c,
                      onSelected: (_) =>
                          setState(() => _filter = c),
                    ),
                  ))
                      .toList(),
                ),
              );
            },
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<SharedRecord>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('${snapshot.error}',
                      textAlign: TextAlign.center),
                ),
              );
            }
            final all = snapshot.data ?? [];
            final items = _filter == 'All'
                ? all
                : all.where((s) => s.record.category == _filter).toList();

            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.folder_open,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        all.isEmpty
                            ? '${widget.patientName} hasn\'t shared any records with you yet.'
                            : 'No records in "$_filter".',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _SharedRecordCard(item: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SharedRecordCard extends StatefulWidget {
  final SharedRecord item;
  const _SharedRecordCard({required this.item});

  @override
  State<_SharedRecordCard> createState() => _SharedRecordCardState();
}

class _SharedRecordCardState extends State<_SharedRecordCard> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final file =
      await RecordsService.decryptToTempFile(widget.item.record);
      if (!mounted) return;
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: ${result.message}')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.item.record;
    final (IconData icon, Color bg) = _iconFor(r.category);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: _opening
              ? const Padding(
            padding: EdgeInsets.all(10),
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
              : Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          if (r.category != null) r.category!,
          if (widget.item.sharedAt != null)
            'Shared ${_friendlyDate(widget.item.sharedAt!)}',
        ].join(' · ')),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          tooltip: 'Open',
          onPressed: _opening ? null : _open,
        ),
        onTap: _opening ? null : _open,
      ),
    );
  }

  (IconData, Color) _iconFor(String? category) {
    switch (category) {
      case 'Lab Report':
        return (Icons.science_outlined, Colors.indigo.shade100);
      case 'Prescription':
        return (Icons.medication_outlined, Colors.teal.shade100);
      case 'Scan / Imaging':
        return (Icons.monitor_heart_outlined, Colors.red.shade100);
      case 'Invoice / Bill':
        return (Icons.receipt_long_outlined, Colors.amber.shade100);
      default:
        return (Icons.description_outlined, Colors.blueGrey.shade100);
    }
  }

  String _friendlyDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
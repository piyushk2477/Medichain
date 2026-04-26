import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Opens when a doctor taps an accepted patient on the dashboard.
/// Lists the medical records that patient has shared.
///
/// NOTE: this assumes a `medical_records` table with at minimum:
///   id (uuid), patient_id (uuid → profiles.id), title (text),
///   category (text), file_url (text), created_at (timestamptz)
/// If your table is named differently or has different columns, update the
/// query and the [_RecordItem.fromMap] mapping below.
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
  final _supabase = Supabase.instance.client;
  late Future<List<_RecordItem>> _future;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_RecordItem>> _load() async {
    try {
      final rows = await _supabase
          .from('medical_records')
          .select()
          .eq('patient_id', widget.patientId)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((r) => _RecordItem.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If the table doesn't exist yet, fall back to empty rather than crash.
      debugPrint('medical_records query failed: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: FutureBuilder<List<_RecordItem>>(
            future: _future,
            builder: (context, snap) {
              final cats = <String>{'All'};
              for (final r in snap.data ?? const <_RecordItem>[]) {
                if (r.category != null && r.category!.isNotEmpty) {
                  cats.add(r.category!);
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
                      onSelected: (_) => setState(() => _filter = c),
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
        onRefresh: () async {
          setState(() => _future = _load());
          await _future;
        },
        child: FutureBuilder<List<_RecordItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('${snapshot.error}', textAlign: TextAlign.center),
                ),
              );
            }
            final all = snapshot.data ?? [];
            final items = _filter == 'All'
                ? all
                : all.where((r) => r.category == _filter).toList();

            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.folder_open,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      all.isEmpty
                          ? '${widget.patientName} hasn’t shared any records yet.'
                          : 'No records in “$_filter”.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _RecordCard(item: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _RecordItem {
  final String id;
  final String title;
  final String? category;
  final String? fileUrl;
  final DateTime? createdAt;

  _RecordItem({
    required this.id,
    required this.title,
    this.category,
    this.fileUrl,
    this.createdAt,
  });

  factory _RecordItem.fromMap(Map<String, dynamic> m) {
    return _RecordItem(
      id: m['id'] as String,
      title: (m['title'] ?? m['name'] ?? 'Untitled record') as String,
      category: m['category'] as String?,
      fileUrl: (m['file_url'] ?? m['url']) as String?,
      createdAt: m['created_at'] == null
          ? null
          : DateTime.tryParse(m['created_at'] as String),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final _RecordItem item;
  const _RecordCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color bg) = _iconFor(item.category);

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
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          if (item.category != null) item.category!,
          if (item.createdAt != null) _formatDate(item.createdAt!),
        ].join(' · ')),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          tooltip: 'Open',
          onPressed: item.fileUrl == null
              ? null
              : () {
            // Hook this up to url_launcher / your viewer.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Open: ${item.fileUrl}')),
            );
          },
        ),
      ),
    );
  }

  (IconData, Color) _iconFor(String? category) {
    final theme = Colors.teal.shade100;
    switch (category?.toLowerCase()) {
      case 'ecg':
      case 'cardiology':
      case 'ecg / cardiology reports':
        return (Icons.favorite_outline, Colors.red.shade100);
      case 'blood test':
      case 'blood test reports':
        return (Icons.bloodtype_outlined, Colors.pink.shade100);
      case 'ct scan':
        return (Icons.medical_information_outlined, Colors.indigo.shade100);
      case 'x-ray':
        return (Icons.image_outlined, Colors.blueGrey.shade100);
      case 'prescription':
        return (Icons.receipt_long_outlined, Colors.amber.shade100);
      default:
        return (Icons.description_outlined, theme);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
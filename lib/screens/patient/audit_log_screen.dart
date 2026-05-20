import 'package:flutter/material.dart';

import '../../services/contract_service.dart';

/// Displays the immutable on-chain access log for a single medical record.
///
/// Every GRANT, REVOKE, VIEW, and DOWNLOAD event is read from the
/// MediAccessControl smart contract and shown in reverse-chronological order.
///
/// Usage:
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => AuditLogScreen(
///       recordId:    record.id,
///       recordTitle: record.title,
///     ),
///   ));
class AuditLogScreen extends StatefulWidget {
  final String recordId;    // Supabase UUID of the medical_records row
  final String recordTitle; // displayed in the AppBar

  const AuditLogScreen({
    super.key,
    required this.recordId,
    required this.recordTitle,
  });

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late Future<List<AccessLogEntry>> _logFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _logFuture = ContractService.getAccessLog(widget.recordId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Access Log', style: TextStyle(fontSize: 16)),
            Text(
              widget.recordTitle,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<AccessLogEntry>>(
        future: _logFuture,
        builder: (context, snapshot) {
          // ── Loading ───────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Reading on-chain audit log…'),
                ],
              ),
            );
          }

          // ── Error ─────────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load audit log.\n\n'
                      'Make sure the Hardhat node is running:\n'
                      'npx hardhat node',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Empty ──────────────────────────────────────────────────────────
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No on-chain events yet.\n'
                    'Share this record with a doctor to start the audit trail.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // ── Log list (newest first) ────────────────────────────────────────
          final sorted = entries.reversed.toList();

          return Column(
            children: [
              // Info banner
              Container(
                width: double.infinity,
                color: Colors.deepPurple.shade50,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 16, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entries.length} immutable event${entries.length == 1 ? '' : 's'} — stored on blockchain',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: sorted.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _LogEntryCard(entry: sorted[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Log Entry Card ───────────────────────────────────────────────────────────

class _LogEntryCard extends StatelessWidget {
  final AccessLogEntry entry;

  const _LogEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final config = _actionConfig(entry.action);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: config.borderColor, width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: config.bgColor,
          child: Icon(config.icon, color: config.iconColor, size: 20),
        ),
        title: Text(
          entry.actionLabel,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: config.iconColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _AddressRow(label: 'Doctor', address: entry.doctorAddress),
            _AddressRow(label: 'Patient', address: entry.patientAddress),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(entry.timestamp),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              'Block #${entry.blockNumber}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    return '$date  $time';
  }

  _ActionConfig _actionConfig(OnChainAction action) {
    switch (action) {
      case OnChainAction.granted:
        return _ActionConfig(
          icon: Icons.lock_open,
          iconColor: Colors.green.shade700,
          bgColor: Colors.green.shade50,
          borderColor: Colors.green.shade200,
        );
      case OnChainAction.revoked:
        return _ActionConfig(
          icon: Icons.lock,
          iconColor: Colors.red.shade700,
          bgColor: Colors.red.shade50,
          borderColor: Colors.red.shade200,
        );
      case OnChainAction.viewed:
        return _ActionConfig(
          icon: Icons.visibility,
          iconColor: Colors.blue.shade700,
          bgColor: Colors.blue.shade50,
          borderColor: Colors.blue.shade200,
        );
      case OnChainAction.downloaded:
        return _ActionConfig(
          icon: Icons.download,
          iconColor: Colors.orange.shade700,
          bgColor: Colors.orange.shade50,
          borderColor: Colors.orange.shade200,
        );
    }
  }
}

class _AddressRow extends StatelessWidget {
  final String label;
  final String address;

  const _AddressRow({required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    // Show first 10 + … + last 6 chars to fit on screen
    final short = address.length > 20
        ? '${address.substring(0, 10)}…${address.substring(address.length - 6)}'
        : address;

    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Text(
          short,
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _ActionConfig {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  const _ActionConfig({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });
}

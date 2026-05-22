import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:medichain_beta/services/contract_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';

/// Immutable on-chain access log for a single medical record.
/// LOGIC UNCHANGED — ContractService.getAccessLog, AccessLogEntry,
/// OnChainAction, _reload() all preserved exactly.
class AuditLogScreen extends StatefulWidget {
  final String recordId;
  final String recordTitle;

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

  // ── LOGIC PRESERVED EXACTLY ─────────────────────────────────────────────
  void _reload() {
    setState(() {
      _logFuture = ContractService.getAccessLog(widget.recordId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FutureBuilder<List<AccessLogEntry>>(
        future: _logFuture,
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              // ── Blockchain-themed header ──
              SliverToBoxAdapter(
                child: _AuditHeader(
                  recordTitle: widget.recordTitle,
                  entryCount: snapshot.data?.length,
                  onRefresh: _reload,
                ),
              ),

              // ── Loading ──
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _LoadingView(),
                ),
              ]

              // ── Error ──
              else if (snapshot.hasError) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorView(
                    error: '${snapshot.error}',
                    onRetry: _reload,
                  ),
                ),
              ]

              // ── Empty ──
              else if ((snapshot.data ?? []).isEmpty) ...[
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyView(),
                  ),
                ]

                // ── Log list (newest first) ──
                else ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      sliver: SliverList.builder(
                        itemCount: snapshot.data!.reversed.length,
                        itemBuilder: (context, i) {
                          final entries = snapshot.data!.reversed.toList();
                          return StaggeredAppear(
                            index: i,
                            child: _LogEntryCard(
                              entry: entries[i],
                              index: i,
                              total: entries.length,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
            ],
          );
        },
      ),
    );
  }
}

// ─── Blockchain-themed header ──────────────────────────────────────────────

class _AuditHeader extends StatelessWidget {
  final String recordTitle;
  final int? entryCount;
  final VoidCallback onRefresh;
  const _AuditHeader({
    required this.recordTitle,
    required this.entryCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: mediaTop),
      decoration: const BoxDecoration(
        // Slightly more indigo to feel "crypto / blockchain"
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          // Decorative chain-link rings
          Positioned(
            right: -40,
            top: -10,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.white.withOpacity(0.08), width: 22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.white.withOpacity(0.06), width: 14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onRefresh,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.22)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.history_edu_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Access Log',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            recordTitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      const PulseDot(color: Colors.white, size: 8),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entryCount == null
                              ? 'Loading on-chain events…'
                              : '$entryCount immutable event${entryCount == 1 ? '' : 's'} — stored on Polygon',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'TAMPER-PROOF',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Log entry card — LOGIC UNCHANGED ──────────────────────────────────────

class _LogEntryCard extends StatelessWidget {
  final AccessLogEntry entry;
  final int index;
  final int total;

  const _LogEntryCard({
    required this.entry,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _configFor(entry.action);
    final isLast = index == total - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 44,
            child: Column(
              children: [
                if (index > 0)
                  Container(
                    width: 2,
                    height: 12,
                    color: AppColors.border,
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cfg.tint.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: cfg.tint.withOpacity(0.3), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(cfg.icon, color: cfg.tint, size: 17),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
                if (isLast) const SizedBox(height: 12),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cfg.tint.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action type banner
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      decoration: BoxDecoration(
                        color: cfg.tint.withOpacity(0.06),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            cfg.label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: cfg.tint,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cfg.tint.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Block #${entry.blockNumber}',
                              style: GoogleFonts.robotoMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: cfg.tint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Addresses
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Column(
                        children: [
                          _AddressRow(label: 'Doctor', address: entry.doctorAddress),
                          const SizedBox(height: 6),
                          _AddressRow(label: 'Patient', address: entry.patientAddress),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 13, color: AppColors.textTertiary),
                                const SizedBox(width: 6),
                                Text(
                                  _formatTimestamp(entry.timestamp),
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  _ActionCfg _configFor(OnChainAction action) {
    switch (action) {
      case OnChainAction.granted:
        return _ActionCfg(
          icon: Icons.lock_open_rounded,
          tint: AppColors.success,
          label: 'ACCESS GRANTED',
        );
      case OnChainAction.revoked:
        return _ActionCfg(
          icon: Icons.lock_rounded,
          tint: AppColors.accentRed,
          label: 'ACCESS REVOKED',
        );
      case OnChainAction.viewed:
        return _ActionCfg(
          icon: Icons.visibility_rounded,
          tint: AppColors.primary,
          label: 'RECORD VIEWED',
        );
      case OnChainAction.downloaded:
        return _ActionCfg(
          icon: Icons.download_rounded,
          tint: AppColors.warning,
          label: 'RECORD DOWNLOADED',
        );
    }
  }
}

class _ActionCfg {
  final IconData icon;
  final Color tint;
  final String label;
  const _ActionCfg({
    required this.icon,
    required this.tint,
    required this.label,
  });
}

class _AddressRow extends StatelessWidget {
  final String label;
  final String address;
  const _AddressRow({required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    final short = address.length > 20
        ? '${address.substring(0, 10)}…${address.substring(address.length - 6)}'
        : address;

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            '$label:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              short,
              style: GoogleFonts.robotoMono(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Loading / empty / error ───────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Reading on-chain events…',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.history_toggle_off_rounded,
                  size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No on-chain events yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this record with a doctor to start the audit trail.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.error_outline_rounded,
                  size: 38, color: AppColors.accentRed),
            ),
            const SizedBox(height: 20),
            Text(
              'Could not load audit log',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error\n\nMake sure the Hardhat node is running:\nnpx hardhat node',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
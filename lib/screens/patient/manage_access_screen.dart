import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:medichain_beta/services/contract_service.dart';
import 'package:medichain_beta/services/sharing_service.dart';
import 'package:medichain_beta/services/supabase_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/faucet_dialog.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';

/// Shows all doctors who have (or had) access to a specific record.
/// The patient can revoke any active access from here.
class ManageAccessScreen extends StatefulWidget {
  final String recordId;
  final String recordTitle;

  const ManageAccessScreen({
    super.key,
    required this.recordId,
    required this.recordTitle,
  });

  @override
  State<ManageAccessScreen> createState() => _ManageAccessScreenState();
}

class _ManageAccessScreenState extends State<ManageAccessScreen> {
  late Future<List<_DoctorAccess>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _loadDoctorsWithAccess();
    });
  }

  Future<List<_DoctorAccess>> _loadDoctorsWithAccess() async {
    // Get all wallet addresses that were ever granted access
    final wallets =
        await ContractService.getDoctorsWithAccess(widget.recordId);

    final results = <_DoctorAccess>[];
    for (final wallet in wallets) {
      // Check if access is currently active
      final active = await ContractService.hasAccess(
        doctorAddress: wallet,
        recordUuid: widget.recordId,
      );

      // Look up doctor info from Supabase
      final doctorInfo = await SupabaseService.getDoctorByWallet(wallet);

      results.add(_DoctorAccess(
        walletAddress: wallet,
        doctorId: doctorInfo?['id'] as String?,
        name: (doctorInfo?['name'] as String?) ?? 'Unknown Doctor',
        specialization: doctorInfo?['specialization'] as String?,
        isActive: active,
      ));
    }

    // Active first, then revoked
    results.sort((a, b) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      return 0;
    });

    return results;
  }

  Future<void> _revokeAccess(_DoctorAccess doctor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.accentRed, size: 22),
            const SizedBox(width: 10),
            Text('Revoke Access',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Remove Dr. ${doctor.name}\'s access to "${widget.recordTitle}"?\n\n'
          'This action is recorded on the blockchain and cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      if (doctor.doctorId != null) {
        await SharingService.revokeShare(
          recordId: widget.recordId,
          doctorId: doctor.doctorId!,
        );
      } else {
        // Fallback: call contract directly with wallet address
        await ContractService.revokeAccess(
          doctorAddress: doctor.walletAddress,
          recordUuid: widget.recordId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text('Access revoked for Dr. ${doctor.name}'),
          ]),
          backgroundColor: AppColors.success,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      if (isGasError(e)) {
        await showFaucetDialog(context, isError: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke: $e'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FutureBuilder<List<_DoctorAccess>>(
        future: _future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final items = snapshot.data ?? [];
          final activeCount = items.where((d) => d.isActive).length;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Header ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: _ManageHeader(
                    recordTitle: widget.recordTitle,
                    activeCount: loading ? null : activeCount,
                    onRefresh: _reload,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Loading ─────────────────────────────────────
                if (loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 16),
                          Text('Checking blockchain access...',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 14)),
                        ],
                      ),
                    ),
                  )

                // ── Error ───────────────────────────────────────
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: AppColors.accentRed),
                            const SizedBox(height: 16),
                            Text('${snapshot.error}',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _reload,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )

                // ── Empty ───────────────────────────────────────
                else if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
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
                              child: const Icon(Icons.shield_outlined,
                                  size: 38, color: AppColors.primary),
                            ),
                            const SizedBox(height: 18),
                            Text('No one has access',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            Text(
                              'This record has not been shared with any doctor yet.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )

                // ── Doctor list ─────────────────────────────────
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => StaggeredAppear(
                        index: i,
                        child: _DoctorAccessCard(
                          doctor: items[i],
                          onRevoke: items[i].isActive
                              ? () => _revokeAccess(items[i])
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────

class _ManageHeader extends StatelessWidget {
  final String recordTitle;
  final int? activeCount;
  final VoidCallback onRefresh;

  const _ManageHeader({
    required this.recordTitle,
    required this.activeCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: mediaTop),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFFB91C1C)],
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
                      child: const Icon(Icons.admin_panel_settings_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage Access',
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
                    border:
                        Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      const PulseDot(color: Colors.white, size: 8),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          activeCount == null
                              ? 'Checking access permissions...'
                              : '$activeCount active access${activeCount == 1 ? '' : 'es'} — revoke anytime',
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
                          'ON-CHAIN',
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

// ─── Doctor access card ───────────────────────────────────────────────────

class _DoctorAccessCard extends StatefulWidget {
  final _DoctorAccess doctor;
  final VoidCallback? onRevoke;

  const _DoctorAccessCard({
    required this.doctor,
    this.onRevoke,
  });

  @override
  State<_DoctorAccessCard> createState() => _DoctorAccessCardState();
}

class _DoctorAccessCardState extends State<_DoctorAccessCard> {
  bool _revoking = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;
    final active = d.isActive;
    final shortWallet = d.walletAddress.length > 20
        ? '${d.walletAddress.substring(0, 8)}...${d.walletAddress.substring(d.walletAddress.length - 6)}'
        : d.walletAddress;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppColors.border : AppColors.border.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: active
                        ? [const Color(0xFF34D399), const Color(0xFF059669)]
                        : [Colors.grey.shade300, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(d.name),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Dr. ${d.name}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          active
                              ? Icons.lock_open_rounded
                              : Icons.lock_rounded,
                          size: 14,
                          color: active
                              ? AppColors.success
                              : AppColors.textTertiary,
                        ),
                      ],
                    ),
                    if (d.specialization != null &&
                        d.specialization!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        d.specialization!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.textTertiary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  active ? 'Active' : 'Revoked',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.success : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Wallet address row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  shortWallet,
                  style: GoogleFonts.robotoMono(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Revoke button (only for active)
          if (active) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _revoking
                    ? null
                    : () async {
                        setState(() => _revoking = true);
                        try {
                          widget.onRevoke?.call();
                        } finally {
                          if (mounted) setState(() => _revoking = false);
                        }
                      },
                icon: _revoking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentRed,
                        ),
                      )
                    : const Icon(Icons.block_rounded, size: 16),
                label: Text(_revoking ? 'Revoking...' : 'Revoke Access'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentRed,
                  side: const BorderSide(color: AppColors.accentRed),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'DR';
    return parts.map((p) => p[0]).take(2).join().toUpperCase();
  }
}

// ─── Data model ───────────────────────────────────────────────────────────

class _DoctorAccess {
  final String walletAddress;
  final String? doctorId;
  final String name;
  final String? specialization;
  final bool isActive;

  const _DoctorAccess({
    required this.walletAddress,
    this.doctorId,
    required this.name,
    this.specialization,
    required this.isActive,
  });
}

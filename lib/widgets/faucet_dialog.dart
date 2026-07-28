import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:medichain_beta/services/contract_service.dart';
import 'package:medichain_beta/services/wallet_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';

const _hardhatKey0 =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _hardhatKey1 =
    '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d';

Future<void> showFaucetDialog(
  BuildContext context, {
  String? walletAddress,
  bool isError = false,
}) async {
  final address = walletAddress ?? await WalletService.getAddress();
  if (address == null || !context.mounted) return;

  // On a real network (mainnet/testnet) there are no pre-funded Hardhat keys.
  // Never show the "import this test private key" flow to real users — show an
  // honest message instead. The Hardhat faucet is a local-dev-only convenience.
  if (!ContractService.isLocalDevNetwork) {
    await _showNetworkFeeDialog(context);
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            isError
                ? Icons.local_gas_station_rounded
                : Icons.account_balance_wallet_outlined,
            color: isError ? AppColors.accentRed : AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isError ? 'Insufficient Gas' : 'Fund Your Wallet',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isError
                  ? 'This action requires gas. Import a Hardhat test '
                      'account private key (pre-funded with 10 000 ETH) '
                      'and make sure the local blockchain server is running.'
                  : 'Your blockchain wallet was created. For the demo, '
                      'import a Hardhat test account private key below '
                      'to get pre-funded ETH.',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text('Your wallet address',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            _CopiableBox(label: address, ctx: ctx),
            const SizedBox(height: 16),
            Text(
              isError
                  ? 'Steps:\n'
                      '1. Go to Profile → Wallet → Change Wallet\n'
                      '2. Tap "Import Existing Wallet"\n'
                      '3. Paste a Hardhat test key below\n'
                      '4. Retry the action'
                  : 'Steps:\n'
                      '1. Go to Profile → Wallet → Change Wallet\n'
                      '2. Tap "Import Existing Wallet"\n'
                      '3. Paste a Hardhat test key below',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 14),
            const Text('Patient key (Account #0)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            _CopiableBox(label: _hardhatKey0, ctx: ctx),
            const SizedBox(height: 12),
            const Text('Doctor key (Account #1)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            _CopiableBox(label: _hardhatKey1, ctx: ctx),
            const SizedBox(height: 10),
            const Text(
              'Use different keys for patient & doctor accounts.',
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

/// Honest "this action needs a network fee" dialog shown on real networks
/// (Polygon mainnet / testnets) in place of the Hardhat test-key faucet.
/// Remove this once the gasless relayer sponsors user transactions.
Future<void> _showNetworkFeeDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.local_gas_station_rounded,
              color: AppColors.accentRed, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Action Temporarily Unavailable',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: const Text(
        'Recording this on the blockchain requires a small network fee, '
        'and gasless transactions are not enabled yet. Please try again '
        'later. Viewing your records and access history still works normally.',
        style: TextStyle(
            fontSize: 14, color: AppColors.textSecondary, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _CopiableBox extends StatelessWidget {
  final String label;
  final BuildContext ctx;
  const _CopiableBox({required this.label, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: label));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Copied!'),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Icon(Icons.copy_rounded,
                size: 20, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Returns `true` if the error message looks like an insufficient gas/funds error.
bool isGasError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('insufficient funds') ||
      msg.contains('insufficient balance') ||
      msg.contains('gas required exceeds') ||
      msg.contains('out of gas') ||
      msg.contains('sender doesn\'t have enough funds');
}

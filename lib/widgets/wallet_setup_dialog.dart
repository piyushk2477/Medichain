import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:medichain_beta/services/wallet_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';

/// Shows a wallet setup dialog: import existing private key or generate new.
/// Returns the wallet address on success, or `null` if dismissed.
Future<String?> showWalletSetupDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _WalletSetupDialog(),
  );
}

class _WalletSetupDialog extends StatefulWidget {
  const _WalletSetupDialog();

  @override
  State<_WalletSetupDialog> createState() => _WalletSetupDialogState();
}

class _WalletSetupDialogState extends State<_WalletSetupDialog> {
  bool _importing = false;
  bool _loading = false;
  final _keyController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _generateNew() async {
    setState(() => _loading = true);
    try {
      final address = await WalletService.generateWallet();
      if (!mounted) return;
      Navigator.pop(context, address);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _importKey() async {
    // Clean the input: remove whitespace, newlines, quotes
    final key = _keyController.text
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter a private key');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final address = await WalletService.importWallet(key);
      if (!mounted) return;
      Navigator.pop(context, address);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.primary, size: 24),
          SizedBox(width: 10),
          Text('Wallet Setup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
      content: _importing ? _buildImportView() : _buildChoiceView(),
      actions: _importing
          ? [
              TextButton(
                onPressed:
                    _loading ? null : () => setState(() => _importing = false),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: _loading ? null : _importKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Import'),
              ),
            ]
          : null,
    );
  }

  Widget _buildChoiceView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'You need a blockchain wallet to share records '
          'and view audit logs. Choose an option:',
          style: TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        _OptionTile(
          icon: Icons.vpn_key_rounded,
          title: 'Import existing wallet',
          subtitle: 'Paste your private key',
          onTap: _loading ? null : () => setState(() => _importing = true),
        ),
        const SizedBox(height: 12),
        _OptionTile(
          icon: Icons.add_circle_outline_rounded,
          title: 'Generate new wallet',
          subtitle: "You'll need to fund it with test ETH",
          onTap: _loading ? null : _generateNew,
          loading: _loading,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.accentRed)),
        ],
      ],
    );
  }

  Widget _buildImportView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Paste your private key (64 hex characters). '
          'Each account must use a unique wallet.',
          style: TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _keyController,
          maxLines: 2,
          style: const TextStyle(
              fontSize: 13, fontFamily: 'monospace', color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '0x or 64-char hex...',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste_rounded,
                  size: 20, color: AppColors.primary),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  _keyController.text = data!.text!;
                }
              },
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.accentRed)),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

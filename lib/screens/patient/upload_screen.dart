import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medichain_beta/services/upload_service.dart';
import 'package:medichain_beta/theme/app_theme.dart';
import 'package:medichain_beta/widgets/patient_shell.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  static const _maxFileSizeBytes = 10 * 1024 * 1024;

  static const _categories = <_Category>[
    _Category(
      icon: Icons.science_outlined,
      label: 'Lab Report',
      subtitle: 'Blood, urine, pathology tests',
      color: AppColors.primary,
    ),
    _Category(
      icon: Icons.medication_outlined,
      label: 'Prescription',
      subtitle: 'Medications & doctor notes',
      color: Color(0xFF059669),
    ),
    _Category(
      icon: Icons.monitor_heart_outlined,
      label: 'Scan / Imaging',
      subtitle: 'X-ray, MRI, CT, ultrasound',
      color: Color(0xFFEF4444),
    ),
    _Category(
      icon: Icons.receipt_long_outlined,
      label: 'Invoice / Bill',
      subtitle: 'Hospital bills, insurance claims',
      color: AppColors.warning,
    ),
    _Category(
      icon: Icons.description_outlined,
      label: 'Other',
      subtitle: 'Any other medical document',
      color: Color(0xFF8B5CF6),
    ),
  ];

  _Category? _selectedCategory;

  late final AnimationController _entranceCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
    parent: _entranceCtrl,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrandHeader(
              title: 'Upload Record',
              subtitle: 'Encrypted on your device before upload',
              top: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.22)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.cloud_upload_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: const [
                        _MiniChip(
                            icon: Icons.lock_outline_rounded,
                            label: 'AES-256'),
                        _MiniChip(
                            icon: Icons.cloud_outlined, label: 'IPFS'),
                        _MiniChip(
                            icon: Icons.link_rounded, label: 'On-chain'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _FadeSlideIn(
              animation: _stage(0.0, 0.45),
              slide: 22,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _UploadArea(
                  ready: _selectedCategory != null,
                  category: _selectedCategory,
                  pulseCtrl: _pulseCtrl,
                  onTap: _onUploadAreaTap,
                ),
              ),
            ),
            const SizedBox(height: 16),

            _FadeSlideIn(
              animation: _stage(0.15, 0.55),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SecurityFlowCard(),
              ),
            ),
            const SizedBox(height: 26),

            _FadeSlideIn(
              animation: _stage(0.25, 0.65),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  children: [
                    Text(
                      'Document Type',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedCategory != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _selectedCategory!.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 12,
                                color: _selectedCategory!.color),
                            const SizedBox(width: 3),
                            Text(
                              'Selected',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _selectedCategory!.color,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            _FadeSlideIn(
              animation: _stage(0.27, 0.67),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(
                  'Tap to pick what kind of document this is',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            for (var i = 0; i < _categories.length; i++)
              _FadeSlideIn(
                animation: _stage(
                  (0.32 + i * 0.05).clamp(0.0, 0.85),
                  ((0.32 + i * 0.05) + 0.32).clamp(0.0, 1.0),
                ),
                slide: 16,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: _CategoryTile(
                    category: _categories[i],
                    selected: _selectedCategory == _categories[i],
                    onTap: () => setState(
                            () => _selectedCategory = _categories[i]),
                  ),
                ),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
      bottomNavigationBar: const PatientBottomNav(currentIndex: 1),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // LOGIC — preserved exactly
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _onUploadAreaTap() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Choose a document type first',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
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
        content: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Uploaded and encrypted'),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pushReplacementNamed(context, '/patient/records');
  }

  Future<String?> _askForTitle({required String defaultText}) async {
    final controller = TextEditingController(text: defaultText);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                        Icons.drive_file_rename_outline_rounded,
                        color: Colors.white,
                        size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Name this record',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "You'll find it by this name later",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Blood test - Apr 2026',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop(controller.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadArea extends StatefulWidget {
  final bool ready;
  final _Category? category;
  final AnimationController pulseCtrl;
  final VoidCallback onTap;

  const _UploadArea({
    required this.ready,
    required this.category,
    required this.pulseCtrl,
    required this.onTap,
  });

  @override
  State<_UploadArea> createState() => _UploadAreaState();
}

class _UploadAreaState extends State<_UploadArea> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent =
    widget.ready ? widget.category!.color : AppColors.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            color: widget.ready
                ? accent.withOpacity(0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.ready ? accent : AppColors.border,
              width: widget.ready ? 1.6 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(widget.ready ? 0.18 : 0.08),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _PulseRing(
                        ctrl: widget.pulseCtrl, phase: 0, color: accent),
                    _PulseRing(
                        ctrl: widget.pulseCtrl, phase: 0.5, color: accent),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.ready
                              ? [
                            widget.category!.color.withOpacity(0.85),
                            widget.category!.color,
                          ]
                              : const [
                            Color(0xFF3B82F6),
                            AppColors.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.40),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    if (widget.ready)
                      Positioned(
                        right: 22,
                        bottom: 22,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.category!.color
                                    .withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                                color: widget.category!.color
                                    .withOpacity(0.25),
                                width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            widget.category!.icon,
                            color: widget.category!.color,
                            size: 15,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  widget.ready
                      ? 'Tap to choose your file'
                      : 'Select a document type first',
                  key: ValueKey(widget.ready),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.ready
                    ? '${widget.category!.label}  ·  PDF, JPG, PNG up to 10MB'
                    : 'PDF, JPG, PNG up to 10MB',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: widget.ready ? accent : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.ready) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded,
                          color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Pick file',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final AnimationController ctrl;
  final double phase;
  final Color color;

  const _PulseRing({
    required this.ctrl,
    required this.phase,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final t = (ctrl.value + phase) % 1.0;
        final size = 88 + 50 * t;
        final opacity = (1.0 - t) * 0.35;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(opacity),
              width: 1.6,
            ),
          ),
        );
      },
    );
  }
}

class _SecurityFlowCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _FlowStep(
            icon: Icons.insert_drive_file_outlined,
            label: 'Your file',
            color: AppColors.textSecondary,
          ),
          _FlowArrow(),
          _FlowStep(
            icon: Icons.lock_outline_rounded,
            label: 'AES-256',
            color: AppColors.primary,
          ),
          _FlowArrow(),
          _FlowStep(
            icon: Icons.cloud_outlined,
            label: 'IPFS',
            color: const Color(0xFF14B8A6),
          ),
          _FlowArrow(),
          _FlowStep(
            icon: Icons.link_rounded,
            label: 'On-chain',
            color: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FlowStep({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
        size: 18,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _CategoryTile — THE FIX
//
// The red error came from this widget. The inner icon block AnimatedContainer
// switched between BoxDecoration shapes Flutter cannot interpolate:
//   unselected: gradient: null, color: <value>, boxShadow: null
//   selected:   gradient: <value>, color: null,  boxShadow: [<value>]
// BoxDecoration asserts color AND gradient cannot both be non-null; during
// the lerp Flutter momentarily computes both → assertion failure → red screen.
//
// FIX: gradient is ALWAYS present (flat tint when unselected). Shadow is
// ALWAYS a list with opacity 0 when unselected. Same pattern on the radio.
// Nothing switches between null and non-null inside an AnimatedContainer.
// ═══════════════════════════════════════════════════════════════════════════
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

class _CategoryTile extends StatefulWidget {
  final _Category category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final sel = widget.selected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: sel ? c.color : AppColors.border,
              width: sel ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: c.color.withOpacity(sel ? 0.18 : 0.05),
                blurRadius: sel ? 18 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // ─── ICON BLOCK ────────────────────────────────────────────
              // FIX: gradient is ALWAYS set (collapses to flat tint when
              // unselected). boxShadow is ALWAYS a list (opacity 0 when
              // unselected). No null ↔ value flipping inside AnimatedContainer.
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: sel
                        ? [c.color.withOpacity(0.85), c.color]
                        : [
                      c.color.withOpacity(0.10),
                      c.color.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: c.color.withOpacity(sel ? 0.35 : 0.0),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    c.icon,
                    key: ValueKey(sel),
                    color: sel ? Colors.white : c.color,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // ─── RADIO BUTTON ──────────────────────────────────────────
              // FIX: boxShadow is ALWAYS a list (opacity 0 when unselected).
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: sel ? c.color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel ? c.color : AppColors.borderStrong,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.color.withOpacity(sel ? 0.35 : 0.0),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: sel
                      ? const Icon(Icons.check_rounded,
                      key: ValueKey('check'),
                      color: Colors.white,
                      size: 16)
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Upload progress dialog — LOGIC UNCHANGED (also fixed _StageIndicator's
// boxShadow null/list switching to always-present-with-zero-opacity)
// ═══════════════════════════════════════════════════════════════════════════
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
  State<_UploadProgressDialog> createState() =>
      _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<_UploadProgressDialog>
    with TickerProviderStateMixin {
  StreamSubscription<UploadProgress>? _sub;
  UploadProgress _current = const UploadProgress(
    stage: UploadStage.reading,
    message: 'Starting…',
    progress: 0,
  );

  late final AnimationController _orbPulse;

  @override
  void initState() {
    super.initState();
    _orbPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

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
    _orbPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFailed = _current.stage == UploadStage.failed;
    final isDone = _current.stage == UploadStage.done;

    return Dialog(
      backgroundColor: Colors.white,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFailed)
              _StatusOrb(
                  color: AppColors.accentRed, icon: Icons.error_outline)
            else if (isDone)
              _StatusOrb(
                  color: AppColors.success, icon: Icons.check_rounded)
            else
              _UploadingOrb(
                  orbPulse: _orbPulse, progress: _current.progress),
            const SizedBox(height: 22),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                isFailed
                    ? 'Upload failed'
                    : isDone
                    ? 'All set!'
                    : _current.message,
                key: ValueKey('${_current.stage}-$isFailed-$isDone'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 14),

            if (!isFailed && !isDone)
              _StageIndicator(stage: _current.stage)
            else if (isFailed)
              Text(
                _current.error ?? 'Something went wrong',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              )
            else if (isDone && _current.result != null)
                _DoneSummary(result: _current.result!),

            const SizedBox(height: 20),

            if (!isFailed && !isDone)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _current.progress,
                  minHeight: 6,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),

            if (isFailed || isDone) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .pop(isDone ? _current.result : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    isDone ? AppColors.success : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isDone ? 'Done' : 'Close',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UploadingOrb extends StatelessWidget {
  final AnimationController orbPulse;
  final double progress;
  const _UploadingOrb({required this.orbPulse, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: orbPulse,
            builder: (context, _) {
              final t = orbPulse.value;
              final size = 70 + 26 * t;
              final opacity = (1.0 - t) * 0.38;
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(opacity),
                ),
              );
            },
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 4,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              valueColor:
              const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.lock_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

class _StatusOrb extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _StatusOrb({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
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
        final color =
        done || active ? AppColors.primary : AppColors.textTertiary;
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.primary
                    : active
                    ? AppColors.primary.withOpacity(0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
                // FIX: always-present shadow (zero opacity when inactive)
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary
                        .withOpacity(active ? 0.30 : 0.0),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                done ? Icons.check : _stages[i].$2,
                size: 15,
                color: done ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _stages[i].$3,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
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
          'Encrypted, pinned to IPFS, and saved.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border:
            Border.all(color: AppColors.primary.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'CID  ·  $shortCid',
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final double slide;
  const _FadeSlideIn({
    required this.animation,
    required this.child,
    this.slide = 18,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, c) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, slide * (1 - t)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medichain_beta/theme/app_theme.dart';

/// Shared bottom navigation used across every patient screen.
/// Pill-style icons with gradient on the selected item, matching the brand.
class PatientBottomNav extends StatelessWidget {
  final int currentIndex;
  const PatientBottomNav({super.key, required this.currentIndex});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home', '/patient/dashboard'),
    (Icons.cloud_upload_outlined, Icons.cloud_upload_rounded, 'Upload', '/patient/upload'),
    (Icons.folder_outlined, Icons.folder_rounded, 'Records', '/patient/records'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile', '/patient/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: List.generate(_items.length, (i) {
              final selected = i == currentIndex;
              final (outline, filled, label, route) = _items[i];
              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (selected) return;
                    Navigator.pushReplacementNamed(context, route);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          width: 46,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: selected
                                ? const LinearGradient(
                              colors: [Color(0xFF3B82F6), AppColors.primary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            selected ? filled : outline,
                            size: 21,
                            color: selected ? Colors.white : AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? AppColors.textPrimary : AppColors.textTertiary,
                          ),
                          child: Text(label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Reusable branded gradient header. Pass a [title] and optional children.
class BrandHeader extends StatelessWidget {
  final Widget? top;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottomExtra;
  final bool showBack;

  const BrandHeader({
    super.key,
    this.top,
    this.title,
    this.subtitle,
    this.trailing,
    this.bottomExtra,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: mediaTop),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), AppColors.primary, Color(0xFF1D4ED8)],
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
            right: -50,
            top: 10,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (top != null || showBack)
                  Row(
                    children: [
                      if (showBack)
                        _CircleIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      if (top != null) Expanded(child: top!),
                      if (trailing != null) trailing!,
                    ],
                  ),
                if (title != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      title!,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      subtitle!,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                if (bottomExtra != null) ...[
                  const SizedBox(height: 14),
                  bottomExtra!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircleIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}

/// White header icon button (used in the header trailing slot)
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? badge;
  const HeaderIconButton({super.key, required this.icon, this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 19),
            ),
          ),
          if (badge != null) Positioned(right: 8, top: 8, child: badge!),
        ],
      ),
    );
  }
}

/// Staggered fade+slide for list/grid items.
class StaggeredAppear extends StatefulWidget {
  final int index;
  final Widget child;
  final int delayMsPerIndex;
  const StaggeredAppear({
    super.key,
    required this.index,
    required this.child,
    this.delayMsPerIndex = 55,
  });

  @override
  State<StaggeredAppear> createState() => _StaggeredAppearState();
}

class _StaggeredAppearState extends State<StaggeredAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    final ms = (widget.index * widget.delayMsPerIndex).clamp(0, 600);
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
        child: widget.child,
      ),
    );
  }
}

/// Pulsing dot for "live" indicators.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulseDot({super.key, required this.color, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.3 + _c.value * 0.5),
              blurRadius: 4 + _c.value * 6,
            ),
          ],
        ),
      ),
    );
  }
}
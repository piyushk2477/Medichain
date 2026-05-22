import 'package:flutter/material.dart';
import 'package:medichain_beta/theme/app_theme.dart';

/// Medichain plus-cross icon (blue vertical pill + red horizontal pill with a
/// small white dot). When [withTile] is true, the cross sits inside a white
/// rounded-square tile — this is the form used on the splash screen and the
/// login header.
class MedichainLogo extends StatelessWidget {
  final double size;
  final bool withTile;
  final Color tileColor;
  final List<BoxShadow>? shadows;

  const MedichainLogo({
    super.key,
    this.size = 80,
    this.withTile = true,
    this.tileColor = Colors.white,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final cross = _MedichainCross(size: withTile ? size * 0.55 : size);
    if (!withTile) return cross;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: shadows,
      ),
      alignment: Alignment.center,
      child: cross,
    );
  }
}

class _MedichainCross extends StatelessWidget {
  final double size;
  const _MedichainCross({required this.size});

  @override
  Widget build(BuildContext context) {
    final pillThickness = size * 0.36;
    final dotSize = pillThickness * 0.34;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blue vertical pill
          Container(
            width: pillThickness,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(pillThickness),
            ),
          ),
          // Red horizontal pill with white dot
          Container(
            width: size,
            height: pillThickness,
            decoration: BoxDecoration(
              color: AppColors.accentRed,
              borderRadius: BorderRadius.circular(pillThickness),
            ),
            alignment: Alignment.center,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}
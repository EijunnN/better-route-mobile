import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

/// 36×36 rounded icon container used as a leading marker in section
/// blocks (Time window, Contact, Location, Order). Subdued background
/// so it reads as a quiet anchor, not a CTA.
class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color? background;
  final Color? iconColor;

  const IconBubble({
    super.key,
    required this.icon,
    this.background,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background ?? AppColors.bgSurfaceElevated,
        borderRadius: AppRadius.rMd,
      ),
      child: Icon(
        icon,
        size: 16,
        color: iconColor ?? AppColors.fgSecondary,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design/tokens.dart';

/// Floating circular control over the map (back, recenter, my-location).
/// Sits on top of the dark map tiles with an elevated shadow.
class CircleControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const CircleControl({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceElevated,
          borderRadius: AppRadius.rFull,
          border: Border.all(color: AppColors.borderSubtle, width: 1),
          boxShadow: AppShadows.elevated,
        ),
        child: Icon(icon, size: 18, color: AppColors.fgPrimary),
      ),
    );
  }
}

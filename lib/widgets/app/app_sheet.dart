import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

/// Bottom sheet container with the cockpit aesthetic: drag handle,
/// elevated surface, subtle top border, and sheet-shaped corners. Use
/// instead of bare [showModalBottomSheet] children for visual coherence.
class AppSheet extends StatelessWidget {
  final Widget child;
  /// Use blurred backdrop instead of solid scrim.
  final bool blurBackdrop;

  const AppSheet({
    super.key,
    required this.child,
    this.blurBackdrop = false,
  });

  @override
  Widget build(BuildContext context) {
    final sheet = Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: AppRadius.topXl,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        boxShadow: AppShadows.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: AppRadius.rFull,
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );

    if (!blurBackdrop) return sheet;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: sheet,
    );
  }
}

/// Section header inside a sheet — small uppercase label + optional
/// trailing widget (count, action).
class SheetSectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SheetSectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(label.toUpperCase(), style: AppTypography.overline)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design/tokens.dart';

/// Floating top bar for the stop detail screen — back button on the
/// left, customizable trailing action (e.g. copy tracking ID).
class StopDetailTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final Widget trailing;

  const StopDetailTopBar({
    super.key,
    required this.onBack,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          CircleAction(icon: Icons.arrow_back_rounded, onTap: onBack),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

/// 40×40 circular icon button. Used in the stop detail top bar and as
/// a public widget so the screen can compose the trailing action with
/// the same chrome.
class CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const CircleAction({
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: AppRadius.rFull,
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Icon(icon, size: 16, color: AppColors.fgPrimary),
      ),
    );
  }
}

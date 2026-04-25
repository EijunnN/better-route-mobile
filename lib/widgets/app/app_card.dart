import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design/tokens.dart';

/// Surface container with optional press animation. Replaces shadcn's
/// [Card] for content blocks. Two levels of elevation — the [elevated]
/// variant lifts the card via background color, NOT shadow.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  final bool border;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.elevated = false,
    this.border = true,
    this.onTap,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.elevated
        ? AppColors.bgSurfaceElevated
        : AppColors.bgSurface;
    final hoverBg = widget.elevated
        ? AppColors.bgSurfaceHover
        : AppColors.bgSurfaceElevated;
    final isInteractive = widget.onTap != null;

    return GestureDetector(
      onTapDown: isInteractive ? (_) => setState(() => _pressed = true) : null,
      onTapUp: isInteractive ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: isInteractive ? () => setState(() => _pressed = false) : null,
      onTap: isInteractive
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standardCurve,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _pressed ? hoverBg : bg,
          borderRadius: AppRadius.rLg,
          border: widget.border
              ? Border.all(color: AppColors.borderSubtle, width: 1)
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

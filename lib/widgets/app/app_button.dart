import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design/tokens.dart';

/// Driver Cockpit button.
///
/// Four variants × three sizes. Variants describe semantic intent, sizes
/// describe physical importance — a primary button can be small (in a
/// row) or huge (a primary CTA at the bottom of a sheet). Variant and
/// size are independent.
///
/// Every press fires haptic feedback by default. The driver context
/// (gloves, vibration, ambient noise) makes haptic confirmation more
/// reliable than visual.
enum AppButtonVariant {
  /// White fill — for the single most important action on a screen.
  primary,

  /// Outlined surface — secondary actions, "secondary because there's a
  /// primary nearby", not because it's less important globally.
  secondary,

  /// Borderless — tertiary actions, in-row inline buttons.
  ghost,

  /// Live/positive accent (jade fill) — for confirming forward motion
  /// (Start, Confirm Delivery). Reserved.
  live,

  /// Destructive (red fill) — for irreversible negative actions
  /// (Cancel, Mark as failed).
  destructive,
}

enum AppButtonSize {
  /// 32px — used inside lists, in dense contexts.
  sm,

  /// 44px — default form submit / row action.
  md,

  /// 56px — primary CTA in sheets and main screens.
  lg,

  /// 64px — full-width hero action when the screen has ONE next step.
  xl,
}

class AppButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool fullWidth;
  final bool haptic;
  final VoidCallback? onPressed;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
    this.haptic = true,
    this.onPressed,
  });

  /// Convenience: full-width primary CTA at xl size — the most common
  /// "main action of the screen" pattern.
  factory AppButton.primaryCta({
    required String label,
    IconData? icon,
    bool isLoading = false,
    VoidCallback? onPressed,
  }) {
    return AppButton(
      label: label,
      icon: icon,
      variant: AppButtonVariant.primary,
      size: AppButtonSize.xl,
      isLoading: isLoading,
      fullWidth: true,
      onPressed: onPressed,
    );
  }

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    if (!_enabled) return;
    setState(() => _pressed = true);
    _scaleController.animateTo(0.97, duration: AppMotion.fast, curve: AppMotion.standardCurve);
  }

  void _onTapUp(_) {
    setState(() => _pressed = false);
    _scaleController.animateTo(1.0, duration: AppMotion.fast, curve: AppMotion.standardCurve);
  }

  void _onTapCancel() {
    setState(() => _pressed = false);
    _scaleController.animateTo(1.0, duration: AppMotion.fast, curve: AppMotion.standardCurve);
  }

  void _handleTap() {
    if (!_enabled) return;
    if (widget.haptic) {
      HapticFeedback.lightImpact();
    }
    widget.onPressed?.call();
  }

  ({Color bg, Color fg, Color? border}) get _colors {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return (
          bg: AppColors.accentPrimary,
          fg: AppColors.fgInverse,
          border: null,
        );
      case AppButtonVariant.secondary:
        return (
          bg: _pressed ? AppColors.bgSurfaceHover : AppColors.bgSurfaceElevated,
          fg: AppColors.fgPrimary,
          border: AppColors.borderSubtle,
        );
      case AppButtonVariant.ghost:
        return (
          bg: _pressed
              ? AppColors.bgSurfaceHover
              : AppColors.bgBase.withValues(alpha: 0),
          fg: AppColors.fgPrimary,
          border: null,
        );
      case AppButtonVariant.live:
        return (
          bg: AppColors.accentLive,
          fg: AppColors.fgInverse,
          border: null,
        );
      case AppButtonVariant.destructive:
        return (
          bg: AppColors.accentDanger,
          fg: AppColors.fgPrimary,
          border: null,
        );
    }
  }

  ({double height, double padX, double iconSize, TextStyle text}) get _sizing {
    switch (widget.size) {
      case AppButtonSize.sm:
        return (
          height: 32,
          padX: 12,
          iconSize: 14,
          text: AppTypography.label,
        );
      case AppButtonSize.md:
        return (
          height: 44,
          padX: 16,
          iconSize: 16,
          text: AppTypography.button,
        );
      case AppButtonSize.lg:
        return (
          height: 56,
          padX: 24,
          iconSize: 18,
          text: AppTypography.buttonLarge,
        );
      case AppButtonSize.xl:
        return (
          height: 64,
          padX: 28,
          iconSize: 20,
          text: AppTypography.buttonLarge.copyWith(fontSize: 18),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final s = _sizing;
    final fg = _enabled ? c.fg : AppColors.fgDisabled;
    final bg = _enabled ? c.bg : AppColors.bgSurface;

    return ScaleTransition(
      scale: _scaleController,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: s.height,
          width: widget.fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: s.padX),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.rMd,
            border: c.border != null
                ? Border.all(color: c.border!, width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: s.iconSize,
                  height: s.iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(fg),
                  ),
                )
              else if (widget.icon != null) ...[
                Icon(widget.icon, size: s.iconSize, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: s.text.copyWith(color: fg),
                textAlign: TextAlign.center,
              ),
              if (widget.trailingIcon != null && !widget.isLoading) ...[
                const SizedBox(width: 8),
                Icon(widget.trailingIcon, size: s.iconSize, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

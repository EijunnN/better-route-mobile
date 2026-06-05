import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design/tokens.dart';

/// Floating top bar that sits *over* the map peek. Three pieces, all
/// glassmorphic (semi-opaque + backdrop blur):
///
///   [avatar pill]  [driver status pill (flex)]  [chat icon button]
///
/// Spec: `Mobile - Specs.html` § 07 / 03 · Home (mirrors `D2Home`'s
/// floating chrome). The avatar shows the driver's initials, the
/// status pill says "Nombre · En turno" with a pulsing lime dot, and
/// the chat icon opens the dispatch thread.
class GlassTopBar extends StatefulWidget {
  final String driverName;
  final VoidCallback onChatTap;
  final VoidCallback onAvatarTap;

  const GlassTopBar({
    super.key,
    required this.driverName,
    required this.onChatTap,
    required this.onAvatarTap,
  });

  @override
  State<GlassTopBar> createState() => _GlassTopBarState();
}

class _GlassTopBarState extends State<GlassTopBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.driverName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '··';
    final first = parts.first[0].toUpperCase();
    final second =
        parts.length > 1 && parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
    return '$first$second';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          // Avatar pill.
          _GlassPill(
            onTap: widget.onAvatarTap,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: Text(
                  _initials,
                  style: AppTypography.label.copyWith(
                    color: AppColors.fgPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Driver status pill — flex.
          Expanded(
            child: _GlassPill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        final t = _pulse.value;
                        return SizedBox(
                          width: 14,
                          height: 14,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 6 + 8 * t,
                                height: 6 + 8 * t,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.lime.withValues(
                                    alpha: (0.55 * (1 - t)).clamp(0.0, 1.0),
                                  ),
                                ),
                              ),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.lime,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${widget.driverName} · En turno',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.fgPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Chat icon — 38x38 glass button.
          _GlassPill(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onChatTap();
            },
            child: const SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: AppColors.fgPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable glass surface used by every chip / button in the top bar.
class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _GlassPill({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pill = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: pill,
      ),
    );
  }
}

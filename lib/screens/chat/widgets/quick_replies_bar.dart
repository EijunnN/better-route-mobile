import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/tokens.dart';
import '../../../models/chat_message.dart';

/// Tappable chip row above the composer. The driver shouldn't be typing
/// while moving; chips cover the common cases. Only renders when the
/// composer's input is empty (passed via `visible`), so once the driver
/// starts typing they aren't competing with chips for thumb attention.
class QuickRepliesBar extends StatelessWidget {
  final bool visible;
  final bool isSending;
  final ValueChanged<ChatQuickReply> onPick;

  const QuickRepliesBar({
    super.key,
    required this.visible,
    required this.isSending,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 140),
        child: visible
            ? Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageX,
                  AppSpacing.space2,
                  AppSpacing.pageX,
                  AppSpacing.space2,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final reply in chatQuickReplies) ...[
                        _Chip(
                          label: reply.label,
                          enabled: !isSending,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onPick(reply);
                          },
                        ),
                        const SizedBox(width: AppSpacing.space2),
                      ],
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: AppColors.bgSurfaceElevated,
        borderRadius: AppRadius.rFull,
        child: InkWell(
          borderRadius: AppRadius.rFull,
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space3,
              vertical: AppSpacing.space2 + 2,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: AppRadius.rFull,
            ),
            child: Text(
              label,
              style: AppTypography.label.copyWith(color: AppColors.fgPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

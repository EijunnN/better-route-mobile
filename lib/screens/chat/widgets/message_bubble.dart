import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../models/chat_message.dart';

/// One message in the thread. Outbound (driver → dispatch) hugs the
/// right edge with the live jade tint; inbound (dispatch → driver)
/// hugs the left with the elevated-surface neutral. Broadcasts get a
/// distinct amber accent — they're "emergency-band" announcements.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final inbound = message.isInbound;
    final broadcast = message.isBroadcast;

    final bg = broadcast
        ? AppColors.accentWarningDim.withValues(alpha: 0.4)
        : inbound
            ? AppColors.bgSurfaceElevated
            : AppColors.accentLiveSoft;
    final border = broadcast
        ? AppColors.accentWarning.withValues(alpha: 0.45)
        : inbound
            ? AppColors.borderSubtle
            : AppColors.accentLive.withValues(alpha: 0.3);

    return Align(
      alignment: inbound ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageX,
            vertical: AppSpacing.space1,
          ),
          child: Column(
            crossAxisAlignment:
                inbound ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3,
                  vertical: AppSpacing.space2 + 2,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.md),
                    topRight: const Radius.circular(AppRadius.md),
                    bottomLeft: Radius.circular(inbound ? AppRadius.xs : AppRadius.md),
                    bottomRight: Radius.circular(inbound ? AppRadius.md : AppRadius.xs),
                  ),
                ),
                child: Text(
                  message.body,
                  style: AppTypography.body,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (broadcast) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.accentWarning.withValues(alpha: 0.5),
                          ),
                          borderRadius: AppRadius.rXs,
                        ),
                        child: Text(
                          'DIFUSIÓN',
                          style: AppTypography.monoSmall.copyWith(
                            color: AppColors.accentWarning,
                            fontSize: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (message.isTemplate && !broadcast) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderSubtle),
                          borderRadius: AppRadius.rXs,
                        ),
                        child: Text(
                          'RÁPIDA',
                          style: AppTypography.monoSmall.copyWith(
                            fontSize: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _formatTime(message.createdAt),
                      style: AppTypography.monoSmall,
                    ),
                    // Read receipt en los mensajes propios del driver:
                    // ✓ enviado, ✓✓ lima cuando el despachador lo leyó.
                    if (!inbound) ...[
                      const SizedBox(width: 4),
                      Text(
                        message.readAt != null ? '✓✓' : '✓',
                        style: AppTypography.monoSmall.copyWith(
                          color: message.readAt != null
                              ? AppColors.accentLive
                              : AppColors.fgSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

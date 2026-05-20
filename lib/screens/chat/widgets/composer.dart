import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/tokens.dart';

/// Bottom composer. Sized so a thumb can hit Enviar from any natural
/// hand position; min height matches the platform comfortable target.
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onSend,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgBase,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageX,
        AppSpacing.space2,
        AppSpacing.space3,
        AppSpacing.space3,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, maxHeight: 140),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: AppRadius.rXl,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  enabled: !isSending,
                  maxLines: null,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.body,
                  cursorColor: AppColors.accentLive,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Escribe un mensaje…',
                    hintStyle:
                        AppTypography.body.copyWith(color: AppColors.fgTertiary),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.space3 - 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            _SendButton(
              enabled: !isSending && controller.text.trim().isNotEmpty,
              loading: isSending,
              onTap: () {
                HapticFeedback.lightImpact();
                onSend();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: AppColors.accentLive,
        borderRadius: AppRadius.rFull,
        child: InkWell(
          borderRadius: AppRadius.rFull,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.fgInverse,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: AppColors.fgInverse,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

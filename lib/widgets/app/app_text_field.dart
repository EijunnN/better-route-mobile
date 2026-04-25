import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design/tokens.dart';

/// Text input matching the cockpit aesthetic. Uses Flutter's native
/// [TextField] under the hood for keyboard correctness, but takes over
/// the chrome.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? placeholder;
  final IconData? leadingIcon;
  final Widget? trailing;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final String? errorText;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.leadingIcon,
    this.trailing,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.errorText,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focus;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = _focus.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? AppColors.accentDanger
        : _focused
            ? AppColors.borderFocus
            : AppColors.borderSubtle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppTypography.label),
          const SizedBox(height: 6),
        ],
        AnimatedContainer(
          duration: AppMotion.fast,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: AppRadius.rMd,
            border: Border.all(color: borderColor, width: _focused ? 1.5 : 1),
          ),
          child: Row(
            children: [
              if (widget.leadingIcon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Icon(
                    widget.leadingIcon,
                    size: 16,
                    color: _focused
                        ? AppColors.fgPrimary
                        : AppColors.fgTertiary,
                  ),
                ),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    widget.leadingIcon != null ? 10 : 14,
                    14,
                    14,
                    14,
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    obscureText: widget.obscure,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    inputFormatters: widget.inputFormatters,
                    maxLines: widget.maxLines,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled,
                    style: AppTypography.body,
                    cursorColor: AppColors.fgPrimary,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: widget.placeholder,
                      hintStyle: AppTypography.body.copyWith(
                        color: AppColors.fgTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: widget.trailing!,
                ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: AppTypography.bodySmall.copyWith(color: AppColors.accentDanger),
          ),
        ],
      ],
    );
  }
}

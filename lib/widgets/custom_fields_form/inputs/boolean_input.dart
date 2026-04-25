import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

/// Switch + label for boolean custom fields.
class BooleanInput extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const BooleanInput({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch(value: value, onChanged: onChanged),
        const SizedBox(width: 10),
        Text(
          value ? 'Sí' : 'No',
          style: AppTypography.body.copyWith(color: AppColors.fgPrimary),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

/// Square "+" button that opens the camera picker. Pairs with
/// [PhotoThumb] inside evidence galleries.
class AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const AddPhotoButton({
    super.key,
    required this.onTap,
    this.size = 88,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Icon(
          Icons.add_a_photo_rounded,
          size: 18,
          color: AppColors.fgSecondary,
        ),
      ),
    );
  }
}

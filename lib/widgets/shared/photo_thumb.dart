import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

/// Square photo thumbnail with a delete chip in the corner.
/// Used by every sheet that captures evidence (delivery, failure,
/// workflow transitions). Extracted so the look stays consistent
/// when one of them changes.
class PhotoThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  final double size;

  const PhotoThumb({
    super.key,
    required this.file,
    required this.onRemove,
    this.size = 88,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: AppRadius.rMd,
            child: Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.accentDanger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

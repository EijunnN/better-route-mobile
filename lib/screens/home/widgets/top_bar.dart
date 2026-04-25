import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design/tokens.dart';

/// Home top bar — avatar with initials + driver name + logout button.
/// Compact on purpose so the KPI strip below gets the visual weight.
class HomeTopBar extends StatelessWidget {
  final String driverName;
  final VoidCallback onLogout;

  const HomeTopBar({
    super.key,
    required this.driverName,
    required this.onLogout,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceElevated,
              borderRadius: AppRadius.rFull,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(driverName),
              style: AppTypography.label.copyWith(color: AppColors.fgPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hoy', style: AppTypography.overline),
                const SizedBox(height: 2),
                Text(
                  driverName,
                  style: AppTypography.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onLogout();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: AppRadius.rFull,
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 16,
                color: AppColors.fgSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

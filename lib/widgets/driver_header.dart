import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';

class DriverHeader extends StatelessWidget {
  final DriverInfo? driver;
  final Vehicle? vehicle;
  final VoidCallback onLogout;

  const DriverHeader({
    super.key,
    this.driver,
    this.vehicle,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // Avatar - 36px circle with primary bg
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: driver?.photo != null
                ? ClipOval(
                    child: Image.network(
                      driver!.photo!,
                      fit: BoxFit.cover,
                      width: 36,
                      height: 36,
                      errorBuilder: (_, __, ___) => _buildInitials(),
                    ),
                  )
                : _buildInitials(),
          ),

          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    driver?.name ?? 'Conductor',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Vehicle plate chip
                if (vehicle != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vehicle!.displayName,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Logout button
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'Cerrar sesion',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        driver?.initials ?? '?',
        style: const TextStyle(
          color: AppColors.textOnPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

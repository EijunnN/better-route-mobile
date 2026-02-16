import 'package:shadcn_flutter/shadcn_flutter.dart';
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.border),
        ),
      ),
      child: Row(
        children: [
          // Avatar - 36px circle with primary bg
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: driver?.photo != null
                ? ClipOval(
                    child: Image.network(
                      driver!.photo!,
                      fit: BoxFit.cover,
                      width: 36,
                      height: 36,
                      errorBuilder: (_, __, ___) => _buildInitials(theme),
                    ),
                  )
                : _buildInitials(theme),
          ),

          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    driver?.name ?? 'Conductor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ).semiBold(),
                ),

                // Vehicle plate badge
                if (vehicle != null) ...[
                  const SizedBox(width: 8),
                  OutlineBadge(
                    child: Text(vehicle!.displayName).xSmall(),
                  ),
                ],
              ],
            ),
          ),

          // Logout button
          GhostButton(
            size: ButtonSize.small,
            density: ButtonDensity.compact,
            onPressed: onLogout,
            child: Icon(
              Icons.logout_rounded,
              size: 20,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(ThemeData theme) {
    return Center(
      child: Text(
        driver?.initials ?? '?',
        style: TextStyle(
          color: theme.colorScheme.primaryForeground,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

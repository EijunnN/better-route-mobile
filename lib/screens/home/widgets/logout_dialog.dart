import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../widgets/app/app.dart';

/// Confirmation dialog for logout. Shown with [AppColors.bgOverlay]
/// scrim. Returns `true` from `Navigator.pop` when the user confirms,
/// `false` (or null) otherwise.
class HomeLogoutDialog extends StatelessWidget {
  const HomeLogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Cerrar sesión?', style: AppTypography.h3),
            const SizedBox(height: 8),
            Text(
              'Vas a dejar de recibir actualizaciones de la ruta y se va a detener el envío de ubicación.',
              style: AppTypography.body
                  .copyWith(color: AppColors.fgSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancelar',
                    variant: AppButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Cerrar sesión',
                    variant: AppButtonVariant.destructive,
                    fullWidth: true,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

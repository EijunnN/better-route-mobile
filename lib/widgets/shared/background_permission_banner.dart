import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';
import '../../services/location_service.dart';

/// Inline warning shown on the home screen when the OS didn't grant
/// background location. Without "always-on" location, the foreground
/// service can keep emitting only while the screen is on — the moment
/// the driver locks the phone or switches apps, monitoring loses
/// signal. Surfacing this explicitly is more honest than letting the
/// driver discover it after a missed delivery.
///
/// The banner adapts its copy and CTA to the underlying status:
/// `serviceDisabled` → reopen Location Services, `deniedForever` →
/// open app settings, `denied` / `foregroundOnly` → re-prompt.
class BackgroundPermissionBanner extends StatelessWidget {
  final LocationPermissionStatus status;
  final VoidCallback onAction;

  const BackgroundPermissionBanner({
    super.key,
    required this.status,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (status == LocationPermissionStatus.background) {
      return const SizedBox.shrink();
    }

    final copy = _copyFor(status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accentWarningDim.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentWarningDim),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppColors.accentWarning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.title,
                        style: AppTypography.label.copyWith(
                          color: AppColors.fgPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        copy.subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.fgSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  copy.cta,
                  style: AppTypography.label.copyWith(
                    color: AppColors.accentWarning,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.accentWarning,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _Copy _copyFor(LocationPermissionStatus s) {
    switch (s) {
      case LocationPermissionStatus.serviceDisabled:
        return const _Copy(
          title: 'GPS apagado',
          subtitle: 'Activá la ubicación del dispositivo para iniciar la ruta.',
          cta: 'Activar',
        );
      case LocationPermissionStatus.deniedForever:
        return const _Copy(
          title: 'Permiso bloqueado',
          subtitle:
              'Abrí los ajustes y elegí "Permitir siempre" para ubicación.',
          cta: 'Ajustes',
        );
      case LocationPermissionStatus.denied:
        return const _Copy(
          title: 'Necesitamos tu ubicación',
          subtitle: 'Sin permiso no podemos seguir tu ruta.',
          cta: 'Permitir',
        );
      case LocationPermissionStatus.foregroundOnly:
        return const _Copy(
          title: 'Permitir ubicación siempre',
          subtitle:
              'Sin "siempre", el seguimiento se detiene cuando minimizás el app.',
          cta: 'Permitir',
        );
      case LocationPermissionStatus.background:
        return const _Copy(title: '', subtitle: '', cta: '');
    }
  }
}

class _Copy {
  final String title;
  final String subtitle;
  final String cta;
  const _Copy({required this.title, required this.subtitle, required this.cta});
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';

/// Hero block at the top of the stop detail screen.
///
/// Layout inspired by delivery-app reference designs: sequence overline
/// + status pill on top, customer name as h2, address muted, then a
/// tinted "ticket card" surfacing the tracking ID with an inline copy
/// affordance — replaces the previous tag-icon row which read as data
/// noise more than a primary identifier.
class StopDetailHero extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback onCopyTracking;

  const StopDetailHero({
    super.key,
    required this.stop,
    required this.onCopyTracking,
  });

  @override
  Widget build(BuildContext context) {
    final seq = stop.sequence.toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('PARADA  $seq', style: AppTypography.overline),
            ),
            StatusPill(status: stop.status),
          ],
        ),
        const SizedBox(height: 12),
        Text(stop.displayName, style: AppTypography.h2),
        const SizedBox(height: 6),
        Text(
          stop.address,
          style: AppTypography.body.copyWith(color: AppColors.fgSecondary),
        ),
        if (stop.isRevisit) ...[
          const SizedBox(height: 12),
          _RevisitNotice(
            attemptNumber: stop.attemptNumber,
            priorVisitsCount: stop.priorVisitsCount,
          ),
        ],
        const SizedBox(height: 16),
        _TrackingTicket(
          trackingId: stop.trackingDisplay,
          onCopy: onCopyTracking,
        ),
      ],
    );
  }
}

/// Aviso destacado de que esta parada es una revisita: el conductor
/// debería revisar las notas y el historial antes de actuar.
class _RevisitNotice extends StatelessWidget {
  final int attemptNumber;
  final int priorVisitsCount;
  const _RevisitNotice({
    required this.attemptNumber,
    required this.priorVisitsCount,
  });

  @override
  Widget build(BuildContext context) {
    final priorLabel = priorVisitsCount == 1
        ? '1 intento previo registrado'
        : '$priorVisitsCount intentos previos registrados';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.accentWarningDim.withValues(alpha: 0.4),
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.accentWarning, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.replay_rounded,
            size: 18,
            color: AppColors.accentWarning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reintento · Intento #$attemptNumber',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accentWarning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  priorLabel,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.fgSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Green-tinted card that anchors the screen to the tracking ID — the
/// piece of info the driver references most when communicating with
/// support or the client. The tint links visually to the brand accent
/// without competing with downstream CTAs.
class _TrackingTicket extends StatelessWidget {
  final String trackingId;
  final VoidCallback onCopy;

  const _TrackingTicket({required this.trackingId, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.statusCompletedBg,
        borderRadius: AppRadius.rLg,
        border: Border.all(
          color: AppColors.accentLive.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRACKING ID',
                  style: AppTypography.overline.copyWith(
                    color: AppColors.accentLive,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trackingId,
                  style: AppTypography.statMedium.copyWith(
                    fontSize: 18,
                    color: AppColors.fgPrimary,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onCopy();
              },
              borderRadius: AppRadius.rFull,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentLive.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppColors.accentLive,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

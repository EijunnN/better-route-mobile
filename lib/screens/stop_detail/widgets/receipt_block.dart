import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';

/// Receipt-style information block. Replaces the previous stack of
/// individual cards (Cliente / Ubicación / Detalle del pedido) with a
/// single grouped surface where every row reads "label — value" — the
/// same pattern used by the delivery-app reference designs (Order
/// detail screen). The driver scans top-to-bottom in one fixation
/// instead of jumping between three cards.
///
/// Action row (Llamar / Maps / Waze) sits below the rows so the visual
/// weight of the buttons doesn't compete with the data.
class StopDetailReceipt extends StatelessWidget {
  final RouteStop stop;
  final Future<void> Function(String) onCall;
  final VoidCallback onMaps;
  final VoidCallback onWaze;

  const StopDetailReceipt({
    super.key,
    required this.stop,
    required this.onCall,
    required this.onMaps,
    required this.onWaze,
  });

  @override
  Widget build(BuildContext context) {
    final order = stop.order;
    final phone = order?.customerPhone;
    final hasPhone = phone != null && phone.isNotEmpty;
    final email = order?.customerEmail;
    final hasEmail = email != null && email.isNotEmpty;

    final rows = <Widget>[];

    rows.add(_ReceiptRow(label: 'Cliente', value: stop.displayName));

    if (hasPhone) {
      rows.add(_ReceiptRow(label: 'Teléfono', value: phone, mono: true));
    }
    if (hasEmail) {
      rows.add(_ReceiptRow(label: 'Email', value: email));
    }

    rows.add(_ReceiptRow(label: 'Dirección', value: stop.address));
    rows.add(
      _ReceiptRow(
        label: 'Coordenadas',
        value:
            '${stop.latitude.toStringAsFixed(5)}, ${stop.longitude.toStringAsFixed(5)}',
        mono: true,
      ),
    );

    if (order != null) {
      if ((order.weight ?? 0) > 0) {
        rows.add(
          _ReceiptRow(
            label: 'Peso',
            value: '${order.weight!.toStringAsFixed(0)} kg',
            mono: true,
          ),
        );
      }
      if ((order.volume ?? 0) > 0) {
        rows.add(
          _ReceiptRow(
            label: 'Volumen',
            value: '${order.volume!.toStringAsFixed(0)} L',
            mono: true,
          ),
        );
      }
      if ((order.units ?? 0) > 0) {
        rows.add(
          _ReceiptRow(
            label: 'Unidades',
            value: order.units!.toString(),
            mono: true,
          ),
        );
      }
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.borderSubtle,
                ),
              ),
            rows[i],
          ],
          const SizedBox(height: 16),
          _ActionRow(
            hasPhone: hasPhone,
            onCall: hasPhone ? () => onCall(phone) : null,
            onMaps: onMaps,
            onWaze: onWaze,
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.fgTertiary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: mono
                ? AppTypography.mono.copyWith(color: AppColors.fgPrimary)
                : AppTypography.bodyMedium,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool hasPhone;
  final VoidCallback? onCall;
  final VoidCallback onMaps;
  final VoidCallback onWaze;

  const _ActionRow({
    required this.hasPhone,
    required this.onCall,
    required this.onMaps,
    required this.onWaze,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (hasPhone)
          _CircleActionButton(
            icon: Icons.phone_rounded,
            tint: AppColors.accentLive,
            onTap: onCall!,
          ),
        if (hasPhone) const SizedBox(width: 10),
        Expanded(
          child: AppButton(
            label: 'Maps',
            icon: Icons.navigation_rounded,
            variant: AppButtonVariant.live,
            fullWidth: true,
            onPressed: onMaps,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppButton(
            label: 'Waze',
            icon: Icons.alt_route_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: onWaze,
          ),
        ),
      ],
    );
  }
}

/// Compact circular action — used for low-priority but fast actions
/// (call client) that share a row with text-bearing CTAs.
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rFull,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: tint.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 18, color: tint),
        ),
      ),
    );
  }
}

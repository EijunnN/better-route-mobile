import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';
import '../../../widgets/shared/shared.dart';

/// Customer contact block: name + phone + a "call" CTA when phone exists.
class ContactBlock extends StatelessWidget {
  final RouteStop stop;
  final Future<void> Function(String) onCall;

  const ContactBlock({
    super.key,
    required this.stop,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final phone = stop.order?.customerPhone;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.person_outline_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente', style: AppTypography.label),
                    const SizedBox(height: 4),
                    Text(stop.displayName, style: AppTypography.bodyMedium),
                    if (phone != null && phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(phone, style: AppTypography.mono),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 14),
            AppButton(
              label: 'Llamar',
              icon: Icons.phone_rounded,
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: () => onCall(phone),
            ),
          ],
        ],
      ),
    );
  }
}

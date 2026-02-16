import 'dart:io';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, showModalBottomSheet;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/delivery_action_sheet.dart';
import '../widgets/failure_reason_sheet.dart';

class StopDetailScreen extends ConsumerStatefulWidget {
  final String stopId;

  const StopDetailScreen({super.key, required this.stopId});

  @override
  ConsumerState<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends ConsumerState<StopDetailScreen> {
  bool _isProcessing = false;
  final List<File> _capturedPhotos = [];

  RouteStop? get stop => ref.watch(stopByIdProvider(widget.stopId));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentStop = stop;

    if (currentStop == null) {
      return Scaffold(
        headers: [
          AppBar(title: const Text('Parada')),
        ],
        child: const Center(child: Text('Parada no encontrada')),
      );
    }

    return SafeArea(
      child: Scaffold(
      headers: [
        AppBar(
          leading: [
            IconButton.ghost(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ],
          title: Text('Parada #${currentStop.sequence}'),
          trailing: [
            IconButton.ghost(
              icon: const Icon(Icons.copy_outlined, size: 22),
              onPressed: () => _copyTrackingId(currentStop),
            ),
          ],
        ),
      ],
      footers: [
        if (currentStop.status.isDone)
          _buildCompletedBar(currentStop)
        else
          _buildActionBar(currentStop),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          _buildStatusCard(currentStop),

          const SizedBox(height: 16),

          // Customer info
          _buildCustomerCard(currentStop),

          const SizedBox(height: 16),

          // Location card
          _buildLocationCard(currentStop),

          const SizedBox(height: 16),

          // Order details
          if (currentStop.order != null)
            _buildOrderCard(currentStop.order!),

          if (currentStop.order != null) const SizedBox(height: 16),

          // Notes
          if (currentStop.order?.notes != null &&
              currentStop.order!.notes!.isNotEmpty)
            _buildNotesCard(currentStop.order!.notes!),

          const SizedBox(height: 16),
        ],
      ),
    ),
    );
  }

  Widget _buildStatusCard(RouteStop stop) {
    final theme = Theme.of(context);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (stop.status) {
      case StopStatus.pending:
        statusColor = StatusColors.pending;
        statusText = 'Pendiente';
        statusIcon = Icons.schedule;
      case StopStatus.inProgress:
        statusColor = StatusColors.inProgress;
        statusText = 'En Progreso';
        statusIcon = Icons.play_circle;
      case StopStatus.completed:
        statusColor = StatusColors.completed;
        statusText = 'Entregado';
        statusIcon = Icons.check_circle;
      case StopStatus.failed:
        statusColor = StatusColors.failed;
        statusText = 'No Entregado';
        statusIcon = Icons.cancel;
      case StopStatus.skipped:
        statusColor = StatusColors.skipped;
        statusText = 'Omitido';
        statusIcon = Icons.skip_next;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha:0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                if (stop.timeWindow?.hasWindow == true) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: theme.colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ventana: ${stop.timeWindow!.displayText}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // ETA
          if (stop.estimatedArrival != null && !stop.status.isDone)
            Column(
              children: [
                Text(
                  stop.arrivalTimeDisplay,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                Text(
                  'ETA',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(RouteStop stop) {
    final theme = Theme.of(context);
    final order = stop.order;

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 20),
              const SizedBox(width: 8),
              const Text('Cliente').semiBold(),
            ],
          ),
          const SizedBox(height: 12),

          // Customer name
          Text(
            stop.displayName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Tracking ID
          const SizedBox(height: 4),
          Text(
            'ID: ${stop.trackingDisplay}',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.mutedForeground,
              fontFamily: 'monospace',
            ),
          ),

          // Phone
          if (order?.customerPhone != null &&
              order!.customerPhone!.isNotEmpty) ...[
            const Divider(height: 24),
            GestureDetector(
              onTap: () => _callPhone(order.customerPhone!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: StatusColors.completedBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.phone,
                        color: StatusColors.completed,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Telefono',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.mutedForeground,
                            ),
                          ),
                          Text(
                            order.customerPhone!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard(RouteStop stop) {
    final theme = Theme.of(context);
    final locationState = ref.watch(locationProvider);

    String? distanceText;
    if (locationState.currentLocation != null) {
      final locationService = ref.read(locationServiceProvider);
      final distance = locationService.distanceBetween(
        locationState.currentLocation!.latitude,
        locationState.currentLocation!.longitude,
        stop.latitude,
        stop.longitude,
      );
      distanceText = locationService.formatDistance(distance);
    }

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 20),
              const SizedBox(width: 8),
              const Text('Ubicacion').semiBold(),
              const Spacer(),
              if (distanceText != null)
                SecondaryBadge(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.navigation,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Address
          Text(stop.address),

          const SizedBox(height: 16),

          // Navigation buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: PrimaryButton(
                    onPressed: () => _openNavigation(stop),
                    leading: const Icon(Icons.navigation_outlined, size: 20),
                    child: const Text('Google Maps'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlineButton(
                    onPressed: () => _openWaze(stop),
                    leading:
                        const Icon(Icons.directions_car_outlined, size: 20),
                    child: const Text('Waze'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderInfo order) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 20),
              const SizedBox(width: 8),
              const Text('Detalles del Pedido').semiBold(),
            ],
          ),
          const SizedBox(height: 16),

          // Order details grid
          Row(
            children: [
              if (order.units != null)
                _buildOrderDetail(
                  Icons.widgets_outlined,
                  '${order.units}',
                  'Unidades',
                ),
              if (order.weight != null)
                _buildOrderDetail(
                  Icons.fitness_center_outlined,
                  '${order.weight!.toStringAsFixed(1)} kg',
                  'Peso',
                ),
              if (order.value != null)
                _buildOrderDetail(
                  Icons.attach_money,
                  '\$${order.value!.toStringAsFixed(0)}',
                  'Valor',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetail(IconData icon, String value, String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.mutedForeground),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(String notes) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEA580C).withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: Color(0xFFEA580C),
              ),
              const SizedBox(width: 8),
              Text(
                'Notas Importantes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(notes),
        ],
      ),
    );
  }

  Widget _buildActionBar(RouteStop stop) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary action button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: PrimaryButton(
                onPressed:
                    _isProcessing ? null : () => _handleDeliveryAction(stop),
                size: ButtonSize.large,
                child: _isProcessing
                    ? const CircularProgressIndicator(
                        size: 24,
                        strokeWidth: 2.5,
                        color: Colors.white,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            stop.status.isInProgress
                                ? Icons.check_circle
                                : Icons.play_circle_filled,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            stop.status.isInProgress
                                ? 'Completar entrega'
                                : 'Iniciar entrega',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Secondary action - failure button when in progress
            if (stop.status.isInProgress) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: DestructiveButton(
                  onPressed:
                      _isProcessing ? null : () => _handleFailure(stop),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'No se pudo entregar',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedBar(RouteStop stop) {
    Color bgColor;
    String message;
    IconData icon;
    Color iconColor;

    if (stop.status.isCompleted) {
      bgColor = StatusColors.completedBg;
      message = 'Entrega completada exitosamente';
      icon = Icons.check_circle;
      iconColor = StatusColors.completed;
    } else if (stop.status.isFailed) {
      bgColor = StatusColors.failedBg;
      final reason = FailureReason.fromString(stop.failureReason);
      message = 'No entregado: ${reason.label}';
      icon = Icons.cancel;
      iconColor = StatusColors.failed;
    } else {
      bgColor = StatusColors.skippedBg;
      message = 'Parada omitida';
      icon = Icons.skip_next;
      iconColor = StatusColors.skipped;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor),
      child: SafeArea(
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            GhostButton(
              onPressed: () => context.pop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  // Actions

  void _copyTrackingId(RouteStop stop) {
    Clipboard.setData(ClipboardData(text: stop.trackingDisplay));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ID copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openNavigation(RouteStop stop) async {
    await ref.read(locationProvider.notifier).navigateTo(
          stop.latitude,
          stop.longitude,
        );
  }

  Future<void> _openWaze(RouteStop stop) async {
    await ref.read(locationProvider.notifier).openWaze(
          stop.latitude,
          stop.longitude,
        );
  }

  Future<void> _handleDeliveryAction(RouteStop stop) async {
    if (stop.status.isPending) {
      // Start the stop
      setState(() => _isProcessing = true);
      final success =
          await ref.read(routeProvider.notifier).startStop(stop.id);
      setState(() => _isProcessing = false);

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al iniciar la entrega')),
        );
      }
    } else if (stop.status.isInProgress) {
      // Show delivery action sheet
      _showDeliveryActionSheet(stop);
    }
  }

  void _showDeliveryActionSheet(RouteStop stop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeliveryActionSheet(
        stop: stop,
        onComplete: (photos, notes) =>
            _completeDelivery(stop, photos, notes),
      ),
    );
  }

  Future<void> _completeDelivery(
    RouteStop stop,
    List<File> photos,
    String? notes,
  ) async {
    Navigator.pop(context); // Close sheet

    setState(() => _isProcessing = true);

    try {
      // Upload photos
      final evidenceUrls = <String>[];
      final trackingId = stop.order?.trackingId ?? stop.id;

      for (int i = 0; i < photos.length; i++) {
        final url = await ref.read(routeProvider.notifier).uploadEvidence(
              photo: photos[i],
              trackingId: trackingId,
              index: i + 1,
            );
        if (url != null) {
          evidenceUrls.add(url);
        }
      }

      // Complete the stop
      final success = await ref.read(routeProvider.notifier).completeStop(
            stopId: stop.id,
            evidenceUrls: evidenceUrls,
            notes: notes,
          );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al completar la entrega')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleFailure(RouteStop stop) async {
    final result = await showModalBottomSheet<
        ({FailureReason reason, String? notes, List<File> photos})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FailureReasonSheet(stop: stop),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);

    try {
      // Upload evidence photos if any
      final evidenceUrls = <String>[];
      if (result.photos.isNotEmpty) {
        final trackingId = stop.order?.trackingId ?? stop.id;
        for (int i = 0; i < result.photos.length; i++) {
          final url = await ref.read(routeProvider.notifier).uploadEvidence(
                photo: result.photos[i],
                trackingId: trackingId,
                index: i + 1,
              );
          if (url != null) {
            evidenceUrls.add(url);
          }
        }
      }

      // Mark as failed
      final success = await ref.read(routeProvider.notifier).failStop(
            stopId: stop.id,
            reason: result.reason,
            evidenceUrls: evidenceUrls.isNotEmpty ? evidenceUrls : null,
            notes: result.notes,
          );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al reportar el fallo')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}

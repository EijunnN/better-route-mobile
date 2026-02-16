import 'dart:io';
import 'package:flutter/material.dart';
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
        appBar: AppBar(title: const Text('Parada')),
        body: const Center(child: Text('Parada no encontrada')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Parada #${currentStop.sequence}',
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 22),
            tooltip: 'Copiar tracking',
            onPressed: () => _copyTrackingId(currentStop),
          ),
        ],
      ),
      body: ListView(
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

          if (currentStop.order != null)
            const SizedBox(height: 16),

          // Notes
          if (currentStop.order?.notes != null &&
              currentStop.order!.notes!.isNotEmpty)
            _buildNotesCard(currentStop.order!.notes!),

          // Bottom spacing for action bar
          const SizedBox(height: 100),
        ],
      ),

      // Bottom action buttons - fixed with SafeArea
      bottomNavigationBar: currentStop.status.isDone
          ? _buildCompletedBar(currentStop)
          : _buildActionBar(currentStop),
    );
  }

  Widget _buildStatusCard(RouteStop stop) {
    final theme = Theme.of(context);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (stop.status) {
      case StopStatus.pending:
        statusColor = AppColors.pending;
        statusText = 'Pendiente';
        statusIcon = Icons.schedule;
      case StopStatus.inProgress:
        statusColor = AppColors.inProgress;
        statusText = 'En Progreso';
        statusIcon = Icons.play_circle;
      case StopStatus.completed:
        statusColor = AppColors.completed;
        statusText = 'Entregado';
        statusIcon = Icons.check_circle;
      case StopStatus.failed:
        statusColor = AppColors.failed;
        statusText = 'No Entregado';
        statusIcon = Icons.cancel;
      case StopStatus.skipped:
        statusColor = AppColors.skipped;
        statusText = 'Omitido';
        statusIcon = Icons.skip_next;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
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
                  style: theme.textTheme.titleMedium?.copyWith(
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
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ventana: ${stop.timeWindow!.displayText}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
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
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                Text(
                  'ETA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Cliente',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer name
            Text(
              stop.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            // Tracking ID
            const SizedBox(height: 4),
            Text(
              'ID: ${stop.trackingDisplay}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),

            // Phone
            if (order?.customerPhone != null &&
                order!.customerPhone!.isNotEmpty) ...[
              const Divider(height: 24),
              InkWell(
                onTap: () => _callPhone(order.customerPhone!),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.phone,
                          color: AppColors.success,
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
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              order.customerPhone!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textTertiary,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ubicacion',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (distanceText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.navigation,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distanceText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.primary,
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
            Text(
              stop.address,
              style: theme.textTheme.bodyLarge,
            ),

            const SizedBox(height: 16),

            // Navigation buttons - prominent
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _openNavigation(stop),
                      icon: const Icon(Icons.navigation_outlined, size: 20),
                      label: const Text('Google Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _openWaze(stop),
                      icon: const Icon(Icons.directions_car_outlined, size: 20),
                      label: const Text('Waze'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderInfo order) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Detalles del Pedido',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
      ),
    );
  }

  Widget _buildOrderDetail(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
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
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                'Notas Importantes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(RouteStop stop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _handleDeliveryAction(stop),
                style: ElevatedButton.styleFrom(
                  backgroundColor: stop.status.isInProgress
                      ? AppColors.success
                      : AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
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
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : () => _handleFailure(stop),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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
    final theme = Theme.of(context);

    Color bgColor;
    String message;
    IconData icon;

    if (stop.status.isCompleted) {
      bgColor = AppColors.successLight;
      message = 'Entrega completada exitosamente';
      icon = Icons.check_circle;
    } else if (stop.status.isFailed) {
      bgColor = AppColors.errorLight;
      final reason = FailureReason.fromString(stop.failureReason);
      message = 'No entregado: ${reason.label}';
      icon = Icons.cancel;
    } else {
      bgColor = AppColors.skippedBg;
      message = 'Parada omitida';
      icon = Icons.skip_next;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
      ),
      child: SafeArea(
        child: Row(
          children: [
            Icon(
              icon,
              color: stop.status.isCompleted
                  ? AppColors.success
                  : stop.status.isFailed
                      ? AppColors.error
                      : AppColors.skipped,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
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
      final success = await ref.read(routeProvider.notifier).startStop(stop.id);
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
        onComplete: (photos, notes) => _completeDelivery(stop, photos, notes),
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
    final result = await showModalBottomSheet<({FailureReason reason, String? notes, List<File> photos})>(
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

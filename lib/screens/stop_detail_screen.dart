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
import '../widgets/custom_fields_display.dart';

class StopDetailScreen extends ConsumerStatefulWidget {
  final String stopId;

  const StopDetailScreen({super.key, required this.stopId});

  @override
  ConsumerState<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends ConsumerState<StopDetailScreen> {
  bool _isProcessing = false;

  RouteStop? get stop => ref.watch(stopByIdProvider(widget.stopId));

  @override
  Widget build(BuildContext context) {
    final currentStop = stop;

    if (currentStop == null) {
      return Scaffold(
        headers: [
          AppBar(title: const Text('Parada')),
        ],
        child: const Center(child: Text('Parada no encontrada')),
      );
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.background,
      child: SafeArea(
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

          // Custom fields
          if (currentStop.order != null &&
              currentStop.order!.hasCustomFields)
            _buildCustomFieldsCard(currentStop.order!),

          if (currentStop.order != null &&
              currentStop.order!.hasCustomFields)
            const SizedBox(height: 16),

          // Notes
          if (currentStop.order?.notes != null &&
              currentStop.order!.notes!.isNotEmpty)
            _buildNotesCard(currentStop.order!.notes!),

          const SizedBox(height: 16),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildStatusCard(RouteStop stop) {
    final theme = Theme.of(context);
    final workflowState = ref.watch(workflowProvider);

    // Try to get workflow state label and color
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (workflowState.hasStates && stop.workflowStateId != null) {
      final wfState = ref.read(workflowProvider.notifier).findById(stop.workflowStateId!);
      if (wfState != null) {
        statusColor = wfState.colorValue;
        statusText = wfState.label;
        statusIcon = _iconForSystemState(wfState.systemState);
      } else {
        // Fallback to stop's embedded workflow data
        final result = _resolveStatusDisplay(stop);
        statusColor = result.color;
        statusText = result.text;
        statusIcon = result.icon;
      }
    } else {
      final result = _resolveStatusDisplay(stop);
      statusColor = result.color;
      statusText = result.text;
      statusIcon = result.icon;
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

  /// Resolve status display from stop data (using embedded workflow or hardcoded)
  ({Color color, String text, IconData icon}) _resolveStatusDisplay(RouteStop stop) {
    // Try embedded workflow state data first
    if (stop.workflowStateLabel != null && stop.workflowStateColor != null) {
      final hex = stop.workflowStateColor!.replaceFirst('#', '');
      final color = Color(int.parse('0xFF$hex'));
      return (
        color: color,
        text: stop.workflowStateLabel!,
        icon: _iconForSystemState(stop.status.value),
      );
    }

    // Hardcoded fallback
    switch (stop.status) {
      case StopStatus.pending:
        return (color: StatusColors.pending, text: 'Pendiente', icon: Icons.schedule);
      case StopStatus.inProgress:
        return (color: StatusColors.inProgress, text: 'En Progreso', icon: Icons.play_circle);
      case StopStatus.completed:
        return (color: StatusColors.completed, text: 'Entregado', icon: Icons.check_circle);
      case StopStatus.failed:
        return (color: StatusColors.failed, text: 'No Entregado', icon: Icons.cancel);
      case StopStatus.skipped:
        return (color: StatusColors.skipped, text: 'Omitido', icon: Icons.skip_next);
    }
  }

  IconData _iconForSystemState(String systemState) {
    switch (systemState) {
      case 'PENDING':
        return Icons.schedule;
      case 'IN_PROGRESS':
        return Icons.play_circle;
      case 'COMPLETED':
        return Icons.check_circle;
      case 'FAILED':
        return Icons.cancel;
      case 'CANCELLED':
        return Icons.skip_next;
      default:
        return Icons.circle_outlined;
    }
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
                        color: StatusColors.completedBackground(theme.brightness),
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

  Widget _buildCustomFieldsCard(OrderInfo order) {
    final fieldDefState = ref.watch(fieldDefinitionProvider);

    if (!fieldDefState.hasDefinitions) return const SizedBox.shrink();

    return CustomFieldsDisplay(
      customFields: order.customFields,
      definitions: fieldDefState.orderFields,
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
    final brightness = Theme.of(context).brightness;
    final notesBg = StatusColors.notesBackground(brightness);
    final notesAccent = StatusColors.notesAccentColor(brightness);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notesBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: notesAccent.withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: notesAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'Notas Importantes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: notesAccent,
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
    final workflowState = ref.watch(workflowProvider);

    // If workflow states are loaded, use dynamic buttons
    if (workflowState.hasStates) {
      return _buildDynamicActionBar(stop, workflowState);
    }

    // Fallback to hardcoded buttons
    return _buildHardcodedActionBar(stop);
  }

  /// Dynamic action bar powered by workflow states
  Widget _buildDynamicActionBar(RouteStop stop, WorkflowStatesState wfState) {
    final theme = Theme.of(context);
    final notifier = ref.read(workflowProvider.notifier);

    // Find the current workflow state for this stop
    WorkflowState? currentWfState;
    if (stop.workflowStateId != null) {
      currentWfState = notifier.findById(stop.workflowStateId!);
    }
    // Fallback: find by system state
    currentWfState ??= notifier.findBySystemState(stop.status.value);

    if (currentWfState == null) {
      // No workflow state found, fall back to hardcoded
      return _buildHardcodedActionBar(stop);
    }

    // Get available transitions
    final transitions = notifier.getAvailableTransitions(currentWfState.id);

    if (transitions.isEmpty) {
      return _buildHardcodedActionBar(stop);
    }

    // Sort transitions: non-terminal first, terminal last
    final sortedTransitions = [...transitions]
      ..sort((a, b) {
        if (a.isTerminal == b.isTerminal) return a.position.compareTo(b.position);
        return a.isTerminal ? 1 : -1;
      });

    // Primary transition is the first non-terminal (or first overall)
    final primaryTransition = sortedTransitions.first;
    final secondaryTransitions = sortedTransitions.skip(1).toList();

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
              child: _buildWorkflowButton(
                stop: stop,
                targetState: primaryTransition,
                isPrimary: true,
              ),
            ),

            // Secondary action buttons
            for (final transition in secondaryTransitions) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _buildWorkflowButton(
                  stop: stop,
                  targetState: transition,
                  isPrimary: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowButton({
    required RouteStop stop,
    required WorkflowState targetState,
    required bool isPrimary,
  }) {
    final isFailed = targetState.isFailed || targetState.isCancelled;

    if (_isProcessing) {
      if (isPrimary) {
        return PrimaryButton(
          onPressed: null,
          size: ButtonSize.large,
          child: CircularProgressIndicator(
            size: 24,
            strokeWidth: 2.5,
            color: Theme.of(context).colorScheme.primaryForeground,
          ),
        );
      } else {
        return OutlineButton(
          onPressed: null,
          child: const CircularProgressIndicator(size: 20, strokeWidth: 2),
        );
      }
    }

    void onPressed() => _handleWorkflowTransition(stop, targetState);

    if (isPrimary) {
      if (isFailed) {
        return DestructiveButton(
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_iconForSystemState(targetState.systemState), size: 24),
              const SizedBox(width: 8),
              Text(
                targetState.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }
      return PrimaryButton(
        onPressed: onPressed,
        size: ButtonSize.large,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconForSystemState(targetState.systemState), size: 24),
            const SizedBox(width: 8),
            Text(
              targetState.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      if (isFailed) {
        return DestructiveButton(
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_iconForSystemState(targetState.systemState), size: 20),
              const SizedBox(width: 8),
              Text(
                targetState.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }
      return OutlineButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconForSystemState(targetState.systemState), size: 20),
            const SizedBox(width: 8),
            Text(
              targetState.label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
  }

  /// Handle a dynamic workflow transition
  Future<void> _handleWorkflowTransition(
    RouteStop stop,
    WorkflowState targetState,
  ) async {
    // Determine what data needs to be collected based on target state requirements
    final needsPhoto = targetState.requiresPhoto;
    final needsReason = targetState.requiresReason;
    final needsNotes = targetState.requiresNotes;

    // If the target state requires any data collection, show the appropriate sheet
    if (needsPhoto || needsReason || needsNotes) {
      _showWorkflowActionSheet(stop, targetState);
      return;
    }

    // No data collection needed -- just transition directly
    setState(() => _isProcessing = true);

    final success = await ref.read(routeProvider.notifier).transitionStop(
      stopId: stop.id,
      workflowStateId: targetState.id,
      systemState: targetState.systemState,
    );

    setState(() => _isProcessing = false);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cambiar a ${targetState.label}')),
      );
    }
  }

  /// Show a bottom sheet to collect required data for the workflow transition
  void _showWorkflowActionSheet(RouteStop stop, WorkflowState targetState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WorkflowTransitionSheet(
        stop: stop,
        targetState: targetState,
        onConfirm: (photos, notes, reason) =>
            _executeWorkflowTransition(stop, targetState, photos, notes, reason),
      ),
    );
  }

  Future<void> _executeWorkflowTransition(
    RouteStop stop,
    WorkflowState targetState,
    List<File> photos,
    String? notes,
    String? reason,
  ) async {
    Navigator.pop(context); // Close sheet
    setState(() => _isProcessing = true);

    try {
      // Upload photos if any
      final evidenceUrls = <String>[];
      if (photos.isNotEmpty) {
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
      }

      final success = await ref.read(routeProvider.notifier).transitionStop(
        stopId: stop.id,
        workflowStateId: targetState.id,
        systemState: targetState.systemState,
        notes: notes,
        failureReason: reason,
        evidenceUrls: evidenceUrls.isNotEmpty ? evidenceUrls : null,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar a ${targetState.label}')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Fallback: hardcoded action bar (used when workflow states are not available)
  Widget _buildHardcodedActionBar(RouteStop stop) {
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
                    ? CircularProgressIndicator(
                        size: 24,
                        strokeWidth: 2.5,
                        color: Theme.of(context).colorScheme.primaryForeground,
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
    final workflowState = ref.watch(workflowProvider);

    Color bgColor;
    String message;
    IconData icon;
    Color iconColor;

    // Try workflow state data first
    if (workflowState.hasStates && stop.workflowStateId != null) {
      final wfState = ref.read(workflowProvider.notifier).findById(stop.workflowStateId!);
      if (wfState != null) {
        bgColor = wfState.bgColor;
        message = wfState.label;
        icon = _iconForSystemState(wfState.systemState);
        iconColor = wfState.colorValue;

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
    }

    // Fallback to embedded workflow state data
    if (stop.workflowStateLabel != null && stop.workflowStateColor != null) {
      final hex = stop.workflowStateColor!.replaceFirst('#', '');
      iconColor = Color(int.parse('0xFF$hex'));
      bgColor = iconColor.withValues(alpha: 0.1);
      message = stop.workflowStateLabel!;
      icon = _iconForSystemState(stop.status.value);
    } else if (stop.status.isCompleted) {
      final brightness = Theme.of(context).brightness;
      bgColor = StatusColors.completedBackground(brightness);
      message = 'Entrega completada exitosamente';
      icon = Icons.check_circle;
      iconColor = StatusColors.completed;
    } else if (stop.status.isFailed) {
      final brightness = Theme.of(context).brightness;
      bgColor = StatusColors.failedBackground(brightness);
      final reason = FailureReason.fromString(stop.failureReason);
      message = 'No entregado: ${reason.label}';
      icon = Icons.cancel;
      iconColor = StatusColors.failed;
    } else {
      final brightness = Theme.of(context).brightness;
      bgColor = StatusColors.skippedBackground(brightness);
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

/// Bottom sheet for collecting data required by a workflow transition
class _WorkflowTransitionSheet extends StatefulWidget {
  final RouteStop stop;
  final WorkflowState targetState;
  final Function(List<File> photos, String? notes, String? reason) onConfirm;

  const _WorkflowTransitionSheet({
    required this.stop,
    required this.targetState,
    required this.onConfirm,
  });

  @override
  State<_WorkflowTransitionSheet> createState() =>
      _WorkflowTransitionSheetState();
}

class _WorkflowTransitionSheetState extends State<_WorkflowTransitionSheet> {
  final List<File> _photos = [];
  final _notesController = TextEditingController();
  final _picker = ImagePicker();
  bool _isCapturing = false;
  String? _selectedReason;

  bool get _needsPhoto => widget.targetState.requiresPhoto;
  bool get _needsReason => widget.targetState.requiresReason;
  bool get _needsNotes => widget.targetState.requiresNotes;
  List<String>? get _reasonOptions => widget.targetState.reasonOptions;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        setState(() => _photos.add(File(photo.path)));
      }
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  bool get _canConfirm {
    if (_needsPhoto && _photos.isEmpty) return false;
    if (_needsReason && _selectedReason == null) return false;
    if (_needsNotes && _notesController.text.trim().isEmpty) return false;
    return true;
  }

  void _confirm() {
    if (!_canConfirm) {
      String message = 'Por favor, completa los campos requeridos';
      if (_needsPhoto && _photos.isEmpty) {
        message = 'Se requiere al menos una foto';
      } else if (_needsReason && _selectedReason == null) {
        message = 'Se requiere seleccionar un motivo';
      } else if (_needsNotes && _notesController.text.trim().isEmpty) {
        message = 'Se requieren notas';
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Campo requerido'),
          content: Text(message),
          actions: [
            PrimaryButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    widget.onConfirm(
      _photos,
      _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      _selectedReason,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final targetColor = widget.targetState.colorValue;
    final isFailed = widget.targetState.isFailed || widget.targetState.isCancelled;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header with target state info
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: targetColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _iconForState(widget.targetState.systemState),
                        color: targetColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.targetState.label).semiBold().large(),
                          Text(widget.stop.displayName).small().muted(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Reason selection
                  if (_needsReason && _reasonOptions != null && _reasonOptions!.isNotEmpty) ...[
                    const Text('Motivo').semiBold().small(),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _reasonOptions!.map((reason) {
                        final isSelected = _selectedReason == reason;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedReason = reason),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? targetColor.withValues(alpha: 0.1)
                                  : theme.colorScheme.muted,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? targetColor : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected
                                    ? targetColor
                                    : theme.colorScheme.foreground,
                              ),
                            ).small(),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Photo section
                  if (_needsPhoto) ...[
                    Row(
                      children: [
                        const Text('Foto de evidencia').semiBold().small(),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_photos.isNotEmpty) ...[
                      SizedBox(
                        height: 88,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _photos.length) {
                              return _buildAddPhotoButton(theme);
                            }
                            return _buildPhotoThumbnail(index);
                          },
                        ),
                      ),
                    ] else ...[
                      GestureDetector(
                        onTap: _takePhoto,
                        child: Container(
                          height: 88,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.muted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.colorScheme.border),
                          ),
                          child: _isCapturing
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_rounded,
                                      size: 22,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tomar foto',
                                      style: TextStyle(color: theme.colorScheme.primary),
                                    ).semiBold(),
                                  ],
                                ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],

                  // Notes field
                  // Notes field always visible (required label changes based on state config)
                  ...[
                    Text(
                      _needsNotes ? 'Notas' : 'Notas (opcional)',
                    ).semiBold().small(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      placeholder: const Text('Agrega notas...'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // Fixed action buttons at bottom
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.border),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: isFailed
                        ? DestructiveButton(
                            onPressed: _canConfirm ? _confirm : null,
                            child: Text(
                              'Confirmar',
                              style: TextStyle(
                                color: _canConfirm
                                    ? null
                                    : theme.colorScheme.mutedForeground,
                              ),
                            ).semiBold(),
                          )
                        : PrimaryButton(
                            onPressed: _canConfirm ? _confirm : null,
                            child: Text(
                              'Confirmar',
                              style: TextStyle(
                                color: _canConfirm
                                    ? theme.colorScheme.primaryForeground
                                    : theme.colorScheme.mutedForeground,
                              ),
                            ).semiBold(),
                          ),
                  ),
                  Center(
                    child: GhostButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar').muted(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForState(String systemState) {
    switch (systemState) {
      case 'PENDING':
        return Icons.schedule;
      case 'IN_PROGRESS':
        return Icons.play_circle;
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      case 'FAILED':
        return Icons.cancel_rounded;
      case 'CANCELLED':
        return Icons.skip_next;
      default:
        return Icons.circle_outlined;
    }
  }

  Widget _buildPhotoThumbnail(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              _photos[index],
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removePhoto(index),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: StatusColors.failed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoButton(ThemeData theme) {
    return GestureDetector(
      onTap: _takePhoto,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 22,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 4),
            Text('Agregar').xSmall().muted(),
          ],
        ),
      ),
    );
  }
}

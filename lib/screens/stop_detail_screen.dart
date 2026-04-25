import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/design/tokens.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/app/app.dart';
import '../widgets/custom_fields_display.dart';
import '../widgets/delivery_action_sheet.dart';
import '../widgets/failure_reason_sheet.dart';

/// Stop detail — driver's working surface for one stop.
///
/// Layout: full-bleed dark canvas, big header (sequence + customer +
/// status pill), then sectioned content (time window, contact, address +
/// navigation, order details, custom fields, notes), and a sticky bottom
/// action bar with primary CTA (Start / Complete) and secondary
/// (No se pudo entregar) sized for one-handed thumb reach.
///
/// Handlers and the workflow transition sheet are preserved verbatim
/// from the prior implementation — only the UI shell is rebuilt with the
/// cockpit primitives.
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
        backgroundColor: AppColors.bgBase,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(onBack: () => context.pop(), trailing: const SizedBox()),
              const Spacer(),
              Center(
                child: Text(
                  'Parada no encontrada',
                  style: AppTypography.body.copyWith(color: AppColors.fgSecondary),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onBack: () => context.pop(),
              trailing: _CircleAction(
                icon: Icons.copy_rounded,
                onTap: () => _copyTrackingId(currentStop),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(stop: currentStop),
                    const SizedBox(height: 20),
                    if (currentStop.timeWindow != null) ...[
                      _TimeWindowBlock(stop: currentStop),
                      const SizedBox(height: 12),
                    ],
                    _ContactBlock(
                      stop: currentStop,
                      onCall: _callPhone,
                    ),
                    const SizedBox(height: 12),
                    _LocationBlock(
                      stop: currentStop,
                      onMaps: () => _openNavigation(currentStop),
                      onWaze: () => _openWaze(currentStop),
                    ),
                    if (currentStop.order != null) ...[
                      const SizedBox(height: 12),
                      _OrderBlock(order: currentStop.order!),
                    ],
                    if (currentStop.order != null &&
                        currentStop.order!.hasCustomFields) ...[
                      const SizedBox(height: 12),
                      _OrderCustomFields(stop: currentStop),
                    ],
                    if (currentStop.order?.notes != null &&
                        currentStop.order!.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _NotesBlock(notes: currentStop.order!.notes!),
                    ],
                    if (currentStop.failureReason != null &&
                        currentStop.status == StopStatus.failed) ...[
                      const SizedBox(height: 12),
                      _FailureBlock(reason: currentStop.failureReason!),
                    ],
                  ],
                ),
              ),
            ),
            currentStop.status.isDone
                ? _CompletedBar(stop: currentStop, onBack: () => context.pop())
                : _ActionBar(
                    stop: currentStop,
                    isProcessing: _isProcessing,
                    onPrimary: () => _handleDeliveryAction(currentStop),
                    onFail: () => _handleFailure(currentStop),
                    onWorkflowTransition: _handleWorkflowTransition,
                  ),
          ],
        ),
      ),
    );
  }

  // ── Handlers (preserved from previous implementation) ───────────────

  void _copyTrackingId(RouteStop s) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: s.trackingDisplay));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ID copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openNavigation(RouteStop s) async {
    await ref
        .read(locationProvider.notifier)
        .navigateTo(s.latitude, s.longitude);
  }

  Future<void> _openWaze(RouteStop s) async {
    await ref
        .read(locationProvider.notifier)
        .openWaze(s.latitude, s.longitude);
  }

  Future<void> _handleDeliveryAction(RouteStop s) async {
    if (s.status.isPending) {
      setState(() => _isProcessing = true);
      final success =
          await ref.read(routeProvider.notifier).startStop(s.id);
      setState(() => _isProcessing = false);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al iniciar la entrega')),
        );
      }
    } else if (s.status.isInProgress) {
      _showDeliveryActionSheet(s);
    }
  }

  void _showDeliveryActionSheet(RouteStop s) {
    final fieldDefState = ref.read(fieldDefinitionProvider);
    final stopFields = fieldDefState.stopFields;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeliveryActionSheet(
        stop: s,
        stopFieldDefinitions: stopFields,
        onComplete: (photos, notes, customFields) =>
            _completeDelivery(s, photos, notes, customFields),
      ),
    );
  }

  Future<void> _completeDelivery(
    RouteStop s,
    List<File> photos,
    String? notes,
    Map<String, dynamic> customFields,
  ) async {
    Navigator.pop(context);
    setState(() => _isProcessing = true);
    try {
      final evidenceUrls = <String>[];
      final trackingId = s.order?.trackingId ?? s.id;
      for (int i = 0; i < photos.length; i++) {
        final url = await ref.read(routeProvider.notifier).uploadEvidence(
              photo: photos[i],
              trackingId: trackingId,
              index: i + 1,
            );
        if (url != null) evidenceUrls.add(url);
      }
      final success = await ref.read(routeProvider.notifier).completeStop(
            stopId: s.id,
            evidenceUrls: evidenceUrls,
            notes: notes,
            customFields: customFields.isEmpty ? null : customFields,
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

  Future<void> _handleFailure(RouteStop s) async {
    final result = await showModalBottomSheet<
        ({
          FailureReason? reason,
          String? customReason,
          String? notes,
          List<File> photos,
        })>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FailureReasonSheet(stop: s),
    );

    if (result == null || result.reason == null) return;

    setState(() => _isProcessing = true);
    try {
      final evidenceUrls = <String>[];
      if (result.photos.isNotEmpty) {
        final trackingId = s.order?.trackingId ?? s.id;
        for (int i = 0; i < result.photos.length; i++) {
          final url = await ref.read(routeProvider.notifier).uploadEvidence(
                photo: result.photos[i],
                trackingId: trackingId,
                index: i + 1,
              );
          if (url != null) evidenceUrls.add(url);
        }
      }
      final success = await ref.read(routeProvider.notifier).failStop(
            stopId: s.id,
            reason: result.reason!,
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

  Future<void> _handleWorkflowTransition(
    RouteStop s,
    WorkflowState targetState,
  ) async {
    final needsPhoto = targetState.requiresPhoto;
    final needsReason = targetState.requiresReason;
    final needsNotes = targetState.requiresNotes;

    if (needsPhoto || needsReason || needsNotes) {
      _showWorkflowActionSheet(s, targetState);
      return;
    }

    setState(() => _isProcessing = true);
    final success = await ref.read(routeProvider.notifier).transitionStop(
          stopId: s.id,
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

  void _showWorkflowActionSheet(RouteStop s, WorkflowState targetState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WorkflowTransitionSheet(
        stop: s,
        targetState: targetState,
        onConfirm: (photos, notes, reason) =>
            _executeWorkflowTransition(s, targetState, photos, notes, reason),
      ),
    );
  }

  Future<void> _executeWorkflowTransition(
    RouteStop s,
    WorkflowState targetState,
    List<File> photos,
    String? notes,
    String? reason,
  ) async {
    Navigator.pop(context);
    setState(() => _isProcessing = true);
    try {
      final evidenceUrls = <String>[];
      if (photos.isNotEmpty) {
        final trackingId = s.order?.trackingId ?? s.id;
        for (int i = 0; i < photos.length; i++) {
          final url = await ref.read(routeProvider.notifier).uploadEvidence(
                photo: photos[i],
                trackingId: trackingId,
                index: i + 1,
              );
          if (url != null) evidenceUrls.add(url);
        }
      }
      final success = await ref.read(routeProvider.notifier).transitionStop(
            stopId: s.id,
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
}

// ── Top bar ──────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final Widget trailing;

  const _TopBar({required this.onBack, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _CircleAction(
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: AppRadius.rFull,
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Icon(icon, size: 16, color: AppColors.fgPrimary),
      ),
    );
  }
}

// ── Hero (sequence + customer + status) ──────────────────────────────

class _Hero extends StatelessWidget {
  final RouteStop stop;

  const _Hero({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Parada', style: AppTypography.overline),
            const SizedBox(width: 8),
            Text(
              '#${stop.sequence.toString().padLeft(2, '0')}',
              style: AppTypography.statMedium.copyWith(
                fontSize: 16,
                color: AppColors.fgSecondary,
              ),
            ),
            const Spacer(),
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
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.tag_rounded, size: 14, color: AppColors.fgTertiary),
            const SizedBox(width: 4),
            Text(stop.trackingDisplay, style: AppTypography.mono),
          ],
        ),
      ],
    );
  }
}

// ── Time window block ────────────────────────────────────────────────

class _TimeWindowBlock extends StatelessWidget {
  final RouteStop stop;

  const _TimeWindowBlock({required this.stop});

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tw = stop.timeWindow!;
    final eta = stop.estimatedArrival;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBubble(icon: Icons.schedule_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ventana horaria', style: AppTypography.label),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(tw.start)} – ${_fmt(tw.end)}',
                  style: AppTypography.statMedium.copyWith(fontSize: 18),
                ),
                if (eta != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Llegada estimada: ${_fmt(eta)}',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact block ────────────────────────────────────────────────────

class _ContactBlock extends StatelessWidget {
  final RouteStop stop;
  final Future<void> Function(String) onCall;

  const _ContactBlock({required this.stop, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final phone = stop.order?.customerPhone;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon: Icons.person_outline_rounded),
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

// ── Location block ────────────────────────────────────────────────────

class _LocationBlock extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback onMaps;
  final VoidCallback onWaze;

  const _LocationBlock({
    required this.stop,
    required this.onMaps,
    required this.onWaze,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon: Icons.place_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ubicación', style: AppTypography.label),
                    const SizedBox(height: 4),
                    Text(stop.address, style: AppTypography.body),
                    const SizedBox(height: 4),
                    Text(
                      '${stop.latitude.toStringAsFixed(6)}, ${stop.longitude.toStringAsFixed(6)}',
                      style: AppTypography.monoSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Maps',
                  icon: Icons.navigation_rounded,
                  variant: AppButtonVariant.primary,
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
          ),
        ],
      ),
    );
  }
}

// ── Order block ──────────────────────────────────────────────────────

class _OrderBlock extends StatelessWidget {
  final OrderInfo order;

  const _OrderBlock({required this.order});

  @override
  Widget build(BuildContext context) {
    final hasMetrics = (order.weight ?? 0) > 0 ||
        (order.volume ?? 0) > 0 ||
        (order.units ?? 0) > 0;
    if (!hasMetrics) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon: Icons.inventory_2_outlined),
              const SizedBox(width: 14),
              Text('Detalle del pedido', style: AppTypography.label),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              if ((order.weight ?? 0) > 0)
                _Metric(
                  label: 'Peso',
                  value: order.weight!.toStringAsFixed(0),
                  unit: 'kg',
                ),
              if ((order.volume ?? 0) > 0)
                _Metric(
                  label: 'Volumen',
                  value: order.volume!.toStringAsFixed(0),
                  unit: 'L',
                ),
              if ((order.units ?? 0) > 0)
                _Metric(
                  label: 'Unidades',
                  value: order.units!.toString(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const _Metric({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.overline),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppTypography.statMedium.copyWith(fontSize: 20)),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Text(unit!, style: AppTypography.bodySmall),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Custom fields block ──────────────────────────────────────────────

class _OrderCustomFields extends ConsumerWidget {
  final RouteStop stop;

  const _OrderCustomFields({required this.stop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldDefState = ref.watch(fieldDefinitionProvider);
    if (!fieldDefState.hasDefinitions) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon: Icons.list_alt_rounded),
              const SizedBox(width: 14),
              Text('Datos del pedido', style: AppTypography.label),
            ],
          ),
          const SizedBox(height: 12),
          CustomFieldsDisplay(
            customFields: stop.order!.customFields,
            definitions: fieldDefState.orderFields,
          ),
        ],
      ),
    );
  }
}

// ── Notes block ──────────────────────────────────────────────────────

class _NotesBlock extends StatelessWidget {
  final String notes;

  const _NotesBlock({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentWarningDim.withValues(alpha: 0.25),
        borderRadius: AppRadius.rLg,
        border: Border.all(
          color: AppColors.accentWarning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sticky_note_2_outlined,
            size: 18,
            color: AppColors.accentWarning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nota del cliente',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accentWarning,
                  ),
                ),
                const SizedBox(height: 6),
                Text(notes, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Failure block (when stop is failed, show reason) ─────────────────

class _FailureBlock extends StatelessWidget {
  final String reason;

  const _FailureBlock({required this.reason});

  @override
  Widget build(BuildContext context) {
    final reasonEnum = FailureReason.fromString(reason);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusFailedBg,
        borderRadius: AppRadius.rLg,
        border: Border.all(
          color: AppColors.accentDanger.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.accentDanger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivo del fallo',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accentDanger,
                  ),
                ),
                const SizedBox(height: 6),
                Text(reasonEnum.label, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action bar ───────────────────────────────────────────────────────

class _ActionBar extends ConsumerWidget {
  final RouteStop stop;
  final bool isProcessing;
  final VoidCallback onPrimary;
  final VoidCallback onFail;
  final Future<void> Function(RouteStop, WorkflowState) onWorkflowTransition;

  const _ActionBar({
    required this.stop,
    required this.isProcessing,
    required this.onPrimary,
    required this.onFail,
    required this.onWorkflowTransition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wfState = ref.watch(workflowProvider);
    if (wfState.hasStates) {
      // Try to render dynamic workflow buttons; fall back to hardcoded
      // if no transitions are available.
      final notifier = ref.read(workflowProvider.notifier);
      final current = stop.workflowStateId != null
          ? notifier.findById(stop.workflowStateId!)
          : notifier.findBySystemState(stop.status.value);
      if (current != null) {
        final transitions = notifier.getAvailableTransitions(current.id);
        if (transitions.isNotEmpty) {
          final sorted = [...transitions]..sort((a, b) {
              if (a.isTerminal == b.isTerminal) {
                return a.position.compareTo(b.position);
              }
              return a.isTerminal ? 1 : -1;
            });
          return _DynamicBar(
            transitions: sorted,
            isProcessing: isProcessing,
            onTap: (target) => onWorkflowTransition(stop, target),
          );
        }
      }
    }

    // Hardcoded fallback (PENDING → IN_PROGRESS → COMPLETED/FAILED)
    return _HardcodedBar(
      stop: stop,
      isProcessing: isProcessing,
      onPrimary: onPrimary,
      onFail: onFail,
    );
  }
}

class _DynamicBar extends StatelessWidget {
  final List<WorkflowState> transitions;
  final bool isProcessing;
  final void Function(WorkflowState) onTap;

  const _DynamicBar({
    required this.transitions,
    required this.isProcessing,
    required this.onTap,
  });

  IconData _icon(String state) {
    switch (state) {
      case 'PENDING':
        return Icons.schedule_rounded;
      case 'IN_PROGRESS':
        return Icons.play_arrow_rounded;
      case 'COMPLETED':
        return Icons.check_rounded;
      case 'FAILED':
        return Icons.close_rounded;
      case 'CANCELLED':
        return Icons.skip_next_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  AppButtonVariant _variant(WorkflowState state, bool isPrimary) {
    if (state.isFailed || state.isCancelled) return AppButtonVariant.destructive;
    if (state.systemState == 'COMPLETED') return AppButtonVariant.live;
    return isPrimary ? AppButtonVariant.primary : AppButtonVariant.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final primary = transitions.first;
    final secondaries = transitions.skip(1).toList();
    return _BarShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: primary.label,
            icon: _icon(primary.systemState),
            variant: _variant(primary, true),
            size: AppButtonSize.xl,
            fullWidth: true,
            isLoading: isProcessing,
            onPressed: () => onTap(primary),
          ),
          for (final t in secondaries) ...[
            const SizedBox(height: 10),
            AppButton(
              label: t.label,
              icon: _icon(t.systemState),
              variant: _variant(t, false),
              size: AppButtonSize.lg,
              fullWidth: true,
              onPressed: isProcessing ? null : () => onTap(t),
            ),
          ],
        ],
      ),
    );
  }
}

class _HardcodedBar extends StatelessWidget {
  final RouteStop stop;
  final bool isProcessing;
  final VoidCallback onPrimary;
  final VoidCallback onFail;

  const _HardcodedBar({
    required this.stop,
    required this.isProcessing,
    required this.onPrimary,
    required this.onFail,
  });

  @override
  Widget build(BuildContext context) {
    final inProgress = stop.status.isInProgress;
    return _BarShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: inProgress ? 'Completar entrega' : 'Iniciar entrega',
            icon: inProgress
                ? Icons.check_rounded
                : Icons.play_arrow_rounded,
            variant: inProgress
                ? AppButtonVariant.live
                : AppButtonVariant.primary,
            size: AppButtonSize.xl,
            fullWidth: true,
            isLoading: isProcessing,
            onPressed: onPrimary,
          ),
          if (inProgress) ...[
            const SizedBox(height: 10),
            AppButton(
              label: 'No se pudo entregar',
              icon: Icons.close_rounded,
              variant: AppButtonVariant.destructive,
              size: AppButtonSize.lg,
              fullWidth: true,
              onPressed: isProcessing ? null : onFail,
            ),
          ],
        ],
      ),
    );
  }
}

class _BarShell extends StatelessWidget {
  final Widget child;

  const _BarShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgBase,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: child,
        ),
      ),
    );
  }
}

class _CompletedBar extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback onBack;

  const _CompletedBar({required this.stop, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isCompleted = stop.status == StopStatus.completed;
    final isFailed = stop.status == StopStatus.failed;
    final color = isCompleted
        ? AppColors.accentLive
        : isFailed
            ? AppColors.accentDanger
            : AppColors.fgTertiary;
    final bg = isCompleted
        ? AppColors.statusCompletedBg
        : isFailed
            ? AppColors.statusFailedBg
            : AppColors.statusSkippedBg;
    final icon = isCompleted
        ? Icons.check_circle_rounded
        : isFailed
            ? Icons.cancel_rounded
            : Icons.skip_next_rounded;
    final label = stop.workflowStateLabel ??
        (isCompleted
            ? 'Entrega completada'
            : isFailed
                ? 'Entrega fallida'
                : 'Parada omitida');

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(color: color),
                ),
              ),
              AppButton(
                label: 'Volver',
                variant: AppButtonVariant.ghost,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Misc helpers ─────────────────────────────────────────────────────

class _IconBubble extends StatelessWidget {
  final IconData icon;

  const _IconBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: AppRadius.rMd,
      ),
      child: Icon(icon, size: 16, color: AppColors.fgSecondary),
    );
  }
}

// ── Workflow transition sheet (preserved, with cockpit chrome) ───────

/// Modal sheet for collecting required data (photo / reason / notes)
/// before transitioning to a workflow state. Logic is preserved from the
/// previous implementation; the chrome is rebuilt to match the cockpit.
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
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (photo != null) setState(() => _photos.add(File(photo.path)));
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
    if (!_canConfirm) return;
    widget.onConfirm(
      _photos,
      _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      _selectedReason,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFailed = widget.targetState.isFailed || widget.targetState.isCancelled;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isFailed
                              ? AppColors.statusFailedBg
                              : AppColors.statusInProgressBg,
                          borderRadius: AppRadius.rMd,
                        ),
                        child: Icon(
                          isFailed
                              ? Icons.close_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                          color: isFailed
                              ? AppColors.accentDanger
                              : AppColors.accentLive,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.targetState.label, style: AppTypography.h4),
                            Text(
                              widget.stop.displayName,
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_needsReason &&
                        _reasonOptions != null &&
                        _reasonOptions!.isNotEmpty) ...[
                      Text('Motivo', style: AppTypography.label),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _reasonOptions!.map((reason) {
                          final selected = _selectedReason == reason;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedReason = reason),
                            child: AnimatedContainer(
                              duration: AppMotion.fast,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.fgPrimary
                                    : AppColors.bgSurface,
                                borderRadius: AppRadius.rFull,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.fgPrimary
                                      : AppColors.borderSubtle,
                                ),
                              ),
                              child: Text(
                                reason,
                                style: AppTypography.label.copyWith(
                                  color: selected
                                      ? AppColors.fgInverse
                                      : AppColors.fgPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (_needsPhoto) ...[
                      Text('Foto de evidencia', style: AppTypography.label),
                      const SizedBox(height: 8),
                      _photos.isNotEmpty
                          ? SizedBox(
                              height: 88,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _photos.length + 1,
                                itemBuilder: (context, i) {
                                  if (i == _photos.length) {
                                    return _AddPhotoButton(onTap: _takePhoto);
                                  }
                                  return _PhotoThumb(
                                    file: _photos[i],
                                    onRemove: () => _removePhoto(i),
                                  );
                                },
                              ),
                            )
                          : GestureDetector(
                              onTap: _takePhoto,
                              child: Container(
                                height: 88,
                                decoration: BoxDecoration(
                                  color: AppColors.bgSurface,
                                  borderRadius: AppRadius.rLg,
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: _isCapturing
                                    ? const Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.fgPrimary,
                                          ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 18,
                                            color: AppColors.fgPrimary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Tomar foto',
                                            style: AppTypography.button,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      _needsNotes ? 'Notas' : 'Notas (opcional)',
                      style: AppTypography.label,
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _notesController,
                      placeholder: 'Agregá detalles relevantes…',
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: AppButton(
                label: 'Confirmar',
                variant: isFailed
                    ? AppButtonVariant.destructive
                    : AppButtonVariant.primary,
                size: AppButtonSize.lg,
                fullWidth: true,
                onPressed: _canConfirm ? _confirm : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _PhotoThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: AppRadius.rMd,
            child: Image.file(
              file,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.accentDanger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
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
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Icon(
          Icons.add_a_photo_rounded,
          size: 20,
          color: AppColors.fgSecondary,
        ),
      ),
    );
  }
}

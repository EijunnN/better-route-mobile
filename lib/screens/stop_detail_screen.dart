import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/design/tokens.dart';
import '../models/route_stop.dart';
import '../models/workflow_state.dart';
import '../providers/providers.dart';
import '../router/router.dart';
import '../widgets/sheets/sheets.dart';
import 'stop_detail/widgets/widgets.dart';

/// Stop detail — driver's working surface for one stop.
///
/// The screen is composed of small section widgets exported from
/// `stop_detail/widgets/`. This file owns the shell (Scaffold layout +
/// scroll) and the handlers (start, complete, fail, workflow). Visual
/// pieces don't know about the providers; the screen wires data and
/// callbacks into them.
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
              StopDetailTopBar(
                onBack: () => context.pop(),
                trailing: const SizedBox(),
              ),
              const Spacer(),
              Center(
                child: Text(
                  'Parada no encontrada',
                  style: AppTypography.body
                      .copyWith(color: AppColors.fgSecondary),
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
            StopDetailTopBar(
              onBack: () => context.pop(),
              // Quick path to chat from a stop — drivers often need to
              // ask dispatch about THIS delivery (cliente ausente,
              // dirección incorrecta), so the entry point belongs in
              // the stop's own chrome.
              trailing: CircleAction(
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => context.push(AppRoutes.chat),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StopDetailHero(
                      stop: currentStop,
                      onCopyTracking: () => _copyTrackingId(currentStop),
                    ),
                    const SizedBox(height: 20),
                    if (currentStop.timeWindow?.hasWindow == true) ...[
                      TimeWindowBlock(stop: currentStop),
                      const SizedBox(height: 12),
                    ],
                    StopDetailReceipt(
                      stop: currentStop,
                      onCall: _callPhone,
                      onMaps: () => _openNavigation(currentStop),
                      onWaze: () => _openWaze(currentStop),
                    ),
                    if (currentStop.order != null &&
                        currentStop.order!.hasCustomFields) ...[
                      const SizedBox(height: 12),
                      OrderCustomFieldsBlock(stop: currentStop),
                    ],
                    if (currentStop.order?.notes != null &&
                        currentStop.order!.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      NotesBlock(notes: currentStop.order!.notes!),
                    ],
                    if (currentStop.failureReason != null &&
                        currentStop.status == StopStatus.failed) ...[
                      const SizedBox(height: 12),
                      FailureBlock(reason: currentStop.failureReason!),
                    ],
                  ],
                ),
              ),
            ),
            currentStop.status.isDone
                ? StopDetailCompletedBar(
                    stop: currentStop,
                    onBack: () => context.pop(),
                  )
                : StopDetailActionBar(
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

  // ── Handlers ─────────────────────────────────────────────────────

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
    await ref.read(locationProvider.notifier).navigateTo(s.latitude, s.longitude);
  }

  Future<void> _openWaze(RouteStop s) async {
    await ref.read(locationProvider.notifier).openWaze(s.latitude, s.longitude);
  }

  Future<void> _handleDeliveryAction(RouteStop s) async {
    if (s.status.isPending) {
      setState(() => _isProcessing = true);
      final success = await ref.read(routeProvider.notifier).startStop(s.id);
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

      // Upload all photos first. If any one fails, abort the whole
      // completion flow — the previous behaviour was to silently
      // discard the failed upload and mark the stop COMPLETED with
      // empty evidence, leaving the customer with a "delivered"
      // status and no proof of delivery.
      for (int i = 0; i < photos.length; i++) {
        try {
          final url = await ref.read(routeProvider.notifier).uploadEvidence(
                photo: photos[i],
                trackingId: trackingId,
                index: i + 1,
              );
          evidenceUrls.add(url);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo subir la foto ${i + 1}. $e'),
              duration: const Duration(seconds: 6),
            ),
          );
          return;
        }
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
      if (mounted) setState(() => _isProcessing = false);
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
          try {
            final url = await ref.read(routeProvider.notifier).uploadEvidence(
                  photo: result.photos[i],
                  trackingId: trackingId,
                  index: i + 1,
                );
            evidenceUrls.add(url);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No se pudo subir la foto ${i + 1}. $e'),
                duration: const Duration(seconds: 6),
              ),
            );
            return;
          }
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
      builder: (context) => WorkflowTransitionSheet(
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
          try {
            final url = await ref.read(routeProvider.notifier).uploadEvidence(
                  photo: photos[i],
                  trackingId: trackingId,
                  index: i + 1,
                );
            evidenceUrls.add(url);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No se pudo subir la foto ${i + 1}. $e'),
                duration: const Duration(seconds: 6),
              ),
            );
            return;
          }
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

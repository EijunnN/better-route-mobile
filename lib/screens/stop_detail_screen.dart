import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/design/tokens.dart';
import '../models/pending_close.dart';
import '../models/route_stop.dart';
import '../models/workflow_state.dart';
import '../providers/providers.dart';
import '../router/router.dart';
import '../services/location_service.dart';
import '../services/offline_outbox.dart';
import '../widgets/sheets/sheets.dart';
import 'stop_detail/widgets/widgets.dart';

/// Stop detail — driver's working surface for one stop (rediseño).
///
/// Spec: `Mobile - Specs.html` § 07 / 04 · Stop detail (D2). Layout:
///
///   [220h map peek + ETA badge + back/chat overlay + nav pills]
///   Hero  : status pill · sequence · time window   — address h1 26
///   Cliente card (avatar + name + phone + Llamar/WhatsApp/Copy)
///   Detalles 2×2 grid (Bultos / Peso / Tracking / OC)
///   Nota despacho (amber callout, only if notes)
///   Capture preview (dashed, only if pending)
///   [Action bar: No entregó (danger) / Confirmar (primary lime)]
///
/// Handlers preserve the previous workflow logic verbatim — start /
/// complete / fail / workflow transition + photo upload. Only the
/// visual shell changed.
class StopDetailScreen extends ConsumerStatefulWidget {
  final String stopId;

  const StopDetailScreen({super.key, required this.stopId});

  @override
  ConsumerState<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends ConsumerState<StopDetailScreen> {
  bool _isProcessing = false;

  RouteStop? get _stopMaybe => ref.watch(stopByIdProvider(widget.stopId));

  @override
  Widget build(BuildContext context) {
    final stop = _stopMaybe;

    if (stop == null) {
      return _NotFound(onBack: () => context.pop());
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _MapPeekHeader(
              stop: stop,
              onBack: () => context.pop(),
              onChat: () => context.push(AppRoutes.chat),
              onNavigate: () => _openNavigation(stop),
              onWaze: () => _openWaze(stop),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroBlock(stop: stop),
                    if (stop.order?.customerName != null) ...[
                      const SizedBox(height: 14),
                      _SectionLabel('Cliente'),
                      const SizedBox(height: 8),
                      _CustomerCard(
                        name: stop.order!.customerName!,
                        phone: stop.order?.customerPhone,
                        onCall: stop.order?.customerPhone != null
                            ? () => _callPhone(stop.order!.customerPhone!)
                            : null,
                        onWhatsApp: stop.order?.customerPhone != null
                            ? () => _openWhatsApp(stop.order!.customerPhone!)
                            : null,
                        onCopy: stop.order?.customerPhone != null
                            ? () => _copyText(
                                stop.order!.customerPhone!,
                                'Teléfono copiado',
                              )
                            : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _SectionLabel('Detalles del pedido'),
                    const SizedBox(height: 8),
                    _OrderDetailsGrid(
                      stop: stop,
                      onCopyTracking: () =>
                          _copyText(stop.trackingDisplay, 'Tracking copiado'),
                    ),
                    if (stop.order?.notes != null &&
                        stop.order!.notes!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _DispatchNote(text: stop.order!.notes!),
                    ],
                    if (stop.order?.hasCustomFields == true) ...[
                      const SizedBox(height: 14),
                      OrderCustomFieldsBlock(stop: stop),
                    ],
                    if (!stop.status.isDone) ...[
                      const SizedBox(height: 14),
                      const _CapturePreview(),
                    ],
                    if (stop.failureReason != null &&
                        stop.status == StopStatus.failed) ...[
                      const SizedBox(height: 14),
                      FailureBlock(reason: stop.failureReason!),
                    ],
                  ],
                ),
              ),
            ),
            stop.status.isDone
                ? StopDetailCompletedBar(
                    stop: stop,
                    onBack: () => context.pop(),
                  )
                : StopDetailActionBar(
                    stop: stop,
                    isProcessing: _isProcessing,
                    onPrimary: () => _handleDeliveryAction(stop),
                    onFail: () => _handleFailure(stop),
                    onWorkflowTransition: _handleWorkflowTransition,
                  ),
          ],
        ),
      ),
    );
  }

  // ── Handlers (unchanged from previous screen) ────────────────────

  void _copyText(String text, String snack) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snack), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    // Strip everything that isn't a digit so WhatsApp accepts the URL.
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openNavigation(RouteStop s) async {
    await ref
        .read(locationProvider.notifier)
        .navigateTo(s.latitude, s.longitude);
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

  /// Best-effort device GPS at closing time, for the audit trail. The GPS
  /// chip works without network, so we prefer the last cached fix and only
  /// fall back to a single live read if there's none. Never throws and never
  /// blocks the closing flow: returns (null, null) when no fix is available.
  Future<({String? lat, String? lng})> _captureClosingGps() async {
    final service = LocationService();
    var fix = service.lastLocation;
    if (fix == null) {
      try {
        fix = await service.getCurrentLocation();
      } catch (_) {
        fix = null;
      }
    }
    if (fix == null) return (lat: null, lng: null);
    return (lat: fix.latitude.toString(), lng: fix.longitude.toString());
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
      // Outbox-first: persist the close (status + photos + gps) locally, then
      // try to sync. In a no-signal zone the close survives and uploads later,
      // so the driver is never blocked. Evidence is uploaded by the outbox.
      final gps = await _captureClosingGps();
      final entry = PendingClose(
        id: s.id,
        stopId: s.id,
        trackingId: s.order?.trackingId ?? s.id,
        status: StopStatus.completed.value,
        notes: notes,
        customFields: customFields.isEmpty ? null : customFields,
        gpsLatitude: gps.lat,
        gpsLongitude: gps.lng,
        photoPaths: photos.map((f) => f.path).toList(),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final result = await OfflineOutbox().submitClose(entry);
      if (!mounted) return;
      if (result == OutboxResult.queued) {
        // Offline: optimistically mark the stop done + reassure the driver.
        ref
            .read(routeProvider.notifier)
            .applyLocalClose(
              stopId: s.id,
              status: StopStatus.completed,
              notes: notes,
              customFields: customFields.isEmpty ? null : customFields,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin señal: la entrega se guardó y se enviará al recuperar conexión.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        // Synced — pull server truth before showing the confirmation.
        await ref.read(routeProvider.notifier).refresh();
      }
      if (mounted) context.push(AppRoutes.successPath(s.id));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleFailure(RouteStop s) async {
    // Reason options + evidence gates come from the company delivery
    // policy (surfaced through the FAILED workflow state). The driver
    // picks one of those exact Spanish strings; we send it verbatim.
    final failedState = ref
        .read(workflowProvider.notifier)
        .findBySystemState(StopStatus.failed.value);
    final reasons = failedState?.reasonOptions ?? const <String>[];
    final requiresNotes = failedState?.requiresNotes ?? false;

    final result = await showModalBottomSheet<FailureResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FailureReasonSheet(
        stop: s,
        reasons: reasons,
        requiresNotes: requiresNotes,
      ),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);
    try {
      // Outbox-first (same as completion): the failure report survives a
      // no-signal zone and syncs later. `result.reason` is the verbatim
      // per-company policy string the driver picked.
      final gps = await _captureClosingGps();
      final entry = PendingClose(
        id: s.id,
        stopId: s.id,
        trackingId: s.order?.trackingId ?? s.id,
        status: StopStatus.failed.value,
        failureReason: result.reason,
        notes: result.notes,
        gpsLatitude: gps.lat,
        gpsLongitude: gps.lng,
        photoPaths: result.photos.map((f) => f.path).toList(),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final outcome = await OfflineOutbox().submitClose(entry);
      if (!mounted) return;
      if (outcome == OutboxResult.queued) {
        ref
            .read(routeProvider.notifier)
            .applyLocalClose(
              stopId: s.id,
              status: StopStatus.failed,
              failureReason: result.reason,
              notes: result.notes,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin señal: el reporte se guardó y se enviará al recuperar conexión.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        await ref.read(routeProvider.notifier).refresh();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Cierre terminal (COMPLETED/FAILED) vía outbox: se persiste local con
  /// las RUTAS de las fotos (no URLs) y se intenta sincronizar. Sin señal,
  /// el outbox sube fotos + cierre cuando vuelva la conexión — el driver
  /// nunca se bloquea por un DioException de red.
  Future<void> _closeViaOutbox(
    RouteStop s, {
    required String status,
    List<File> photos = const [],
    String? notes,
    String? reason,
    Map<String, dynamic>? customFields,
  }) async {
    final gps = await _captureClosingGps();
    final entry = PendingClose(
      id: s.id,
      stopId: s.id,
      trackingId: s.order?.trackingId ?? s.id,
      status: status,
      failureReason: reason,
      notes: notes,
      customFields: customFields,
      gpsLatitude: gps.lat,
      gpsLongitude: gps.lng,
      photoPaths: photos.map((f) => f.path).toList(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final OutboxResult outcome;
    try {
      outcome = await OfflineOutbox().submitClose(entry);
    } on MissingFailureReasonException catch (e) {
      // Backstop del gate FIX-2 — las vías de UI ya exigen motivo, pero si
      // algo se lo saltó, avisamos en vez de perder el cierre en silencio.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    }
    if (!mounted) return;
    if (outcome == OutboxResult.queued) {
      ref
          .read(routeProvider.notifier)
          .applyLocalClose(
            stopId: s.id,
            status: status == StopStatus.completed.value
                ? StopStatus.completed
                : StopStatus.failed,
            failureReason: reason,
            notes: notes,
            customFields: customFields,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sin señal: el cierre se guardó y se enviará al recuperar conexión.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } else {
      await ref.read(routeProvider.notifier).refresh();
    }
  }

  bool _isTerminalState(WorkflowState state) =>
      state.systemState == StopStatus.completed.value ||
      state.systemState == StopStatus.failed.value;

  Future<void> _handleWorkflowTransition(
    RouteStop s,
    WorkflowState targetState,
  ) async {
    final needsPhoto = targetState.requiresPhoto;
    // FIX-2: un FAILED con motivos en la policy exige motivo aunque el flag
    // `requiresReason` no venga seteado — sin motivo el cierre encolado
    // muere en el drain (400 → drop) y el reporte se pierde.
    final needsReason = targetState.requiresReason ||
        (targetState.isFailed &&
            (targetState.reasonOptions?.isNotEmpty ?? false));
    final needsNotes = targetState.requiresNotes;

    if (needsPhoto || needsReason || needsNotes) {
      _showWorkflowActionSheet(s, targetState);
      return;
    }

    // Terminales sin extras → outbox (sobreviven sin señal).
    if (_isTerminalState(targetState)) {
      setState(() => _isProcessing = true);
      try {
        await _closeViaOutbox(s, status: targetState.systemState);
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
      return;
    }

    setState(() => _isProcessing = true);
    final success = await ref
        .read(routeProvider.notifier)
        .transitionStop(
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
      // Terminales → outbox-first: las fotos van como rutas locales y el
      // outbox las sube al sincronizar. Antes este camino subía las fotos
      // online-only y abortaba sin señal ("No se pudo subir la foto…").
      if (_isTerminalState(targetState)) {
        await _closeViaOutbox(
          s,
          status: targetState.systemState,
          photos: photos,
          notes: notes,
          reason: reason,
        );
        return;
      }

      // No-terminales (raros con fotos): flujo online original.
      final evidenceUrls = <String>[];
      if (photos.isNotEmpty) {
        final trackingId = s.order?.trackingId ?? s.id;
        for (int i = 0; i < photos.length; i++) {
          try {
            final url = await ref
                .read(routeProvider.notifier)
                .uploadEvidence(
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
      final success = await ref
          .read(routeProvider.notifier)
          .transitionStop(
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Map peek header — 220h with ETA badge, back/chat overlay, nav pills.
// ─────────────────────────────────────────────────────────────────────

class _MapPeekHeader extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback onBack;
  final VoidCallback onChat;
  final VoidCallback onNavigate;
  final VoidCallback onWaze;

  const _MapPeekHeader({
    required this.stop,
    required this.onBack,
    required this.onChat,
    required this.onNavigate,
    required this.onWaze,
  });

  @override
  Widget build(BuildContext context) {
    final etaLabel = _formatEta(stop);

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _StopMapPainter(stop: stop)),
          ),
          // Bottom-fade.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 60,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bgBase.withValues(alpha: 0.0),
                      AppColors.bgBase,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Back button (top-left).
          Positioned(
            top: 14,
            left: 14,
            child: _GlassIcon(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
          ),
          // Chat button (top-right).
          Positioned(
            top: 14,
            right: 14,
            child: _GlassIcon(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: onChat,
            ),
          ),
          // ETA badge (top-centre).
          if (etaLabel != null)
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(child: _EtaBadge(label: etaLabel)),
            ),
          // Navigation pills (bottom-centre).
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavPill(
                    label: 'Navegar',
                    icon: Icons.navigation_rounded,
                    primary: true,
                    onTap: onNavigate,
                  ),
                  const SizedBox(width: 8),
                  _NavPill(
                    label: 'Waze',
                    icon: Icons.explore_outlined,
                    primary: false,
                    onTap: onWaze,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _formatEta(RouteStop s) {
    // El ETA en vivo (posición real del driver) manda; el fin de la
    // ventana horaria queda como fallback para planes sin recálculo.
    final eta = s.liveEtaAt ?? s.timeWindow?.end;
    if (eta == null) return null;
    final local = eta.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return s.liveEtaAt != null ? 'ETA $hh:$mm · en vivo' : 'ETA $hh:$mm';
  }
}

class _StopMapPainter extends CustomPainter {
  final RouteStop stop;
  const _StopMapPainter({required this.stop});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bgBase);
    // Radial glow around the stop's "centre".
    final centre = Offset(size.width / 2, size.height * 0.45);
    final radius = size.width * 0.55;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.lime.withValues(alpha: 0.18),
            AppColors.lime.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
    // Grid.
    final grid = Paint()
      ..color = AppColors.borderSubtle.withValues(alpha: 0.5)
      ..strokeWidth = 0.7;
    const step = 36.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // Single white-with-dark-border marker for the stop.
    canvas.drawCircle(centre, 11, Paint()..color = AppColors.fgPrimary);
    canvas.drawCircle(
      centre,
      11,
      Paint()
        ..color = AppColors.bgBase
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Sequence numeral on top.
    final tp = TextPainter(
      text: TextSpan(
        text: '${stop.sequence}',
        style: AppTypography.mono.copyWith(
          color: AppColors.bgBase,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(centre.dx - tp.width / 2, centre.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _StopMapPainter old) =>
      !identical(old.stop, stop);
}

class _GlassIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: AppColors.fgPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _EtaBadge extends StatefulWidget {
  final String label;
  const _EtaBadge({required this.label});

  @override
  State<_EtaBadge> createState() => _EtaBadgeState();
}

class _EtaBadgeState extends State<_EtaBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = _pulse.value;
                  return SizedBox(
                    width: 14,
                    height: 14,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 6 + 8 * t,
                          height: 6 + 8 * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.lime.withValues(
                              alpha: (0.55 * (1 - t)).clamp(0.0, 1.0),
                            ),
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.lime,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTypography.label.copyWith(
                  color: AppColors.fgPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _NavPill({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: primary ? 18 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: primary
                ? AppColors.lime
                : Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
            border: primary
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: primary ? AppColors.fgInverse : AppColors.fgPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: primary ? AppColors.fgInverse : AppColors.fgPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (primary) return btn;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: btn,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hero block — status pill + sequence + window in a row, then address.
// ─────────────────────────────────────────────────────────────────────

class _HeroBlock extends StatelessWidget {
  final RouteStop stop;
  const _HeroBlock({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SequenceBadge(seq: stop.sequence, status: stop.status),
            const SizedBox(width: 8),
            _StatusChip(status: stop.status),
            if (stop.timeWindow?.hasWindow == true) ...[
              const SizedBox(width: 8),
              _TimeWindowChip(label: stop.timeWindow!.displayText),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          stop.address,
          style: AppTypography.h1.copyWith(
            fontSize: 26,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _SequenceBadge extends StatelessWidget {
  final int seq;
  final StopStatus status;
  const _SequenceBadge({required this.seq, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    Widget? icon;
    if (status.isCompleted) {
      bg = AppColors.lime;
      fg = AppColors.fgInverse;
      icon = const Icon(Icons.check, size: 14, color: AppColors.fgInverse);
    } else if (status.isFailed) {
      bg = AppColors.danger;
      // Black on coral (6.75:1), mirroring the completed branch — light grey
      // on coral fails WCAG AA (2.58:1).
      fg = AppColors.fgInverse;
      icon = const Icon(Icons.close, size: 14, color: AppColors.fgInverse);
    } else if (status.isInProgress) {
      bg = AppColors.fgPrimary;
      fg = AppColors.bgBase;
    } else {
      bg = Colors.transparent;
      fg = AppColors.fgPrimary;
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: status.isPending
            ? Border.all(color: AppColors.borderStrong, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child:
          icon ??
          Text(
            '$seq',
            style: AppTypography.mono.copyWith(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final StopStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      StopStatus.pending => (
        'Pendiente',
        AppColors.bgSurfaceElevated,
        AppColors.fgSecondary,
      ),
      StopStatus.inProgress => ('En curso', AppColors.limeSoft, AppColors.lime),
      StopStatus.completed => ('Entregado', AppColors.limeSoft, AppColors.lime),
      StopStatus.failed => (
        'No entregó',
        AppColors.dangerSoft,
        AppColors.danger,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeWindowChip extends StatelessWidget {
  final String label;
  const _TimeWindowChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 11,
            color: AppColors.fgSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.mono.copyWith(
              color: AppColors.fgSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Customer card — avatar + name + phone + 3 action buttons.
// ─────────────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final String name;
  final String? phone;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onCopy;

  const _CustomerCard({
    required this.name,
    required this.phone,
    required this.onCall,
    required this.onWhatsApp,
    required this.onCopy,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '··';
    final first = parts.first[0].toUpperCase();
    final second = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1][0].toUpperCase()
        : '';
    return '$first$second';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceElevated,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: AppTypography.label.copyWith(
                    color: AppColors.fgSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone!,
                        style: AppTypography.mono.copyWith(
                          color: AppColors.fgTertiary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onCall != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ContactButton(
                    label: 'Llamar',
                    icon: Icons.phone_rounded,
                    onTap: onCall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ContactButton(
                    label: 'WhatsApp',
                    icon: Icons.chat_rounded,
                    onTap: onWhatsApp,
                  ),
                ),
                const SizedBox(width: 8),
                _ContactButton(
                  icon: Icons.copy_rounded,
                  onTap: onCopy,
                  width: 44,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final String? label;
  final IconData icon;
  final VoidCallback? onTap;
  final double? width;

  const _ContactButton({
    this.label,
    required this.icon,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.bgSurfaceElevated,
        borderRadius: AppRadius.rMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.rMd,
          child: Container(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
            decoration: BoxDecoration(
              borderRadius: AppRadius.rMd,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: AppColors.fgPrimary),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: AppTypography.label.copyWith(
                      color: AppColors.fgPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Order details — 2×2 grid card (Bultos / Peso / Tracking / OC).
// ─────────────────────────────────────────────────────────────────────

class _OrderDetailsGrid extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback onCopyTracking;

  const _OrderDetailsGrid({required this.stop, required this.onCopyTracking});

  @override
  Widget build(BuildContext context) {
    final units = stop.order?.units;
    final weight = stop.order?.weight;
    final tracking = stop.trackingDisplay;
    final oc =
        stop.order?.customFields['oc_cliente'] ??
        stop.order?.customFields['oc'];

    final cells = <_MetaCellSpec>[
      _MetaCellSpec(
        label: 'Bultos',
        value: units != null ? '$units bulto${units == 1 ? "" : "s"}' : '—',
        icon: Icons.inventory_2_outlined,
      ),
      _MetaCellSpec(
        label: 'Peso',
        value: weight != null ? '${weight.toStringAsFixed(1)} kg' : '—',
        icon: Icons.scale_rounded,
        mono: true,
      ),
      _MetaCellSpec(
        label: 'Tracking',
        value: tracking,
        icon: Icons.qr_code_2_rounded,
        mono: true,
        onTap: onCopyTracking,
      ),
      if (oc != null)
        _MetaCellSpec(
          label: 'OC del cliente',
          value: '$oc',
          icon: Icons.tag_rounded,
          mono: true,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        children: [
          for (var rowIdx = 0; rowIdx < (cells.length + 1) ~/ 2; rowIdx++)
            Row(
              children: [
                Expanded(child: _MetaCell(spec: cells[rowIdx * 2])),
                Container(width: 1, height: 56, color: AppColors.borderSubtle),
                Expanded(
                  child: rowIdx * 2 + 1 < cells.length
                      ? _MetaCell(spec: cells[rowIdx * 2 + 1])
                      : const SizedBox(height: 56),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MetaCellSpec {
  final String label;
  final String value;
  final IconData icon;
  final bool mono;
  final VoidCallback? onTap;

  const _MetaCellSpec({
    required this.label,
    required this.value,
    required this.icon,
    this.mono = false,
    this.onTap,
  });
}

class _MetaCell extends StatelessWidget {
  final _MetaCellSpec spec;
  const _MetaCell({required this.spec});

  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 11, color: AppColors.fgTertiary),
              const SizedBox(width: 6),
              Text(
                spec.label.toUpperCase(),
                style: AppTypography.label.copyWith(
                  color: AppColors.fgTertiary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            spec.value,
            overflow: TextOverflow.ellipsis,
            style: (spec.mono ? AppTypography.mono : AppTypography.bodyMedium)
                .copyWith(
                  color: AppColors.fgPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
    if (spec.onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: spec.onTap, child: inner),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Dispatch note — amber callout with the note text.
// ─────────────────────────────────────────────────────────────────────

class _DispatchNote extends StatelessWidget {
  final String text;
  const _DispatchNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTA DEL DESPACHO',
          style: AppTypography.label.copyWith(
            color: AppColors.warning,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: AppRadius.rMd,
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: AppColors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.body.copyWith(
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Capture preview — dashed card with "AL CERRAR VAS A LLENAR" overline.
// ─────────────────────────────────────────────────────────────────────

class _CapturePreview extends StatelessWidget {
  const _CapturePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.borderStrong, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AL CERRAR VAS A LLENAR',
            style: AppTypography.label.copyWith(
              color: AppColors.fgTertiary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              _PreviewChip(
                icon: Icons.camera_alt_outlined,
                label: '0 / 3 fotos',
              ),
              _PreviewChip(icon: Icons.person_outline, label: 'Quién recibió'),
              _PreviewChip(
                icon: Icons.check_circle_outline,
                label: 'Confirmación',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PreviewChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.fgSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.fgSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.label.copyWith(
        color: AppColors.fgTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  final VoidCallback onBack;
  const _NotFound({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _GlassIcon(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                'Parada no encontrada',
                style: AppTypography.body.copyWith(
                  color: AppColors.fgSecondary,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

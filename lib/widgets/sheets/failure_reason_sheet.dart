import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/design/tokens.dart';
import '../../models/models.dart';
import '../app/app.dart';
import '../shared/shared.dart';

/// Result of the failure sheet. [reason] is the exact per-company policy
/// string the driver picked (verbatim — never a code). Null only when the
/// policy exposes no reasons (cold start offline / list cleared by the
/// operator), mirroring the outbox gate (spec §4).
typedef FailureResult = ({
  String? reason,
  String? notes,
  List<File> photos,
});

/// Failure reason sheet (rediseño).
///
/// Spec: `Mobile - Specs.html` § 07 / 10 · Reportar fallo (mirrors the
/// design's `MobReportarFallo`). The visual:
///
///   • Danger overline "NO SE PUDO ENTREGAR" + h3 "¿Qué pasó?"
///   • Stop summary chip
///   • Inline radio-card list of reasons (icon + title + radio)
///   • Optional evidence row (foto, dashed)
///   • Optional notes textarea
///   • Amber callout explaining the re-attempt behaviour
///   • Action bar: Cancelar (secondary) + Reportar fallo (danger)
///
/// The reason options are ALWAYS the per-company failure-reason strings
/// from the delivery policy (`GET /api/mobile/driver/delivery-policy` →
/// `policy.failureReasons`), surfaced here via [reasons]. The selected
/// option is returned verbatim so the PATCH stores the exact policy
/// string the backend advertised — no hard-coded enum, no code mapping.
class FailureReasonSheet extends StatefulWidget {
  final RouteStop stop;

  /// Per-company failure reasons from the delivery policy. The legacy
  /// caller passes the FAILED workflow state's `reasonOptions`; the
  /// workflow-transition caller passes the target state's `reasonOptions`.
  final List<String> reasons;

  /// Whether notes are mandatory (policy `failedRequiresNotes`).
  final bool requiresNotes;

  const FailureReasonSheet({
    super.key,
    required this.stop,
    required this.reasons,
    this.requiresNotes = false,
  });

  @override
  State<FailureReasonSheet> createState() => _FailureReasonSheetState();
}

class _FailureReasonSheetState extends State<FailureReasonSheet> {
  String? _selectedReason;
  final _notesController = TextEditingController();
  final List<File> _photos = [];
  final _picker = ImagePicker();
  bool _isCapturing = false;

  bool get _hasSelection => _selectedReason != null;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_isCapturing) return;
    HapticFeedback.lightImpact();
    setState(() => _isCapturing = true);
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (photo != null) setState(() => _photos.add(File(photo.path)));
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _confirm() {
    // Sin motivos en la policy (cold start offline / lista vacía) el gate se
    // apaga — igual que el gate del outbox (spec §4). Exigir selección acá
    // dejaría al driver sin poder reportar el fallo.
    if (!_hasSelection && widget.reasons.isNotEmpty) {
      _alert('Motivo requerido', 'Seleccioná un motivo para continuar.');
      return;
    }
    if (widget.requiresNotes && _notesController.text.trim().isEmpty) {
      _alert('Notas requeridas', 'Este estado requiere agregar una nota.');
      return;
    }
    final FailureResult result = (
      reason: _selectedReason,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      photos: _photos,
    );
    Navigator.pop(context, result);
  }

  void _alert(String title, String body) {
    showDialog(
      context: context,
      barrierColor: AppColors.bgOverlay,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bgSurfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.h4),
              const SizedBox(height: 6),
              Text(
                body,
                style: AppTypography.body
                    .copyWith(color: AppColors.fgSecondary),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Entendido',
                fullWidth: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NO SE PUDO ENTREGAR',
                          style: AppTypography.label.copyWith(
                            color: AppColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('¿Qué pasó?', style: AppTypography.h3),
                        const SizedBox(height: 4),
                        Text(
                          'Esto se reporta al despacho y queda en el '
                          'registro de la entrega.',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: AppColors.bgSurfaceElevated,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.fgPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stop summary.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _StopSummaryChip(stop: widget.stop),
            ),
            const SizedBox(height: 14),

            // Body — scrollable.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Reasons.
                    Text(
                      'MOTIVO',
                      style: AppTypography.label.copyWith(
                        color: AppColors.fgTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.reasons.isEmpty)
                      Text(
                        'No hay motivos configurados. Pedí al despacho que '
                        'configure los motivos de fallo en la política de '
                        'entrega.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.fgTertiary,
                        ),
                      )
                    else
                      ...widget.reasons.map(
                        (s) => _ReasonRow(
                          icon: Icons.help_outline_rounded,
                          label: s,
                          hint: '',
                          selected: s == _selectedReason,
                          onTap: () => setState(() => _selectedReason = s),
                        ),
                      ),

                    const SizedBox(height: 18),

                    // Evidence row.
                    Text(
                      'EVIDENCIA (OPCIONAL)',
                      style: AppTypography.label.copyWith(
                        color: AppColors.fgTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _EvidenceButton(
                            label: _photos.isEmpty
                                ? 'Foto del lugar'
                                : '${_photos.length} foto'
                                    '${_photos.length == 1 ? "" : "s"}',
                            icon: Icons.camera_alt_outlined,
                            busy: _isCapturing,
                            onTap: _takePhoto,
                          ),
                        ),
                      ],
                    ),
                    if (_photos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 88,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          itemBuilder: (context, i) => PhotoThumb(
                            file: _photos[i],
                            onRemove: () =>
                                setState(() => _photos.removeAt(i)),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Notes.
                    Text(
                      'NOTAS (OPCIONAL)',
                      style: AppTypography.label.copyWith(
                        color: AppColors.fgTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _notesController,
                      placeholder: 'Detalles para el despacho',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 14),

                    // Amber callout — reattempt hint.
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: AppRadius.rMd,
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.fgSecondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'El despacho puede pedirte un ',
                                  ),
                                  TextSpan(
                                    text: 'segundo intento',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.fgPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        ' más tarde. Esta parada queda en estado "reintento pendiente".',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancelar',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 16,
                    child: AppButton(
                      label: 'Reportar fallo',
                      icon: Icons.close_rounded,
                      variant: AppButtonVariant.destructive,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      onPressed: _confirm,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopSummaryChip extends StatelessWidget {
  final RouteStop stop;
  const _StopSummaryChip({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.fgPrimary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${stop.sequence}',
              style: AppTypography.mono.copyWith(
                color: AppColors.bgBase,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stop.address,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.dangerSoft : AppColors.bgSurfaceElevated,
        borderRadius: AppRadius.rMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.rMd,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              borderRadius: AppRadius.rMd,
              border: Border.all(
                color: selected
                    ? AppColors.danger.withValues(alpha: 0.5)
                    : AppColors.borderSubtle,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.danger.withValues(alpha: 0.25)
                        : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 14,
                    color: selected ? AppColors.danger : AppColors.fgSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.label.copyWith(
                          color: selected
                              ? AppColors.danger
                              : AppColors.fgPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      if (hint.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          hint,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.fgTertiary,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.danger : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppColors.danger
                          : AppColors.borderStrong,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? const SizedBox(
                          width: 6,
                          height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;

  const _EvidenceButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSurfaceElevated,
      borderRadius: AppRadius.rMd,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: AppRadius.rMd,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderStrong, width: 1),
            borderRadius: AppRadius.rMd,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: AppColors.fgSecondary,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(icon, size: 16, color: AppColors.fgSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: AppColors.fgPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

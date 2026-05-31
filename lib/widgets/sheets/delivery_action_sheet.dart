import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/design/tokens.dart';
import '../../models/models.dart';
import '../app/app.dart';
import '../custom_fields_form/custom_fields_form.dart';
import '../shared/shared.dart';

/// Confirm-delivery sheet — 3 micro-steps with a stepper.
///
/// Spec: `Mobile - Specs.html` § 07 / 05 · Confirmar entrega. The
/// stepper splits the work into:
///   step 0 — Fotos        (camera-driven evidence capture)
///   step 1 — Datos        (CustomFieldsForm — whatever the company configured)
///   step 2 — Confirmar    (notes + summary + final submit)
///
/// The callback signature is preserved from the previous sheet so the
/// StopDetail screen wires in without changes.
class DeliveryActionSheet extends StatefulWidget {
  final RouteStop stop;
  final List<FieldDefinition> stopFieldDefinitions;
  final void Function(
    List<File> photos,
    String? notes,
    Map<String, dynamic> customFields,
  ) onComplete;

  const DeliveryActionSheet({
    super.key,
    required this.stop,
    this.stopFieldDefinitions = const [],
    required this.onComplete,
  });

  @override
  State<DeliveryActionSheet> createState() => _DeliveryActionSheetState();
}

class _DeliveryActionSheetState extends State<DeliveryActionSheet> {
  static const int _maxPhotos = 3;

  int _step = 0;
  final List<File> _photos = [];
  final _notesController = TextEditingController();
  final _picker = ImagePicker();
  bool _isCapturing = false;
  Map<String, dynamic> _customFields = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.stop.customFields;
    if (initial != null && initial.isNotEmpty) {
      _customFields = {...initial};
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ── Step helpers ──────────────────────────────────────────────────

  static const _stepLabels = ['Fotos', 'Datos', 'Confirmar'];

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _photos.isNotEmpty;
      case 1:
        return findMissingRequired(
          widget.stopFieldDefinitions,
          _customFields,
        ).isEmpty;
      default:
        return true;
    }
  }

  void _next() {
    if (!_canAdvance) {
      _showRequiredHint();
      return;
    }
    if (_step < 2) {
      setState(() => _step += 1);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
  }

  void _showRequiredHint() {
    HapticFeedback.lightImpact();
    final msg = _step == 0
        ? 'Tomá al menos una foto como evidencia.'
        : 'Completá los campos obligatorios antes de seguir.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.bgSurfaceElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _submit() {
    final notes = _notesController.text.trim();
    widget.onComplete(_photos, notes.isEmpty ? null : notes, _customFields);
  }

  Future<void> _takePhoto() async {
    if (_isCapturing || _photos.length >= _maxPhotos) return;
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
            // Header: step counter + close.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Row(
                children: [
                  _IconCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: _back,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PASO ${_step + 1} DE 3',
                          style: AppTypography.label.copyWith(
                            color: AppColors.fgTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _stepLabels[_step],
                          style: AppTypography.h3,
                        ),
                      ],
                    ),
                  ),
                  _IconCircleButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Stepper bar — 3 segments.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? AppColors.lime
                            : AppColors.bgSurfaceElevated,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 14),

            // Stop summary chip.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _StopSummaryChip(stop: widget.stop),
            ),

            const SizedBox(height: 18),

            // Step content.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildStepContent(),
              ),
            ),

            // Action bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: _step == 0 ? 'Cancelar' : 'Atrás',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      onPressed: _back,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 17,
                    child: AppButton(
                      label: _step == 2 ? 'Confirmar entrega' : 'Siguiente',
                      icon: _step == 2 ? Icons.check_rounded : null,
                      trailingIcon: _step == 2
                          ? null
                          : Icons.arrow_forward_rounded,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      onPressed: _next,
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

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _StepFotos(
          photos: _photos,
          isCapturing: _isCapturing,
          maxPhotos: _maxPhotos,
          onTake: _takePhoto,
          onRemove: (i) => setState(() => _photos.removeAt(i)),
        );
      case 1:
        if (widget.stopFieldDefinitions.isEmpty) {
          return _EmptyStepHint(
            icon: Icons.check_circle_outline_rounded,
            title: 'No hay datos extras a llenar',
            body: 'Tu empresa no configuró campos personalizados para la '
                'entrega. Tocá Siguiente para continuar.',
          );
        }
        return CustomFieldsForm(
          definitions: widget.stopFieldDefinitions,
          initialValues: _customFields,
          onChanged: (values) {
            setState(() => _customFields = values);
          },
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notas (opcional)',
              style: AppTypography.label.copyWith(
                color: AppColors.fgSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _notesController,
              placeholder: 'Detalles relevantes para el despacho…',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // Lightweight pre-submit summary so the driver knows what
            // they're confirming.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceElevated,
                borderRadius: AppRadius.rMd,
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                    icon: Icons.camera_alt_outlined,
                    label: 'Fotos',
                    value: '${_photos.length}',
                  ),
                  const SizedBox(height: 6),
                  _SummaryRow(
                    icon: Icons.list_alt_rounded,
                    label: 'Campos',
                    value:
                        '${widget.stopFieldDefinitions.length} configurado'
                        '${widget.stopFieldDefinitions.length == 1 ? "" : "s"}',
                  ),
                ],
              ),
            ),
          ],
        );
    }
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

class _StepFotos extends StatelessWidget {
  final List<File> photos;
  final bool isCapturing;
  final int maxPhotos;
  final VoidCallback onTake;
  final ValueChanged<int> onRemove;

  const _StepFotos({
    required this.photos,
    required this.isCapturing,
    required this.maxPhotos,
    required this.onTake,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'EVIDENCIA DE ENTREGA',
              style: AppTypography.label.copyWith(
                color: AppColors.fgSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Text(
              '${photos.length} / $maxPhotos',
              style: AppTypography.mono.copyWith(
                color: photos.isEmpty
                    ? AppColors.fgTertiary
                    : AppColors.lime,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tomá hasta $maxPhotos fotos del paquete entregado o del lugar '
          'donde lo dejaste. Mínimo una.',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length + (photos.length < maxPhotos ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == photos.length) {
                return AddPhotoButton(onTap: onTake);
              }
              return PhotoThumb(
                file: photos[i],
                onRemove: () => onRemove(i),
              );
            },
          ),
        ),
        if (isCapturing)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.lime,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Abriendo cámara…',
                  style: TextStyle(
                    color: AppColors.fgTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyStepHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyStepHint({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.lime),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h4.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(body, style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.fgTertiary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.fgSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.label.copyWith(
            color: AppColors.fgPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSurfaceElevated,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 16, color: AppColors.fgPrimary),
        ),
      ),
    );
  }
}

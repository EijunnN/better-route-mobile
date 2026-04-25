import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/design/tokens.dart';
import '../../models/models.dart';
import '../app/app.dart';
import '../shared/shared.dart';

/// Failure reason sheet — dual-mode:
///  * Legacy ([targetWorkflowState] is null): chip grid of the
///    [FailureReason] enum.
///  * Workflow ([targetWorkflowState] set): chips of the operator-
///    defined [WorkflowState.reasonOptions]. Result returns
///    `customReason` (String) instead of `reason` (enum).
class FailureReasonSheet extends StatefulWidget {
  final RouteStop stop;
  final WorkflowState? targetWorkflowState;

  const FailureReasonSheet({
    super.key,
    required this.stop,
    this.targetWorkflowState,
  });

  @override
  State<FailureReasonSheet> createState() => _FailureReasonSheetState();
}

class _FailureReasonSheetState extends State<FailureReasonSheet> {
  FailureReason? _selectedReason;
  String? _selectedCustomReason;
  final _notesController = TextEditingController();
  final List<File> _photos = [];
  final _picker = ImagePicker();
  bool _isCapturing = false;

  bool get _isWorkflowMode => widget.targetWorkflowState != null;
  List<String> get _workflowReasons =>
      widget.targetWorkflowState?.reasonOptions ?? const [];
  bool get _hasSelection =>
      _isWorkflowMode ? _selectedCustomReason != null : _selectedReason != null;

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
      setState(() => _isCapturing = false);
    }
  }

  void _confirm() {
    if (!_hasSelection) {
      _alert('Motivo requerido', 'Seleccioná un motivo para continuar.');
      return;
    }
    if (!_isWorkflowMode &&
        _selectedReason == FailureReason.other &&
        _notesController.text.trim().isEmpty) {
      _alert('Notas requeridas', 'Especificá el motivo en las notas.');
      return;
    }
    if (_isWorkflowMode &&
        widget.targetWorkflowState!.requiresNotes &&
        _notesController.text.trim().isEmpty) {
      _alert('Notas requeridas', 'Este estado requiere agregar una nota.');
      return;
    }
    Navigator.pop(context, (
      reason: _selectedReason,
      customReason: _selectedCustomReason,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      photos: _photos,
    ));
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
                style: AppTypography.body.copyWith(color: AppColors.fgSecondary),
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
            _Header(stopName: widget.stop.displayName),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Motivo', style: AppTypography.label),
                    const SizedBox(height: 8),
                    if (_isWorkflowMode)
                      _WorkflowReasonChips(
                        reasons: _workflowReasons,
                        selected: _selectedCustomReason,
                        onSelect: (r) =>
                            setState(() => _selectedCustomReason = r),
                      )
                    else
                      _LegacyReasonChips(
                        selected: _selectedReason,
                        onSelect: (r) => setState(() => _selectedReason = r),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      _isWorkflowMode
                          ? (widget.targetWorkflowState!.requiresNotes
                              ? 'Notas (requeridas)'
                              : 'Notas adicionales (opcional)')
                          : (_selectedReason == FailureReason.other
                              ? 'Especificá el motivo'
                              : 'Notas adicionales (opcional)'),
                      style: AppTypography.label,
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _notesController,
                      placeholder: 'Detalles…',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 18),
                    Text('Foto de evidencia (opcional)',
                        style: AppTypography.label),
                    const SizedBox(height: 8),
                    if (_photos.isNotEmpty)
                      SizedBox(
                        height: 72,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length + 1,
                          itemBuilder: (context, i) {
                            if (i == _photos.length) {
                              return AddPhotoButton(onTap: _takePhoto, size: 72);
                            }
                            return PhotoThumb(
                              file: _photos[i],
                              onRemove: () =>
                                  setState(() => _photos.removeAt(i)),
                              size: 72,
                            );
                          },
                        ),
                      )
                    else
                      AppButton(
                        label: 'Tomar foto',
                        icon: Icons.camera_alt_rounded,
                        variant: AppButtonVariant.secondary,
                        fullWidth: true,
                        isLoading: _isCapturing,
                        onPressed: _takePhoto,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: AppButton(
                label: 'Confirmar fallo',
                variant: AppButtonVariant.destructive,
                size: AppButtonSize.lg,
                fullWidth: true,
                onPressed: _hasSelection ? _confirm : null,
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

class _Header extends StatelessWidget {
  final String stopName;

  const _Header({required this.stopName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.statusFailedBg,
              borderRadius: AppRadius.rMd,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.accentDanger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reportar fallo', style: AppTypography.h4),
                Text(
                  stopName,
                  style: AppTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowReasonChips extends StatelessWidget {
  final List<String> reasons;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _WorkflowReasonChips({
    required this.reasons,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: reasons.map((r) {
        final isSelected = selected == r;
        return GestureDetector(
          onTap: () => onSelect(r),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.statusFailedBg
                  : AppColors.bgSurface,
              borderRadius: AppRadius.rFull,
              border: Border.all(
                color: isSelected
                    ? AppColors.accentDanger
                    : AppColors.borderSubtle,
              ),
            ),
            child: Text(
              r,
              style: AppTypography.label.copyWith(
                color: isSelected
                    ? AppColors.accentDanger
                    : AppColors.fgPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LegacyReasonChips extends StatelessWidget {
  final FailureReason? selected;
  final ValueChanged<FailureReason> onSelect;

  const _LegacyReasonChips({
    required this.selected,
    required this.onSelect,
  });

  IconData _iconFor(FailureReason reason) {
    switch (reason) {
      case FailureReason.customerAbsent:
        return Icons.person_off_outlined;
      case FailureReason.customerRefused:
        return Icons.block_outlined;
      case FailureReason.addressNotFound:
        return Icons.location_off_outlined;
      case FailureReason.packageDamaged:
        return Icons.broken_image_outlined;
      case FailureReason.rescheduleRequested:
        return Icons.event_outlined;
      case FailureReason.unsafeArea:
        return Icons.warning_amber_outlined;
      case FailureReason.other:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FailureReason.values.map((reason) {
        final isSelected = selected == reason;
        return GestureDetector(
          onTap: () => onSelect(reason),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.statusFailedBg
                  : AppColors.bgSurface,
              borderRadius: AppRadius.rMd,
              border: Border.all(
                color: isSelected
                    ? AppColors.accentDanger
                    : AppColors.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconFor(reason),
                  size: 16,
                  color: isSelected
                      ? AppColors.accentDanger
                      : AppColors.fgSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  reason.label,
                  style: AppTypography.label.copyWith(
                    color: isSelected
                        ? AppColors.accentDanger
                        : AppColors.fgPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

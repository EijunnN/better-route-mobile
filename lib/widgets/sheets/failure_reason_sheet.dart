import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/design/tokens.dart';
import '../../models/models.dart';
import '../app/app.dart';
import '../shared/shared.dart';

/// Failure reason sheet — dual-mode:
///  * Legacy ([targetWorkflowState] is null): single select over the
///    [FailureReason] enum.
///  * Workflow ([targetWorkflowState] set): single select over the
///    operator-defined [WorkflowState.reasonOptions]. Result returns
///    `customReason` (String) instead of `reason` (enum).
///
/// Uses a "select-row → sub-sheet of options" pattern instead of
/// inline chips because the workflow reason list can grow per company
/// and Wrap-of-chips reflows the layout once it doesn't fit on one
/// row, pushing the action bar around.
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

  String? get _selectedLabel => _isWorkflowMode
      ? _selectedCustomReason
      : _selectedReason?.label;

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

  Future<void> _openReasonPicker() async {
    HapticFeedback.selectionClick();
    if (_isWorkflowMode) {
      final picked = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ReasonOptionsSheet<String>(
          title: 'Motivo de fallo',
          options: _workflowReasons,
          labelOf: (s) => s,
          isSelected: (s) => s == _selectedCustomReason,
        ),
      );
      if (picked != null) setState(() => _selectedCustomReason = picked);
    } else {
      final picked = await showModalBottomSheet<FailureReason>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ReasonOptionsSheet<FailureReason>(
          title: 'Motivo de fallo',
          options: FailureReason.values,
          labelOf: (r) => r.label,
          iconOf: _iconFor,
          isSelected: (r) => r == _selectedReason,
        ),
      );
      if (picked != null) setState(() => _selectedReason = picked);
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

  static IconData _iconFor(FailureReason reason) {
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
                    _ReasonSelectField(
                      value: _selectedLabel,
                      onTap: _openReasonPicker,
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

/// Single tap target that shows the current reason (or placeholder)
/// and a chevron, mirroring the iOS-style "settings row" pattern. The
/// whole row is tappable; visual states: empty (placeholder text) vs
/// filled (primary text + filled border).
class _ReasonSelectField extends StatelessWidget {
  final String? value;
  final VoidCallback onTap;

  const _ReasonSelectField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: filled ? AppColors.borderStrong : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? 'Seleccionar motivo',
                style: AppTypography.body.copyWith(
                  color: filled
                      ? AppColors.fgPrimary
                      : AppColors.fgTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.fgSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic single-select bottom sheet over a list of options. Designed
/// to scale: each option is a full-width tap target, vertical scroll
/// kicks in once the list overflows the sheet's max height. The
/// generic [T] keeps it reusable for both the [FailureReason] enum and
/// the workflow's `List<String>` reason options.
class _ReasonOptionsSheet<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final IconData Function(T)? iconOf;
  final bool Function(T) isSelected;

  const _ReasonOptionsSheet({
    required this.title,
    required this.options,
    required this.labelOf,
    required this.isSelected,
    this.iconOf,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return AppSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: AppTypography.h4)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.fgSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, i) {
                  final option = options[i];
                  final selected = isSelected(option);
                  return _ReasonOptionTile(
                    label: labelOf(option),
                    icon: iconOf?.call(option),
                    selected: selected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, option);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonOptionTile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? AppColors.accentLive
                      : AppColors.fgSecondary,
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.fgPrimary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.accentLive,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/design/tokens.dart';
import '../../models/route_stop.dart';
import '../../models/workflow_state.dart';
import '../app/app.dart';
import '../shared/shared.dart';

/// Modal sheet for collecting required data (photo / reason / notes)
/// before transitioning a stop into a workflow state. The sheet only
/// shows the inputs the [targetState] actually requires (
/// [WorkflowState.requiresPhoto], `requiresReason`, `requiresNotes`).
///
/// Logic is identical to the legacy implementation; the chrome is
/// rebuilt with [AppSheet]/[AppButton]/[AppTextField] for visual
/// coherence with the rest of the cockpit.
class WorkflowTransitionSheet extends StatefulWidget {
  final RouteStop stop;
  final WorkflowState targetState;
  final void Function(List<File> photos, String? notes, String? reason) onConfirm;

  const WorkflowTransitionSheet({
    super.key,
    required this.stop,
    required this.targetState,
    required this.onConfirm,
  });

  @override
  State<WorkflowTransitionSheet> createState() =>
      _WorkflowTransitionSheetState();
}

class _WorkflowTransitionSheetState extends State<WorkflowTransitionSheet> {
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
      _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      _selectedReason,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFailed =
        widget.targetState.isFailed || widget.targetState.isCancelled;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(targetState: widget.targetState, stop: widget.stop),
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
                      _ReasonChips(
                        options: _reasonOptions!,
                        selected: _selectedReason,
                        onSelect: (r) => setState(() => _selectedReason = r),
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
                                    return AddPhotoButton(onTap: _takePhoto);
                                  }
                                  return PhotoThumb(
                                    file: _photos[i],
                                    onRemove: () => _removePhoto(i),
                                  );
                                },
                              ),
                            )
                          : _CameraPlaceholder(
                              isCapturing: _isCapturing,
                              onTap: _takePhoto,
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

class _Header extends StatelessWidget {
  final WorkflowState targetState;
  final RouteStop stop;

  const _Header({required this.targetState, required this.stop});

  @override
  Widget build(BuildContext context) {
    final isFailed = targetState.isFailed || targetState.isCancelled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
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
              isFailed ? Icons.close_rounded : Icons.arrow_forward_rounded,
              size: 18,
              color: isFailed ? AppColors.accentDanger : AppColors.accentLive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(targetState.label, style: AppTypography.h4),
                Text(stop.displayName, style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonChips extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ReasonChips({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((reason) {
        final isSelected = selected == reason;
        return GestureDetector(
          onTap: () => onSelect(reason),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.fgPrimary : AppColors.bgSurface,
              borderRadius: AppRadius.rFull,
              border: Border.all(
                color: isSelected ? AppColors.fgPrimary : AppColors.borderSubtle,
              ),
            ),
            child: Text(
              reason,
              style: AppTypography.label.copyWith(
                color: isSelected ? AppColors.fgInverse : AppColors.fgPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback onTap;

  const _CameraPlaceholder({required this.isCapturing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: isCapturing
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
                  Text('Tomar foto', style: AppTypography.button),
                ],
              ),
      ),
    );
  }
}

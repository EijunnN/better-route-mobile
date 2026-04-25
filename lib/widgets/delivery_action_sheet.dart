import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../core/design/tokens.dart';
import '../models/models.dart';
import 'app/app.dart';
import 'custom_fields_form.dart';

class DeliveryActionSheet extends StatefulWidget {
  final RouteStop stop;
  /// Definitions for entity=route_stops + showInMobile=true. The driver
  /// fills these in this sheet; the values are passed back via [onComplete]
  /// and end up in `route_stops.customFields` on the backend.
  final List<FieldDefinition> stopFieldDefinitions;
  final Function(
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

  void _confirmDelivery() {
    if (_photos.isEmpty) {
      _showRequired('Foto requerida', 'Tomá al menos una foto como evidencia.');
      return;
    }
    final missing = findMissingRequired(widget.stopFieldDefinitions, _customFields);
    if (missing.isNotEmpty) {
      final labels = widget.stopFieldDefinitions
          .where((d) => missing.contains(d.code))
          .map((d) => d.label)
          .join(', ');
      _showRequired('Faltan datos', 'Completá los campos obligatorios: $labels');
      return;
    }
    widget.onComplete(
      _photos,
      _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      _customFields,
    );
  }

  void _showRequired(String title, String body) {
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.statusCompletedBg,
                      borderRadius: AppRadius.rMd,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.accentLive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Confirmar entrega', style: AppTypography.h4),
                        Text(
                          widget.stop.displayName,
                          style: AppTypography.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Foto de evidencia', style: AppTypography.label),
                    const SizedBox(height: 8),
                    if (_photos.isNotEmpty)
                      SizedBox(
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
                    else
                      GestureDetector(
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
                    if (widget.stopFieldDefinitions.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      CustomFieldsForm(
                        definitions: widget.stopFieldDefinitions,
                        initialValues: _customFields,
                        onChanged: (values) {
                          setState(() => _customFields = values);
                        },
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text('Notas (opcional)', style: AppTypography.label),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _notesController,
                      placeholder: 'Detalles relevantes de la entrega…',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: AppButton(
                label: 'Confirmar entrega',
                icon: Icons.check_rounded,
                variant: AppButtonVariant.live,
                size: AppButtonSize.lg,
                fullWidth: true,
                onPressed: _confirmDelivery,
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

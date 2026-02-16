import 'dart:io';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../models/models.dart';

class FailureReasonSheet extends StatefulWidget {
  final RouteStop stop;

  const FailureReasonSheet({super.key, required this.stop});

  @override
  State<FailureReasonSheet> createState() => _FailureReasonSheetState();
}

class _FailureReasonSheetState extends State<FailureReasonSheet> {
  FailureReason? _selectedReason;
  final _notesController = TextEditingController();
  final List<File> _photos = [];
  final _picker = ImagePicker();
  bool _isCapturing = false;

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
        setState(() {
          _photos.add(File(photo.path));
        });
      }
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  void _confirm() {
    if (_selectedReason == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Motivo requerido'),
          content: const Text('Por favor, selecciona un motivo'),
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

    // Require notes for "OTHER" reason
    if (_selectedReason == FailureReason.other &&
        _notesController.text.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Notas requeridas'),
          content: const Text('Por favor, especifica el motivo en las notas'),
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

    Navigator.pop(context, (
      reason: _selectedReason!,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      photos: _photos,
    ));
  }

  IconData _reasonIcon(FailureReason reason) {
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
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

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

                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: StatusColors.failedBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.cancel_rounded,
                        color: theme.colorScheme.destructive,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reportar fallo').semiBold().large(),
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
                  // Reason selection label
                  const Text('Motivo').semiBold().small(),

                  const SizedBox(height: 10),

                  // Reason chips in a wrap
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FailureReason.values.map((reason) {
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
                                ? StatusColors.failedBg
                                : theme.colorScheme.muted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.destructive
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _reasonIcon(reason),
                                size: 18,
                                color: isSelected
                                    ? theme.colorScheme.destructive
                                    : theme.colorScheme.mutedForeground,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                reason.label,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? theme.colorScheme.destructive
                                      : theme.colorScheme.foreground,
                                ),
                              ).small(),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Notes field
                  Text(
                    _selectedReason == FailureReason.other
                        ? 'Especifica el motivo'
                        : 'Notas adicionales (opcional)',
                  ).semiBold().small(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    placeholder: const Text('Agrega mas detalles...'),
                  ),

                  const SizedBox(height: 20),

                  // Photo evidence (optional)
                  Row(
                    children: [
                      const Text('Foto de evidencia').semiBold().small(),
                      const SizedBox(width: 8),
                      OutlineBadge(
                        child: const Text('Opcional').xSmall(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_photos.isNotEmpty) ...[
                    SizedBox(
                      height: 72,
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
                    OutlineButton(
                      onPressed: _takePhoto,
                      leading: _isCapturing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_outlined, size: 18),
                      child: const Text('Tomar foto'),
                    ),
                  ],

                  const SizedBox(height: 16),
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
                    child: DestructiveButton(
                      onPressed: _selectedReason == null ? null : _confirm,
                      child: Text(
                        'Confirmar',
                        style: TextStyle(
                          color: _selectedReason == null
                              ? theme.colorScheme.mutedForeground
                              : Colors.white,
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

  Widget _buildPhotoThumbnail(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _photos[index],
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: GestureDetector(
              onTap: () => _removePhoto(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: StatusColors.failed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.close,
                  size: 11,
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
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 20,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 2),
            Text('Agregar').xSmall().muted(),
          ],
        ),
      ),
    );
  }
}

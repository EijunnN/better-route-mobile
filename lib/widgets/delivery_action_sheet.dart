import 'dart:io';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../models/models.dart';

class DeliveryActionSheet extends StatefulWidget {
  final RouteStop stop;
  final Function(List<File> photos, String? notes) onComplete;

  const DeliveryActionSheet({
    super.key,
    required this.stop,
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

  void _confirmDelivery() {
    if (_photos.isEmpty) {
      // Show toast via snackbar-like approach
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Foto requerida'),
          content: const Text('Por favor, toma al menos una foto como evidencia'),
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

    widget.onComplete(
      _photos,
      _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        color: StatusColors.completedBackground(theme.brightness),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: StatusColors.completed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Confirmar entrega').semiBold().large(),
                          Text(widget.stop.displayName).small().muted(),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Photo section label
                const Text('Foto de evidencia').semiBold().small(),
                const SizedBox(height: 10),

                // Photos grid or camera button
                if (_photos.isNotEmpty) ...[
                  SizedBox(
                    height: 88,
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
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      height: 88,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.muted,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.border),
                      ),
                      child: _isCapturing
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  size: 22,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tomar foto',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                  ),
                                ).semiBold(),
                              ],
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Notes field
                const Text('Notas (opcional)').semiBold().small(),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  placeholder: const Text('Agrega notas sobre la entrega...'),
                ),

                const SizedBox(height: 24),

                // Confirm button
                SizedBox(
                  height: 52,
                  child: PrimaryButton(
                    onPressed: _photos.isEmpty ? null : _confirmDelivery,
                    child: Text(
                      _photos.isEmpty
                          ? 'Toma una foto primero'
                          : 'Confirmar entrega',
                      style: TextStyle(
                        color: _photos.isEmpty
                            ? theme.colorScheme.mutedForeground
                            : theme.colorScheme.primaryForeground,
                      ),
                    ).semiBold(),
                  ),
                ),

                const SizedBox(height: 8),

                // Cancel link
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
      ),
    );
  }

  Widget _buildPhotoThumbnail(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              _photos[index],
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removePhoto(index),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: StatusColors.failed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.close,
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

  Widget _buildAddPhotoButton(ThemeData theme) {
    return GestureDetector(
      onTap: _takePhoto,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 22,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 4),
            Text('Agregar').xSmall().muted(),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A reusable ground gallery image picker widget.
/// Usage:
///   GroundImagePicker(
///     onImagesChanged: (files) => setState(() => _pickedImages = files),
///   )
class GroundImagePicker extends StatefulWidget {
  final void Function(List<XFile> images) onImagesChanged;
  final int maxImages;

  const GroundImagePicker({
    super.key,
    required this.onImagesChanged,
    this.maxImages = 4,
  });

  @override
  State<GroundImagePicker> createState() => _GroundImagePickerState();
}

class _GroundImagePickerState extends State<GroundImagePicker> {
  static const _green = Color(0xFF0D5C3A);
  static const _greenLight = Color(0xFFE8F5EE);

  List<XFile> _images = [];

  // ── Pick images from gallery ───────────────────────────────────────────────
  Future<void> _pickImages() async {
    final remaining = widget.maxImages - _images.length;
    if (remaining <= 0) {
      _showSnack('Maximum ${widget.maxImages} images allowed.');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 70, // compress to ~70% — reduces size without visible loss
      maxWidth: 1280, // cap resolution — no need for 4K ground photos
      maxHeight: 960,
    );

    if (picked.isEmpty) return;

    setState(() {
      // Merge existing + new, cap at maxImages
      _images = [..._images, ...picked].take(widget.maxImages).toList();
    });

    // Notify parent
    widget.onImagesChanged(_images);
  }

  // ── Remove a single image ─────────────────────────────────────────────────
  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
    widget.onImagesChanged(_images);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main preview ───────────────────────────────────────────────────
        _buildMainPreview(),
        const SizedBox(height: 10),

        // ── Thumbnail strip ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Existing image thumbnails (skip index 0 — already shown above)
              ...List.generate(_images.length.clamp(0, widget.maxImages), (i) {
                if (i == 0) return const SizedBox.shrink(); // skip main
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_images[i].path),
                          width: 68,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Remove button
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
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
              }),

              // Add more button (only if under limit)
              if (_images.length < widget.maxImages)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 68,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _greenLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _green.withOpacity(0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                          color: _green,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_images.length}/${widget.maxImages}',
                          style: TextStyle(
                            fontSize: 10,
                            color: _green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Helper text ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            _images.isEmpty
                ? 'Add up to ${widget.maxImages} photos of your ground'
                : '${_images.length} photo${_images.length > 1 ? 's' : ''} selected · Tap × to remove',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _buildMainPreview() {
    if (_images.isNotEmpty) {
      // Show first image as main preview with remove button
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_images[0].path),
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            // Cover label
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Cover Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Remove cover
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _removeImage(0),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Empty state — tap to add
    return GestureDetector(
      onTap: _pickImages,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: _greenLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _green.withOpacity(0.2),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 44,
                color: _green.withOpacity(0.7),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to add ground photos',
                style: TextStyle(
                  fontSize: 13,
                  color: _green.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Up to ${widget.maxImages} photos · JPG, PNG',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

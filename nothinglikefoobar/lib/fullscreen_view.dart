import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:transparent_image/transparent_image.dart';

class FullscreenImageView extends StatefulWidget {
  final AssetEntity asset;
  final Uint8List? thumbnailBytes; // Layer 1: Thumbnail

  const FullscreenImageView({
    super.key,
    required this.asset,
    this.thumbnailBytes,
  });

  @override
  State<FullscreenImageView> createState() => _FullscreenImageViewState();
}

class _FullscreenImageViewState extends State<FullscreenImageView> {
  Uint8List? _screenResBytes; // Layer 2: 1920px
  File? _fullResFile;         // Layer 3: Original File

  @override
  void initState() {
    super.initState();
    _loadLayers();
  }

  Future<void> _loadLayers() async {
    // LAYER 2: Load Screen-Res (Fast)
    // We fire this first so it populates quickly.
    widget.asset.thumbnailDataWithSize(const ThumbnailSize(1920, 1920)).then((bytes) {
      if (mounted) {
        setState(() => _screenResBytes = bytes);
      }
    });

    // LAYER 3: Load Full-Res (Slow)
    // We get the actual file object. Flutter's FileImage provider handles
    // the memory management better than loading raw bytes for 50MP images.
    widget.asset.file.then((file) {
      if (mounted) {
        setState(() => _fullResFile = file);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 10.0, // Increased zoom to verify Layer 3 quality
          clipBehavior: Clip.none,
          child: Hero(
            tag: widget.asset.id,
            child: _buildLayeredImage(),
          ),
        ),
      ),
    );
  }

  Widget _buildLayeredImage() {
    // We use a Stack to layer the images on top of each other.
    // gaplessPlayback: true is ESSENTIAL on all layers to prevent flashing.
    return Stack(
      fit: StackFit.expand,
      children: [

        // LAYER 1: Thumbnail (Base)
        if (widget.thumbnailBytes != null)
          Image.memory(
            widget.thumbnailBytes!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),

        // LAYER 2: Screen Resolution (Mid)
        // This usually covers the thumbnail within 200-300ms.
        if (_screenResBytes != null)
          Image.memory(
            _screenResBytes!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),

        // LAYER 3: Original File (Top)
        // This appears last (1-2s). Since it's identical visually to Layer 2
        // until you zoom, we don't need a fade animation here—just swap it in.
        if (_fullResFile != null)
          Image.file(
            _fullResFile!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),

        // Loading Spinner (only if we have absolutely nothing)
        if (widget.thumbnailBytes == null && _screenResBytes == null)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFD71921)),
          ),
      ],
    );
  }
}
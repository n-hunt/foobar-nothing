import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:transparent_image/transparent_image.dart';

// Import the Video Player Widget
import 'video_view.dart';

class FullscreenImageView extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;
  final Uint8List? thumbnailBytes;

  const FullscreenImageView({
    super.key,
    required this.assets,
    required this.initialIndex,
    this.thumbnailBytes,
  });

  @override
  State<FullscreenImageView> createState() => _FullscreenImageViewState();
}

class _FullscreenImageViewState extends State<FullscreenImageView> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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
        title: Text(
          "${_currentIndex + 1} / ${widget.assets.length}",
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.assets.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          final asset = widget.assets[index];

          // UNIFIED LOGIC: Switch widget based on type
          if (asset.type == AssetType.video) {
            return SingleVideoPlayer(asset: asset);
          } else {
            return _SingleImageView(
              asset: asset,
              // Only use the passed thumbnail for the FIRST image we opened
              thumbnailBytes: index == widget.initialIndex ? widget.thumbnailBytes : null,
            );
          }
        },
      ),
    );
  }
}

class _SingleImageView extends StatefulWidget {
  final AssetEntity asset;
  final Uint8List? thumbnailBytes;

  const _SingleImageView({required this.asset, this.thumbnailBytes});

  @override
  State<_SingleImageView> createState() => _SingleImageViewState();
}

class _SingleImageViewState extends State<_SingleImageView> {
  Uint8List? _screenResBytes;
  File? _fullResFile;

  @override
  void initState() {
    super.initState();
    _loadLayers();
  }

  Future<void> _loadLayers() async {
    // Layer 2: 1080p Optimized
    widget.asset.thumbnailDataWithSize(const ThumbnailSize(1920, 1920)).then((bytes) {
      if (mounted) setState(() => _screenResBytes = bytes);
    });

    // Layer 3: Original File
    widget.asset.file.then((file) {
      if (mounted) setState(() => _fullResFile = file);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      clipBehavior: Clip.none,
      child: Hero(
        tag: widget.asset.id,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Passed Thumbnail (Instant)
            if (widget.thumbnailBytes != null)
              Image.memory(
                widget.thumbnailBytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),

            // Layer 2: Screen Res (Fast)
            if (_screenResBytes != null)
              Image.memory(
                _screenResBytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),

            // Layer 3: Full Res (Highest Quality)
            if (_fullResFile != null)
              Image.file(
                _fullResFile!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),

            // Spinner if nothing is ready
            if (widget.thumbnailBytes == null && _screenResBytes == null)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFD71921)),
              ),
          ],
        ),
      ),
    );
  }
}
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'video_view.dart';
import 'edit_image_view.dart'; // Import Edit View
import 'bin_service.dart';

class FullscreenImageView extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;
  final Uint8List? thumbnailBytes;
  final VoidCallback? onDeleted;
  final bool isFromBin; // Add this parameter

  const FullscreenImageView({
    super.key,
    required this.assets,
    required this.initialIndex,
    this.thumbnailBytes,
    this.onDeleted,
    this.isFromBin = false, // Default to false
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

  // --- ACTIONS ---

  Future<void> _handleShare() async {
    final AssetEntity asset = widget.assets[_currentIndex];
    final File? file = await asset.file;
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

  void _handleEdit() {
    final AssetEntity asset = widget.assets[_currentIndex];
    if (asset.type == AssetType.image) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditImageView(asset: asset),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Video editing coming soon")),
      );
    }
  }

  void _handleRestore() {
    final AssetEntity asset = widget.assets[_currentIndex];

    BinService().restore(asset);

    if (widget.onDeleted != null) {
      widget.onDeleted!();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Restored from Bin")),
    );

    Navigator.pop(context);
  }

  void _handleDelete() {
    final AssetEntity asset = widget.assets[_currentIndex];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("Move to Bin?", style: GoogleFonts.shareTechMono(color: Colors.white)),
        content: const Text(
          "Items will be deleted after 30 days.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog

              // Add to BinService
              BinService().addToBin(asset);

              // Notify parent to refresh
              if (widget.onDeleted != null) {
                widget.onDeleted!();
              }

              // Show snackbar with undo
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Moved to Bin (30 Days left)"),
                  duration: const Duration(milliseconds: 750), // Auto-dismiss after 0.75s
                  action: SnackBarAction(
                    label: "UNDO",
                    textColor: const Color(0xFFD71921),
                    onPressed: () {
                      BinService().restore(asset);
                      if (widget.onDeleted != null) widget.onDeleted!();
                    },
                  ),
                ),
              );

              Navigator.pop(context); // Close fullscreen
            },
            child: const Text("MOVE TO BIN", style: TextStyle(color: Color(0xFFD71921))),
          ),
        ],
      ),
    );
  }

  void _handlePermanentDelete() {
    final AssetEntity asset = widget.assets[_currentIndex];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("Delete Permanently?", style: GoogleFonts.shareTechMono(color: const Color(0xFFD71921))),
        content: const Text(
          "This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // Uncomment for production:
              // await PhotoManager.editor.deleteWithIds([asset.id]);

              BinService().restore(asset); // Remove from bin tracking

              if (widget.onDeleted != null) {
                widget.onDeleted!();
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Permanently deleted (simulated)")),
                );
                Navigator.pop(context);
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Color(0xFFD71921))),
          ),
        ],
      ),
    );
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
      body: Stack(
        children: [
          // 1. The Swipeable Content
          PageView.builder(
            controller: _pageController,
            itemCount: widget.assets.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final asset = widget.assets[index];
              if (asset.type == AssetType.video) {
                return SingleVideoPlayer(asset: asset);
              } else {
                return _SingleImageView(
                  asset: asset,
                  thumbnailBytes: index == widget.initialIndex ? widget.thumbnailBytes : null,
                );
              }
            },
          ),

          // 2. Bottom Action Bar (Different for Bin vs Gallery)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              child: widget.isFromBin
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: Icons.restore,
                          label: "Restore",
                          onTap: _handleRestore,
                        ),
                        _ActionButton(
                          icon: Icons.delete_forever,
                          label: "Delete",
                          onTap: _handlePermanentDelete,
                          isDestructive: true,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ActionButton(icon: Icons.share_outlined, label: "Share", onTap: _handleShare),
                        _ActionButton(icon: Icons.edit_outlined, label: "Edit", onTap: _handleEdit),
                        _ActionButton(icon: Icons.delete_outline, label: "Bin", onTap: _handleDelete, isDestructive: true),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFD71921) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

// ... _SingleImageView Class remains unchanged ...
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
    widget.asset.thumbnailDataWithSize(const ThumbnailSize(1920, 1920)).then((bytes) {
      if (mounted) setState(() => _screenResBytes = bytes);
    });

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
            if (widget.thumbnailBytes != null)
              Image.memory(
                widget.thumbnailBytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),

            if (_screenResBytes != null)
              Image.memory(
                _screenResBytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),

            if (_fullResFile != null)
              Image.file(
                _fullResFile!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),

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

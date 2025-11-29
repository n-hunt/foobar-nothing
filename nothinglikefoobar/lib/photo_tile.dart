import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:transparent_image/transparent_image.dart';

import 'fullscreen_view.dart';
import 'asset_image_provider.dart';
import 'edit_image_view.dart';
import 'bin_service.dart';

class PhotoTile extends StatelessWidget {
  final AssetEntity asset;
  final List<AssetEntity> assets;
  final int index;
  final VoidCallback? onDeleted;

  const PhotoTile({
    super.key,
    required this.asset,
    required this.assets,
    required this.index,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = AssetEntityImageProvider(
      asset,
      // OPTIMIZATION: Reduced from 300 to 200.
      // 200x200 is sufficient for 3-column grid and loads much faster.
      thumbnailSize: const ThumbnailSize.square(200),
    );

    return GestureDetector(
      onTap: () async {
        Uint8List? bytes;
        try {
          if (asset.type == AssetType.image) {
            bytes = await asset.thumbnailDataWithSize(const ThumbnailSize.square(300));
          }
        } catch (e) {
          // Ignore thumbnail errors
        }

        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FullscreenImageView(
                assets: assets,
                initialIndex: index,
                thumbnailBytes: bytes,
              ),
            ),
          );
        }
      },
      onLongPress: () => _showOptionsSheet(context),
      child: Hero(
        tag: asset.id,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FadeInImage(
              placeholder: MemoryImage(kTransparentImage),
              image: imageProvider,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              excludeFromSemantics: true,
              imageErrorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 20),
                  ),
                );
              },
            ),
            if (asset.type == AssetType.video)
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Colors.grey, width: 0.5),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "OPTIONS",
                style: GoogleFonts.shareTechMono(
                  fontSize: 14,
                  color: Colors.grey,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.spaceAround,
                children: [
                  _OptionButton(
                    icon: Icons.share_outlined,
                    label: "SHARE",
                    onTap: () async {
                      Navigator.pop(ctx);
                      final File? file = await asset.file;
                      if (file != null) {
                        await Share.shareXFiles([XFile(file.path)]);
                      }
                    },
                  ),
                  _OptionButton(
                    icon: Icons.edit_outlined,
                    label: "EDIT",
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateToEditor(context);
                    },
                  ),
                  _OptionButton(
                    icon: Icons.auto_fix_normal_outlined,
                    label: "MAGIC ERASER",
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateToEditor(context, initialToolIndex: 2);
                    },
                  ),
                  _OptionButton(
                    icon: Icons.delete_outline,
                    label: "BIN",
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _navigateToEditor(BuildContext context, {int initialToolIndex = 0}) {
    if (asset.type == AssetType.image) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditImageView(
            asset: asset,
            initialToolIndex: initialToolIndex,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Video editing coming soon")),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("Move to Bin?", style: GoogleFonts.shareTechMono(color: Colors.white)),
        content: const Text(
          "Items in the bin will be permanently deleted after 30 days.",
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

              // 1. Add to Bin Service
              BinService().addToBin(asset);

              // 2. Notify Parent to refresh UI
              if (onDeleted != null) {
                onDeleted!();
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Moved to Bin (30 Days left)"),
                  action: SnackBarAction(
                    label: "UNDO",
                    textColor: const Color(0xFFD71921),
                    onPressed: () {
                      BinService().restore(asset);
                      if (onDeleted != null) onDeleted!(); // Refresh again
                    },
                  ),
                ),
              );
            },
            child: const Text("MOVE TO BIN", style: TextStyle(color: Color(0xFFD71921))),
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OptionButton({
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.5)),
                color: isDestructive ? color.withValues(alpha: 0.1) : Colors.transparent,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.shareTechMono(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
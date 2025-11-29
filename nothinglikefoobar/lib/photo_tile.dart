import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:transparent_image/transparent_image.dart';

// FIX: Imports are now direct (since everything is in lib/)
import 'fullscreen_view.dart';
import 'asset_image_provider.dart';

class PhotoTile extends StatelessWidget {
  final AssetEntity asset;
  final List<AssetEntity> assets;
  final int index;

  const PhotoTile({
    super.key,
    required this.asset,
    required this.assets,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = AssetEntityImageProvider(
        asset,
        thumbnailSize: const ThumbnailSize.square(300)
    );

    return GestureDetector(
      onTap: () async {
        // UNIFIED LOGIC: We removed the separate video route.
        // FullscreenImageView now handles both Photos and Videos intelligently.

        Uint8List? bytes;

        // We attempt to get a thumbnail for the transition.
        // Even for videos, a thumbnail helps the Hero animation look smooth.
        try {
          bytes = await asset.thumbnailDataWithSize(const ThumbnailSize.square(300));
        } catch (e) {
          // Ignore thumbnail errors on tap, just proceed to fullscreen
        }

        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FullscreenImageView(
                  assets: assets,
                  initialIndex: index,
                  thumbnailBytes: bytes
              ),
            ),
          );
        }
      },
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
            // Video Indicator Overlay
            if (asset.type == AssetType.video)
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
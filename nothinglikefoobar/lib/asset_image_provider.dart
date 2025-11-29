import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class AssetEntityImageProvider extends ImageProvider<AssetEntityImageProvider> {
  final AssetEntity entity;
  final ThumbnailSize thumbnailSize;

  const AssetEntityImageProvider(
      this.entity, {
        this.thumbnailSize = const ThumbnailSize.square(300),
      });

  @override
  ImageStreamCompleter loadImage(AssetEntityImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'AssetEntityImageProvider(${key.entity.id})',
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<AssetEntityImageProvider>('Image provider', this),
        DiagnosticsProperty<AssetEntityImageProvider>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(AssetEntityImageProvider key, ImageDecoderCallback decode) async {
    try {
      final data = await key.entity.thumbnailDataWithSize(thumbnailSize);
      if (data == null) throw StateError('Could not load data for asset: ${key.entity.id}');
      return await decode(await ui.ImmutableBuffer.fromUint8List(data));
    } catch (e) {
      // FIX: Rethrowing allows the widget (FadeInImage) to catch the error
      // and display the errorBuilder content instead of crashing the image decoder
      // with invalid (empty) bytes.
      if (kDebugMode) {
        print("Thumbnail failed for ${key.entity.id}: $e");
      }
      rethrow;
    }
  }

  @override
  Future<AssetEntityImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AssetEntityImageProvider>(this);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is AssetEntityImageProvider &&
        other.entity.id == entity.id &&
        other.thumbnailSize == thumbnailSize;
  }

  @override
  int get hashCode => Object.hash(entity.id, thumbnailSize);
}
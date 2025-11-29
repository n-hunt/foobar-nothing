import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Required for SynchronousFuture
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:transparent_image/transparent_image.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'fullscreen_view.dart';

void main() {
  runApp(const CactusApp());
}

class CactusApp extends StatelessWidget {
  const CactusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nothing Privacy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFD71921),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD71921),
          surface: Colors.black,
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.shareTechMonoTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const NothingGalleryHome(),
    );
  }
}

class NothingGalleryHome extends StatefulWidget {
  const NothingGalleryHome({super.key});

  @override
  State<NothingGalleryHome> createState() => _NothingGalleryHomeState();
}

enum GallerySortOrder { recent, oldest }

class _NothingGalleryHomeState extends State<NothingGalleryHome> {
  // Navigation State
  int _selectedIndex = 0;

  // Gallery State
  List<AssetEntity> _images = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  GallerySortOrder _sortOrder = GallerySortOrder.recent;

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    // Only set loading if we don't have images yet to avoid flashing
    if (_images.isEmpty) setState(() => _isLoading = true);

    final PermissionState ps = await PhotoManager.requestPermissionExtend();

    if (!ps.isAuth && !ps.hasAccess) {
      setState(() {
        _isLoading = false;
        _hasPermission = false;
      });
      return;
    }

    final FilterOptionGroup filterOption = FilterOptionGroup(
      orders: [
        OrderOption(
          type: OrderOptionType.createDate,
          asc: _sortOrder == GallerySortOrder.oldest,
        ),
      ],
    );

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: filterOption,
    );

    if (albums.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasPermission = true;
      });
      return;
    }

    final int assetCount = await albums[0].assetCountAsync;

    final List<AssetEntity> media = await albums[0].getAssetListRange(
      start: 0,
      end: assetCount,
    );

    setState(() {
      _images = media;
      _isLoading = false;
      _hasPermission = true;
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == GallerySortOrder.recent
          ? GallerySortOrder.oldest
          : GallerySortOrder.recent;
    });
    _fetchAssets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Expanded content area that switches based on tab
            Expanded(
              child: _selectedIndex == 0
                  ? _buildGalleryView()
                  : _buildSearchView(),
            ),
            _buildNothingNavBar(),
          ],
        ),
      ),
    );
  }

  // --- VIEW 1: GALLERY ---
  Widget _buildGalleryView() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildGridBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "NOTHING",
                style: GoogleFonts.shareTechMono(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Container(width: 8, height: 8, color: const Color(0xFFD71921)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text("PRIVACY GALLERY", style: TextStyle(color: Colors.grey[600])),
              const Spacer(),
              GestureDetector(
                onTap: _toggleSortOrder,
                child: Row(
                  children: [
                    Icon(
                      _sortOrder == GallerySortOrder.recent
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 14,
                      color: const Color(0xFFD71921),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortOrder == GallerySortOrder.recent ? "RECENT" : "OLDEST",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD71921),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (_images.isNotEmpty)
                Text("${_images.length} FILES", style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.grey[800]),
        ],
      ),
    );
  }

  Widget _buildGridBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD71921)));
    }

    if (!_hasPermission) {
      return _buildPermissionView();
    }

    if (_images.isEmpty) {
      return const Center(child: Text("NO IMAGES FOUND"));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      cacheExtent: 1000,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        return _PhotoTile(asset: _images[index]);
      },
    );
  }

  Widget _buildPermissionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 50, color: Color(0xFFD71921)),
          const SizedBox(height: 20),
          const Text("PERMISSION REQUIRED"),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => PhotoManager.openSetting(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: const Text("OPEN SETTINGS", style: TextStyle(color: Colors.black)),
          )
        ],
      ),
    );
  }

  // --- VIEW 2: SEARCH (Placeholder for Dev B) ---
  Widget _buildSearchView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SEARCH",
            style: GoogleFonts.shareTechMono(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: "TYPE COMMAND...",
              hintStyle: TextStyle(color: Colors.grey[700]),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD71921))),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 40, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  Text(
                    "CACTUS AGENT READY",
                    style: TextStyle(color: Colors.grey[700], letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NAVIGATION BAR ---
  Widget _buildNothingNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey[900]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, "GALLERY"),
          _buildNavItem(1, "SEARCH"),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            if (isSelected) ...[
              const Icon(Icons.circle, size: 8, color: Color(0xFFD71921)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final AssetEntity asset;

  const _PhotoTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    final imageProvider = AssetEntityImageProvider(
        asset,
        thumbnailSize: const ThumbnailSize.square(300)
    );

    return GestureDetector(
      onTap: () async {
        final bytes = await asset.thumbnailDataWithSize(const ThumbnailSize.square(300));

        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FullscreenImageView(
                  asset: asset,
                  thumbnailBytes: bytes
              ),
            ),
          );
        }
      },
      child: Hero(
        tag: asset.id,
        child: FadeInImage(
          placeholder: MemoryImage(kTransparentImage),
          image: imageProvider,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 200),
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

// Custom ImageProvider for native caching (kept from previous version)
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
      return await decode(await ui.ImmutableBuffer.fromUint8List(Uint8List(0)));
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
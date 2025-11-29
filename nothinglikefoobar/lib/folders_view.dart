import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';

import 'folder_detail_view.dart';
import 'photo_tile.dart';
import 'bin_service.dart';
import 'fullscreen_view.dart'; // Add this import

class FoldersView extends StatefulWidget {
  const FoldersView({super.key});

  @override
  State<FoldersView> createState() => _FoldersViewState();
}

class _FoldersViewState extends State<FoldersView> with WidgetsBindingObserver {
  List<AssetPathEntity> _albums = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAlbums();

    // Listen for gallery changes
    PhotoManager.addChangeCallback(_onPhotoChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PhotoManager.removeChangeCallback(_onPhotoChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchAlbums();
    }
  }

  void _onPhotoChange(MethodCall call) {
    if (mounted) _fetchAlbums();
  }

  Future<void> _fetchAlbums() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      setState(() => _isLoading = false);
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );

    setState(() {
      _albums = albums;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD71921)));
    }

    int totalCount = _albums.length + 1;

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              if (index == 1) {
                // Bin Tile uses ValueListenableBuilder for reactive count
                return ValueListenableBuilder<List<String>>(
                  valueListenable: BinService().binnedIdsListenable,
                  builder: (context, binnedIds, child) => const _BinTile(),
                );
              }
              final albumIndex = index > 1 ? index - 1 : index;
              return _AlbumTile(album: _albums[albumIndex]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "FOLDERS",
            style: GoogleFonts.shareTechMono(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "${_albums.length + 1} COLLECTIONS FOUND",
            style: TextStyle(color: Colors.grey[600], fontSize: 12, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.grey[800]),
        ],
      ),
    );
  }
}

// --- BIN TILE ---
class _BinTile extends StatelessWidget {
  const _BinTile();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BinDetailView()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD71921).withOpacity(0.3)),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, color: Color(0xFFD71921), size: 40),
                    SizedBox(height: 8),
                    Text("30 DAYS LEFT", style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "BIN",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "${BinService().count} FILES",
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// --- BIN VIEW (Updated to use Service assets) ---
class BinDetailView extends StatefulWidget {
  const BinDetailView({super.key});

  @override
  State<BinDetailView> createState() => _BinDetailViewState();
}

class _BinDetailViewState extends State<BinDetailView> {

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: BinService().binnedIdsListenable,
      builder: (context, binnedIds, child) {
        final binAssets = BinService().assets; // Get the AssetEntity list

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text("BIN", style: GoogleFonts.shareTechMono(color: Colors.white)),
            actions: [
              if (binAssets.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await BinService().emptyBin();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bin Empty")));
                    }
                  },
                  child: Text("EMPTY BIN", style: GoogleFonts.shareTechMono(color: const Color(0xFFD71921))),
                )
            ],
          ),
          body: binAssets.isEmpty
              ? _buildEmptyState()
              : _buildGrid(binAssets),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.delete_outline, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          Text("NO ITEMS IN BIN", style: GoogleFonts.shareTechMono(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGrid(List<AssetEntity> assets) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullscreenImageView(
                  assets: assets,
                  initialIndex: index,
                ),
              ),
            );
          },
          onLongPress: () => _showRestoreOption(context, assets[index]),
          child: PhotoTile(
            asset: assets[index],
            assets: assets,
            index: index,
            onDeleted: () {}, // Already handled by ValueNotifier
          ),
        );
      },
    );
  }

  void _showRestoreOption(BuildContext context, AssetEntity asset) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.restore, color: Color(0xFFD71921)),
                title: Text("RESTORE", style: GoogleFonts.shareTechMono(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  BinService().restore(asset);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Restored from Bin")),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text("DELETE PERMANENTLY", style: GoogleFonts.shareTechMono(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  // Uncomment for production:
                  // await PhotoManager.editor.deleteWithIds([asset.id]);
                  BinService().restore(asset); // Remove from bin tracking
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Permanently deleted (simulated)")),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- ALBUM TILE (Made stateful to cache thumbnail) ---
class _AlbumTile extends StatefulWidget {
  final AssetPathEntity album;

  const _AlbumTile({required this.album});

  @override
  State<_AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<_AlbumTile> {
  Uint8List? _cachedThumbnail;
  int? _cachedCount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final assets = await widget.album.getAssetListRange(start: 0, end: 1);
      if (assets.isNotEmpty) {
        final thumbnail = await assets.first.thumbnailDataWithSize(const ThumbnailSize(300, 300));
        final count = await widget.album.assetCountAsync;
        if (mounted) {
          setState(() {
            _cachedThumbnail = thumbnail;
            _cachedCount = count;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FolderDetailView(album: widget.album),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _cachedThumbnail != null
                  ? Image.memory(
                      _cachedThumbnail!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : _isLoading
                      ? Container(
                          color: Colors.grey[850],
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFD71921),
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.folder_open, color: Colors.grey, size: 40),
                        ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.album.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                "${_cachedCount ?? '...'} FILES",
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward, color: Color(0xFFD71921), size: 12),
            ],
          ),
        ],
      ),
    );
  }
}


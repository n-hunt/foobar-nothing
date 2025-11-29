import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:transparent_image/transparent_image.dart';
import 'dart:typed_data';

import 'folder_detail_view.dart';
import 'photo_tile.dart';
import 'bin_service.dart';

class FoldersView extends StatefulWidget {
  const FoldersView({super.key});

  @override
  State<FoldersView> createState() => _FoldersViewState();
}

class _FoldersViewState extends State<FoldersView> {
  List<AssetPathEntity> _albums = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAlbums();
  }

  Future<void> _fetchAlbums() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      setState(() => _isLoading = false);
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // CHANGED: Show folders with videos too
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
                return const _BinTile();
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
        ).then((_) {
          // Force refresh when coming back from bin (in case restored items moved)
          // (Requires converting FoldersView to listenable or using setstate in parent)
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD71921).withValues(alpha: 0.3)),
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

// --- BIN VIEW (Updated to use Service) ---
class BinDetailView extends StatefulWidget {
  const BinDetailView({super.key});

  @override
  State<BinDetailView> createState() => _BinDetailViewState();
}

class _BinDetailViewState extends State<BinDetailView> {

  @override
  Widget build(BuildContext context) {
    // Get assets directly from memory (Instant load)
    final binAssets = BinService().assets;

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
                setState(() {}); // Refresh UI
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bin Empty")));
              },
              child: Text("EMPTY BIN", style: GoogleFonts.shareTechMono(color: const Color(0xFFD71921))),
            )
        ],
      ),
      body: binAssets.isEmpty
          ? _buildEmptyState()
          : _buildGrid(binAssets),
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
        return PhotoTile(
          asset: assets[index],
          assets: assets,
          index: index,
          onDeleted: () {
            // In the Bin, "Delete" usually means "Delete Permanently" or "Restore"
            // For now, we assume it triggers a refresh
            setState(() {});
          },
        );
      },
    );
  }
}

// --- ALBUM TILE ---
class _AlbumTile extends StatelessWidget {
  final AssetPathEntity album;

  const _AlbumTile({required this.album});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AssetEntity>>(
      future: album.getAssetListRange(start: 0, end: 1),
      builder: (context, snapshot) {
        AssetEntity? coverAsset;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          coverAsset = snapshot.data!.first;
        }

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FolderDetailView(album: album),
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: coverAsset != null
                      ? FutureBuilder<Uint8List?>(
                    future: coverAsset.thumbnailDataWithSize(const ThumbnailSize(400, 400)),
                    builder: (context, thumbSnapshot) {
                      if (thumbSnapshot.hasData) {
                        return FadeInImage(
                          placeholder: MemoryImage(kTransparentImage),
                          image: MemoryImage(thumbSnapshot.data!),
                          fit: BoxFit.cover,
                        );
                      }
                      return Container();
                    },
                  )
                      : const Center(
                    child: Icon(Icons.folder_open, color: Colors.grey, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                album.name.toUpperCase(),
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
                  FutureBuilder<int>(
                    future: album.assetCountAsync,
                    builder: (context, countSnapshot) {
                      return Text(
                        "${countSnapshot.data ?? 0} FILES",
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      );
                    },
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward, color: Color(0xFFD71921), size: 12),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
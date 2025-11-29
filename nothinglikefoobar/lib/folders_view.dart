import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:transparent_image/transparent_image.dart';
import 'dart:typed_data';

// FIX: Import from the same directory (flattened structure)
import 'folder_detail_view.dart';

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
      type: RequestType.image,
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
            itemCount: _albums.length,
            itemBuilder: (context, index) {
              return _AlbumTile(album: _albums[index]);
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
            "${_albums.length} COLLECTIONS FOUND",
            style: TextStyle(color: Colors.grey[600], fontSize: 12, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.grey[800]),
        ],
      ),
    );
  }
}

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
            // Navigate to the extracted detail screen
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
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
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
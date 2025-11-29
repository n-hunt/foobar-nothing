import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';

import 'photo_tile.dart';
import 'bin_service.dart'; // NEW IMPORT

enum GallerySortOrder { recent, oldest }

class FolderDetailView extends StatefulWidget {
  final AssetPathEntity album;

  const FolderDetailView({super.key, required this.album});

  @override
  State<FolderDetailView> createState() => _FolderDetailViewState();
}

class _FolderDetailViewState extends State<FolderDetailView> {
  List<AssetEntity> _images = [];
  bool _isLoading = true;
  GallerySortOrder _sortOrder = GallerySortOrder.recent;

  @override
  void initState() {
    super.initState();
    _fetchPhotos();
  }

  Future<void> _fetchPhotos() async {
    setState(() => _isLoading = true);

    final FilterOptionGroup filterOption = FilterOptionGroup(
      orders: [
        OrderOption(
          type: OrderOptionType.createDate,
          asc: _sortOrder == GallerySortOrder.oldest,
        ),
      ],
    );

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // CHANGED: Show videos too
      onlyAll: widget.album.isAll,
      filterOption: filterOption,
    );

    final matchingAlbum = albums.firstWhere(
            (a) => a.id == widget.album.id,
        orElse: () => widget.album
    );

    final int count = await matchingAlbum.assetCountAsync;
    final media = await matchingAlbum.getAssetListRange(start: 0, end: count);

    // Filter out items that are in the bin
    final visibleMedia = media.where((a) => !BinService().isInBin(a)).toList();

    if (mounted) {
      setState(() {
        _images = visibleMedia;
        _isLoading = false;
      });
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == GallerySortOrder.recent
          ? GallerySortOrder.oldest
          : GallerySortOrder.recent;
    });
    _fetchPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.album.name.toUpperCase(),
                  style: GoogleFonts.shareTechMono(fontSize: 24, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text("FOLDER VIEW", style: TextStyle(color: Colors.grey[600])),
              const Spacer(),
              GestureDetector(
                onTap: _toggleSortOrder,
                child: Row(
                  children: [
                    Icon(
                      _sortOrder == GallerySortOrder.recent ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 14,
                      color: const Color(0xFFD71921),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortOrder == GallerySortOrder.recent ? "RECENT" : "OLDEST",
                      style: const TextStyle(fontSize: 12, color: Color(0xFFD71921), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.grey[800]),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD71921)));
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
        return PhotoTile(
          asset: _images[index],
          assets: _images,
          index: index,
          onDeleted: () {
            // FIX: Refresh the UI when item is deleted
            setState(() {
              _images.removeAt(index);
            });
          },
        );
      },
    );
  }
}
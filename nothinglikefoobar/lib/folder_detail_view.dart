import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';

import 'photo_tile.dart';
import 'bin_service.dart';

enum GallerySortOrder { recent, oldest }

class FolderDetailView extends StatefulWidget {
  final AssetPathEntity album;

  const FolderDetailView({super.key, required this.album});

  @override
  State<FolderDetailView> createState() => _FolderDetailViewState();
}

class _FolderDetailViewState extends State<FolderDetailView> with WidgetsBindingObserver {
  List<AssetEntity> _images = [];
  bool _isLoading = true;
  GallerySortOrder _sortOrder = GallerySortOrder.recent;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchPhotos();

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
      _fetchPhotos();
    }
  }

  void _onPhotoChange(MethodCall call) {
    if (mounted) _fetchPhotos();
  }

  Future<void> _fetchPhotos() async {
    // OPTIMIZATION: Don't block UI, show loading only initially
    final bool isInitialLoad = _images.isEmpty;
    if (isInitialLoad) setState(() => _isLoading = true);

    final FilterOptionGroup filterOption = FilterOptionGroup(
      orders: [
        OrderOption(
          type: OrderOptionType.createDate,
          asc: _sortOrder == GallerySortOrder.oldest,
        ),
      ],
    );

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: widget.album.isAll,
      filterOption: filterOption,
    );

    final matchingAlbum = albums.firstWhere(
            (a) => a.id == widget.album.id,
        orElse: () => widget.album
    );

    final int count = await matchingAlbum.assetCountAsync;
    _totalCount = count;

    // ENHANCEMENT: Quick refresh for new items
    if (!isInitialLoad && count > _images.length) {
      final int newItemsCount = count - _images.length;
      final List<AssetEntity> newMedia = await matchingAlbum.getAssetListRange(
        start: 0,
        end: newItemsCount,
      );

      if (mounted) {
        setState(() {
          _images.insertAll(0, newMedia);
        });
      }
      return;
    }

    // OPTIMIZATION: Load first 30 immediately
    const int firstBatch = 30;
    final List<AssetEntity> initialMedia = await matchingAlbum.getAssetListRange(
      start: 0,
      end: count < firstBatch ? count : firstBatch,
    );

    if (mounted) {
      setState(() {
        _images = initialMedia;
        _isLoading = false;
      });
    }

    // Load rest in background batches
    if (count > firstBatch) {
      const int batchSize = 100;
      int currentStart = firstBatch;

      while (currentStart < count) {
        await Future.delayed(const Duration(milliseconds: 50));

        final int end = (currentStart + batchSize) > count ? count : currentStart + batchSize;
        final List<AssetEntity> batch = await matchingAlbum.getAssetListRange(
          start: currentStart,
          end: end,
        );

        if (mounted) {
          setState(() {
            _images.addAll(batch);
          });
        }

        currentStart = end;
      }
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
                  style: GoogleFonts.dotGothic16(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: const Color(0xFFFFFFFF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                "FOLDER VIEW",
                style: GoogleFonts.ibmPlexMono(
                  color: const Color(0xFF8E8E93),
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              // OPTIMIZATION: Show loading indicator for remaining items
              if (_images.length < _totalCount) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${_images.length}/$_totalCount",
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
                const SizedBox(width: 16),
              ],
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

    return ValueListenableBuilder<List<String>>(
      valueListenable: BinService().binnedIdsListenable,
      builder: (context, binnedIds, child) {
        // Filter the images list against the binned IDs
        final visibleImages = _images.where((img) => !binnedIds.contains(img.id)).toList();

        if (visibleImages.isEmpty) {
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
          itemCount: visibleImages.length,
          itemBuilder: (context, index) {
            return PhotoTile(
              asset: visibleImages[index],
              assets: visibleImages,
              index: index,
              onDeleted: () {},
            );
          },
        );
      },
    );
  }
}
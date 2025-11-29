import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for MethodCall
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';

import 'search_view.dart';
import 'search_view_2.dart';
import 'folders_view.dart';
import 'photo_tile.dart';
import 'bin_service.dart';

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

class _NothingGalleryHomeState extends State<NothingGalleryHome> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<AssetEntity> _images = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  GallerySortOrder _sortOrder = GallerySortOrder.recent;

  String _selectedCategory = 'CAMERA';
  final List<String> _categories = ['CAMERA', 'VIDEOS', 'SCREENS', 'ALL'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAssets();
    // Listen to BinService updates
    BinService().addListener(_fetchAssets);

    // OPTIMIZATION: Listen for new photos/videos being added
    PhotoManager.addChangeCallback(_onPhotoManagerChange);
    PhotoManager.startChangeNotify();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BinService().removeListener(_fetchAssets);
    PhotoManager.removeChangeCallback(_onPhotoManagerChange);
    PhotoManager.stopChangeNotify();
    super.dispose();
  }

  // ENHANCEMENT: Detect when app comes to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh when returning from camera
      _fetchAssets();
    }
  }

  void _onPhotoManagerChange(MethodCall call) {
    // ENHANCEMENT: Immediate refresh on any gallery change
    debugPrint("Gallery changed: ${call.method}");
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    // OPTIMIZATION: Don't show loading spinner on refresh, only on first load
    final bool isInitialLoad = _images.isEmpty;
    if (isInitialLoad) setState(() => _isLoading = true);

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

    RequestType requestType = RequestType.image;
    if (_selectedCategory == 'VIDEOS') {
      requestType = RequestType.video;
    } else if (_selectedCategory == 'ALL' || _selectedCategory == 'CAMERA') {
      requestType = RequestType.common;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: requestType,
      hasAll: true,
      filterOption: filterOption,
    );

    if (albums.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPermission = true;
          _images = [];
        });
      }
      return;
    }

    AssetPathEntity targetAlbum = albums.first;
    String targetName = "Camera";

    if (_selectedCategory == 'SCREENS') targetName = "Screenshots";
    if (_selectedCategory == 'ALL') targetName = "Recent";

    if (_selectedCategory != 'ALL') {
      for (var album in albums) {
        if (album.name == targetName || (targetName == "Camera" && !album.isAll && album.name.contains("Camera"))) {
          targetAlbum = album;
          break;
        }
      }
    }

    final int assetCount = await targetAlbum.assetCountAsync;

    // ENHANCEMENT: For refresh (not initial load), just get latest items and merge
    if (!isInitialLoad && assetCount > _images.length) {
      // New items detected - fetch just the new ones
      final int newItemsCount = assetCount - _images.length;
      final List<AssetEntity> newMedia = await targetAlbum.getAssetListRange(
        start: 0,
        end: newItemsCount,
      );

      final visibleNewMedia = newMedia.where((a) => !BinService().isInBin(a.id)).toList();

      if (mounted) {
        setState(() {
          // Add new items to the front (recent first)
          _images.insertAll(0, visibleNewMedia);
          _hasPermission = true;
        });
      }
      return;
    }

    // OPTIMIZATION: Load first 30 items immediately for initial load
    const int firstBatch = 30;

    final List<AssetEntity> initialMedia = await targetAlbum.getAssetListRange(
      start: 0,
      end: assetCount < firstBatch ? assetCount : firstBatch,
    );

    final visibleInitialMedia = initialMedia.where((a) => !BinService().isInBin(a.id)).toList();

    if (mounted) {
      setState(() {
        _images = visibleInitialMedia;
        _isLoading = false;
        _hasPermission = true;
      });
    }

    // Load remaining in batches to avoid blocking
    if (assetCount > firstBatch) {
      const int batchSize = 100;
      int currentStart = firstBatch;

      while (currentStart < assetCount) {
        await Future.delayed(const Duration(milliseconds: 50));

        final int end = (currentStart + batchSize) > assetCount ? assetCount : currentStart + batchSize;
        final List<AssetEntity> batch = await targetAlbum.getAssetListRange(
          start: currentStart,
          end: end,
        );

        if (mounted) {
          setState(() {
            _images.addAll(batch.where((a) => !BinService().isInBin(a.id)));
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
    _fetchAssets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildBodyContent(),
            ),
            _buildNothingNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildGalleryView();
      case 1:
        return const FoldersView(key: ValueKey('folders'));
      case 2:
        return const SearchView();
      case 3:
        return const SearchView2();
      default:
        return _buildGalleryView();
    }
  }

  // --- GALLERY VIEW ---
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
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: Colors.grey[900],
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFD71921), size: 16),
                  style: GoogleFonts.shareTechMono(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0
                  ),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                        _fetchAssets();
                      });
                    }
                  },
                ),
              ),
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
                Text("${_images.length}", style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          _isLoading
              ? const LinearProgressIndicator(
              minHeight: 1,
              backgroundColor: Colors.transparent,
              color: Color(0xFFD71921)
          )
              : Container(height: 1, color: Colors.grey[800]),
        ],
      ),
    );
  }

  Widget _buildGridBody() {
    if (_isLoading && _images.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD71921)));
    }

    if (!_hasPermission) {
      return _buildPermissionView();
    }

    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.grey[800], size: 48),
            const SizedBox(height: 16),
            Text("NO $_selectedCategory FOUND", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
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
          // When an item is marked as deleted/restored, re-fetch the entire list
          // to ensure the gallery is consistent.
          onDeleted: _fetchAssets,
        );
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
          _buildNavItem(1, "FOLDERS"),
          _buildNavItem(2, "SEARCH"),
          _buildNavItem(3, "SEARCH 2"),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
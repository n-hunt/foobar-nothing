import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';

// Page Imports
import 'search_view.dart';
import 'folders_view.dart';

// Widget Imports
import 'photo_tile.dart';

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
  int _selectedIndex = 0;
  List<AssetEntity> _images = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  GallerySortOrder _sortOrder = GallerySortOrder.recent;

  // Category State
  String _selectedCategory = 'CAMERA';
  final List<String> _categories = ['CAMERA', 'VIDEOS', 'SCREENS', 'ALL'];

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    // Only show loading if empty to prevent flashing on refresh
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

    // 1. Determine Request Type
    RequestType requestType = RequestType.image;
    if (_selectedCategory == 'VIDEOS') {
      requestType = RequestType.video;
    } else if (_selectedCategory == 'ALL' || _selectedCategory == 'CAMERA') {
      // CHANGED: CAMERA now requests both images and videos (common)
      requestType = RequestType.common;
    }

    // 2. Fetch Albums
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: requestType,
      hasAll: true,
      filterOption: filterOption,
    );

    if (albums.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasPermission = true;
        _images = [];
      });
      return;
    }

    // 3. Filter for specific album based on Category
    AssetPathEntity targetAlbum = albums.first;
    String targetName = "Camera"; // Default

    if (_selectedCategory == 'SCREENS') targetName = "Screenshots";
    if (_selectedCategory == 'ALL') targetName = "Recent";

    if (_selectedCategory != 'ALL') {
      for (var album in albums) {
        // Robust check for Camera folder
        if (album.name == targetName || (targetName == "Camera" && !album.isAll && album.name.contains("Camera"))) {
          targetAlbum = album;
          break;
        }
      }
    }

    final int assetCount = await targetAlbum.assetCountAsync;
    final List<AssetEntity> media = await targetAlbum.getAssetListRange(
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
        return const FoldersView();
      case 2:
        return const SearchView();
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
              // CATEGORY DROPDOWN
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
              // SORT BUTTON
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
            Text("NO ${_selectedCategory} FOUND", style: TextStyle(color: Colors.grey[600])),
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
          _buildNavItem(1, "FOLDERS"),
          _buildNavItem(2, "SEARCH"),
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
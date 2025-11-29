import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for MethodCall
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';

import 'search_view.dart';
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
        scaffoldBackgroundColor: const Color(0xFF000000), // Pure black
        primaryColor: const Color(0xFFFF1E1E), // High-voltage red
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF1E1E), // High-voltage red
          surface: Color(0xFF1C1C1E), // Dark charcoal
          onSurface: Color(0xFFFFFFFF),
          secondary: Color(0xFF8E8E93), // Light grey
        ),
        textTheme: GoogleFonts.ibmPlexMonoTextTheme(
          ThemeData.dark().textTheme.apply(
            bodyColor: const Color(0xFFFFFFFF),
            displayColor: const Color(0xFFFFFFFF),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF000000),
          elevation: 0,
          titleTextStyle: GoogleFonts.dotGothic16(
            fontSize: 18,
            color: const Color(0xFFFFFFFF),
            letterSpacing: 1.2,
          ),
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

  // Lazy loading state
  bool _isLoadingMore = false;
  int _totalAssetCount = 0;
  AssetPathEntity? _currentAlbum;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _fetchAssets();
    // Listen to BinService updates
    BinService().addListener(_fetchAssets);

    // OPTIMIZATION: Listen for new photos/videos being added
    PhotoManager.addChangeCallback(_onPhotoManagerChange);
    PhotoManager.startChangeNotify();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

  void _onScroll() {
    if (_isLoadingMore || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8; // Load more when 80% scrolled

    if (currentScroll >= threshold) {
      _loadMoreAssets();
    }
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

    // Store for lazy loading
    _currentAlbum = targetAlbum;
    _totalAssetCount = assetCount;

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

    // OPTIMIZATION: Load first 20 items immediately for initial load (reduced from 30)
    const int firstBatch = 20;

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

    // Load remaining in smaller batches with longer delays to avoid lag
    if (assetCount > firstBatch) {
      const int batchSize = 30; // Reduced from 100
      const int maxBackgroundLoad = 200; // Only load up to 200 total items initially
      int currentStart = firstBatch;
      final int maxEnd = assetCount > maxBackgroundLoad ? maxBackgroundLoad : assetCount;

      while (currentStart < maxEnd) {
        await Future.delayed(const Duration(milliseconds: 200)); // Increased from 50ms

        final int end = (currentStart + batchSize) > maxEnd ? maxEnd : currentStart + batchSize;
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

      // Load remaining items lazily only when user scrolls near the end
      // This prevents loading thousands of items unnecessarily
    }
  }

  Future<void> _loadMoreAssets() async {
    if (_isLoadingMore || _currentAlbum == null || _images.length >= _totalAssetCount) {
      return; // Already loading, no album, or all loaded
    }

    setState(() => _isLoadingMore = true);

    try {
      const int batchSize = 50;
      final int currentCount = _images.length;
      final int end = (currentCount + batchSize) > _totalAssetCount
          ? _totalAssetCount
          : currentCount + batchSize;

      final List<AssetEntity> batch = await _currentAlbum!.getAssetListRange(
        start: currentCount,
        end: end,
      );

      if (mounted) {
        setState(() {
          _images.addAll(batch.where((a) => !BinService().isInBin(a.id)));
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading more assets: $e");
      if (mounted) {
        setState(() => _isLoadingMore = false);
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

  List<Map<String, dynamic>> _buildDateSections() {
    if (_images.length <= 1) {
      return [];
    }

    final now = DateTime.now();
    final sections = <Map<String, dynamic>>[];
    final List<AssetEntity> remainingImages = _images.sublist(1); // Skip hero image

    final List<AssetEntity> thisWeek = [];
    final List<AssetEntity> oneWeekAgo = [];
    final List<AssetEntity> oneMonthAgo = [];
    final Map<String, List<AssetEntity>> monthGroups = {};
    final Map<String, List<AssetEntity>> yearGroups = {};

    for (final asset in remainingImages) {
      final date = asset.createDateTime;
      final diff = now.difference(date);

      if (diff.inDays < 7) {
        // Within a week (no header)
        thisWeek.add(asset);
      } else if (diff.inDays >= 7 && diff.inDays < 14) {
        // 1 week ago
        oneWeekAgo.add(asset);
      } else if (diff.inDays >= 14 && diff.inDays < 60) {
        // 1 month ago (14-60 days)
        oneMonthAgo.add(asset);
      } else if (diff.inDays < 365) {
        // Within a year - group by month name
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        monthGroups.putIfAbsent(monthKey, () => []);
        monthGroups[monthKey]!.add(asset);
      } else {
        // Older than a year - group by year
        final yearKey = '${date.year}';
        yearGroups.putIfAbsent(yearKey, () => []);
        yearGroups[yearKey]!.add(asset);
      }
    }

    // Add "This Week" section (no header)
    if (thisWeek.isNotEmpty) {
      sections.add({
        'header': null,
        'images': thisWeek,
      });
    }

    // Add "1 WEEK AGO" section
    if (oneWeekAgo.isNotEmpty) {
      sections.add({
        'header': '1 WEEK AGO',
        'images': oneWeekAgo,
      });
    }

    // Add "1 MONTH AGO" section
    if (oneMonthAgo.isNotEmpty) {
      sections.add({
        'header': '1 MONTH AGO',
        'images': oneMonthAgo,
      });
    }

    // Add month name sections (sorted newest to oldest)
    final sortedMonths = monthGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final monthKey in sortedMonths) {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final monthName = _getMonthName(month);

      sections.add({
        'header': '$monthName $year',
        'images': monthGroups[monthKey]!,
      });
    }

    // Add year sections (sorted newest to oldest)
    final sortedYears = yearGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final yearKey in sortedYears) {
      sections.add({
        'header': yearKey,
        'images': yearGroups[yearKey]!,
      });
    }

    return sections;
  }

  String _getMonthName(int month) {
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    return months[month - 1];
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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFF1C1C1E), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "MEMORIES",
                style: GoogleFonts.dotGothic16(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1E1E),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1E1E).withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF1C1C1E),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFFF1E1E), size: 16),
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
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
                      size: 12,
                      color: const Color(0xFFFF1E1E),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _sortOrder == GallerySortOrder.recent ? "RECENT" : "OLDEST",
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10,
                        color: const Color(0xFFFF1E1E),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              if (_images.isNotEmpty)
                Text(
                  "${_images.length}",
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: const Color(0xFF8E8E93),
                    letterSpacing: 1.0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoading
              ? Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF1E1E),
                        const Color(0xFFFF1E1E).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                )
              : Container(height: 1, color: const Color(0xFF1C1C1E)),
        ],
      ),
    );
  }

  Widget _buildGridBody() {
    if (_isLoading && _images.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF1E1E)));
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

    // Custom layout with hero tile and date-based sections - using slivers for smooth scrolling
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double tileSize = (width - 4) / 3; // 3 columns with 2px spacing

        // Build sections with date breaks
        final sections = _buildDateSections();

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Hero tile as sliver
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: tileSize * 3 + 4,
                  height: tileSize * 3 + 4,
                  child: PhotoTile(
                    asset: _images[0],
                    assets: _images,
                    index: 0,
                    onDeleted: _fetchAssets,
                    isHero: true,
                  ),
                ),
              ),
            ),

            // Spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 2),
            ),

            // Date sections as slivers
            ...sections.map((section) {
              final images = section['images'] as List<AssetEntity>;

              return SliverMainAxisGroup(
                slivers: [
                  // Section header
                  if (section['header'] != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF1E1E),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF1E1E).withValues(alpha: 0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              section['header'] as String,
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: const Color(0xFFFF1E1E),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: const Color(0xFF1C1C1E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Section grid as sliver
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                        childAspectRatio: 1.0,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final asset = images[index];
                          final actualIndex = _images.indexOf(asset);
                          return PhotoTile(
                            asset: asset,
                            assets: _images,
                            index: actualIndex,
                            onDeleted: _fetchAssets,
                          );
                        },
                        childCount: images.length,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),

            // Loading indicator at bottom
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFFF1E1E),
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "LOADING MORE...",
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 10,
                            color: const Color(0xFF8E8E93),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // End indicator
            if (!_isLoadingMore && _images.length >= _totalAssetCount && _totalAssetCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      "${_images.length} ITEMS LOADED",
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10,
                        color: const Color(0xFF8E8E93),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 50, color: Color(0xFFFF1E1E)),
          const SizedBox(height: 20),
          Text(
            "PERMISSION REQUIRED",
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => PhotoManager.openSetting(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF1E1E),
              foregroundColor: const Color(0xFF000000),
            ),
            child: Text(
              "OPEN SETTINGS",
              style: GoogleFonts.ibmPlexMono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNothingNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(top: BorderSide(color: Color(0xFF1C1C1E), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, "PHOTOS"),
          _buildNavItem(1, "FOLDERS"),
          _buildNavItem(2, "SEARCH"),
          _buildNavItem(3, "BIN"),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1E1E),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1E1E).withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: isSelected ? const Color(0xFFFF1E1E) : const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

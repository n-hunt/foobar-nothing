import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:transparent_image/transparent_image.dart';
import 'dart:typed_data';

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
        // The "Nothing" Red
        primaryColor: const Color(0xFFD71921),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD71921),
          surface: Colors.black,
          onSurface: Colors.white,
        ),
        // "Share Tech Mono" is the closest Google Font to Nothing's Ndot
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

class _NothingGalleryHomeState extends State<NothingGalleryHome> {
  List<AssetEntity> _images = [];
  bool _isLoading = true;
  int _privateCount = 0; // Mock count for the header

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    // 1. Request Permission
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      // Handle permission denied (show dialog in real app)
      setState(() => _isLoading = false);
      return;
    }

    // 2. Fetch Albums (Recent)
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // 3. Fetch Photos from "Recent" album
    // Loading first 100 for the hackathon demo to be fast
    final List<AssetEntity> media = await albums[0].getAssetListPaged(
      page: 0,
      size: 100,
    );

    setState(() {
      _images = media;
      _isLoading = false;
      // Just a mock number to make the UI look cool
      _privateCount = (media.length * 0.15).round();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildNothingHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD71921)))
                  : _images.isEmpty
                  ? _buildEmptyState()
                  : _buildPhotoGrid(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildNothingHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "NOTHING",
                style: GoogleFonts.shareTechMono(
                  fontSize: 28,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // The "Red Dot" indicator active when privacy mode is on
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFD71921), // Nothing Red
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                "PRIVACY GALLERY",
                style: GoogleFonts.shareTechMono(
                  fontSize: 14,
                  color: Colors.grey[600],
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                "${_images.length} ITEMS",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The "Dotted" Divider line
          Container(
            height: 1,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.3), Colors.transparent],
                stops: const [0.5, 0.5],
                // Simple hack to make a dotted line effect
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: List.generate(
                  40,
                      (index) => Expanded(
                    child: Container(
                      color: index % 2 == 0
                          ? Colors.grey[800]
                          : Colors.transparent,
                      height: 1,
                    ),
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hide_image_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            "NO ARTIFACTS FOUND",
            style: TextStyle(color: Colors.grey[600], letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        return _NothingPhotoTile(asset: _images[index]);
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCmdButton("CONSOLE"),

          // The Main Action Button
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFD71921),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Center(
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.black, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "SCAN PRIVACY",
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCmdButton(String label) {
    return Text(
      "> $label",
      style: const TextStyle(color: Colors.white, letterSpacing: 1.2),
    );
  }
}

class _NothingPhotoTile extends StatelessWidget {
  final AssetEntity asset;

  const _NothingPhotoTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4), // Slight rounding
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                ),
                // "Glitch" overlay for style (subtle gradient)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.2),
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        }
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }
}
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';

class EditImageView extends StatefulWidget {
  final AssetEntity asset;
  final int initialToolIndex;

  const EditImageView({
    super.key,
    required this.asset,
    this.initialToolIndex = 0, // Default to filters
  });

  @override
  State<EditImageView> createState() => _EditImageViewState();
}

class _EditImageViewState extends State<EditImageView> {
  // State
  File? _imageFile;
  Uint8List? _imageBytes;
  ui.Image? _loadedImage; // Required for painting operations
  int _selectedFilterIndex = 0;
  int _selectedToolIndex = 0; // 0: Filters, 1: Crop, 2: Eraser
  bool _isProcessing = false;

  // Crop Controller
  final _cropController = CropController();

  // Eraser State
  final List<Offset?> _eraserPoints = [];
  double _eraserStrokeWidth = 20.0;

  // Basic Matrix Filters
  final List<List<double>> _filters = [
    [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0], // Normal
    [0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0], // Sepia
    [0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0], // B&W
    [1.5, 0, 0, 0, -50, 0, 1.5, 0, 0, -50, 0, 0, 1.5, 0, -50, 0, 0, 0, 1, 0], // High Contrast
  ];

  final List<String> _filterNames = ["ORIGINAL", "VINTAGE", "MONO", "DRAMA"];

  @override
  void initState() {
    super.initState();
    _selectedToolIndex = widget.initialToolIndex;
    _loadFile();
  }

  Future<void> _loadFile() async {
    final file = await widget.asset.file;
    if (file != null) {
      final bytes = await file.readAsBytes();
      // Decode image for painting capabilities
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _imageFile = file;
          _imageBytes = bytes;
          _loadedImage = frame.image;
        });
      }
    }
  }

  // --- ACTIONS ---

  void _applyCrop(Uint8List croppedData) async {
    setState(() => _isProcessing = true);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(croppedData);

    // Need to reload the ui.Image for subsequent edits
    final codec = await ui.instantiateImageCodec(croppedData);
    final frame = await codec.getNextFrame();

    setState(() {
      _imageFile = tempFile;
      _imageBytes = croppedData;
      _loadedImage = frame.image;
      _selectedToolIndex = 0;
      _isProcessing = false;
    });
  }

  // A basic client-side approximation of "magic eraser" using heavy blur.
  // True generative fill requires complex ML models not available in standard packages.
  Future<void> _applyEraser() async {
    if (_loadedImage == null || _eraserPoints.isEmpty) return;
    setState(() => _isProcessing = true);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _loadedImage!.width.toDouble(), _loadedImage!.height.toDouble()));

    // 1. Draw base image
    canvas.drawImage(_loadedImage!, Offset.zero, Paint());

    // 2. Draw blurred strokes over it to simulate removal
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _eraserStrokeWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.0); // Heavy blur

    for (int i = 0; i < _eraserPoints.length - 1; i++) {
      if (_eraserPoints[i] != null && _eraserPoints[i + 1] != null) {
        canvas.drawLine(_eraserPoints[i]!, _eraserPoints[i + 1]!, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(_loadedImage!.width, _loadedImage!.height);
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final newBytes = pngBytes!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/erase_${DateTime.now().millisecondsSinceEpoch}.png');
    await tempFile.writeAsBytes(newBytes);

    setState(() {
      _imageFile = tempFile;
      _imageBytes = newBytes;
      _loadedImage = img;
      _eraserPoints.clear();
      _isProcessing = false;
    });
  }

  // Apply filter to actual image bytes (not just visual)
  Future<Uint8List> _applyFilterToBytes() async {
    if (_loadedImage == null || _selectedFilterIndex == 0) {
      // No filter or original - return current bytes
      return _imageBytes!;
    }

    // Render the image with the color filter applied
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, _loadedImage!.width.toDouble(), _loadedImage!.height.toDouble()),
    );

    // Apply the color filter matrix as a paint
    final paint = Paint()
      ..colorFilter = ColorFilter.matrix(_filters[_selectedFilterIndex]);

    canvas.drawImage(_loadedImage!, Offset.zero, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(_loadedImage!.width, _loadedImage!.height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _handleSave(bool overwrite) async {
    if (_imageFile == null) return;
    setState(() => _isProcessing = true);

    try {
      // Apply filter to get final bytes
      final finalBytes = await _applyFilterToBytes();

      if (overwrite) {
        // Simulate override for hackathon safety
        final originalFile = await widget.asset.file;
        if (originalFile != null) {
          await originalFile.writeAsBytes(finalBytes);
          PaintingBinding.instance.imageCache.clear();
        }
      } else {
        // Save filtered image as new copy
        final fileName = "Edit_${DateTime.now().millisecondsSinceEpoch}.png";
        await PhotoManager.editor.saveImage(
          finalBytes,
          filename: fileName,
          relativePath: "DCIM/Camera",
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(overwrite ? "Original Overwritten" : "Saved to Camera")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("EDIT", style: GoogleFonts.shareTechMono(color: Colors.white)),
        actions: [
          if (_selectedToolIndex == 1) // Crop Mode
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFFD71921)),
              onPressed: () {
                setState(() => _isProcessing = true);
                _cropController.crop();
              },
            )
          else if (_selectedToolIndex == 2) // Eraser Mode
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFFD71921)),
              onPressed: _applyEraser,
            )
          else // Filter Mode
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'copy') _handleSave(false);
                if (value == 'override') _handleSave(true);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'copy',
                  child: Text("Save as Copy", style: GoogleFonts.shareTechMono()),
                ),
                PopupMenuItem<String>(
                  value: 'override',
                  child: Text("Override Original", style: GoogleFonts.shareTechMono(color: Colors.red)),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: Text("SAVE", style: GoogleFonts.shareTechMono(color: const Color(0xFFD71921))),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isProcessing
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD71921)))
                : _buildMainArea(),
          ),
          _buildEditorToolbar(),
        ],
      ),
    );
  }

  Widget _buildMainArea() {
    if (_imageBytes == null) return const Center(child: CircularProgressIndicator(color: Color(0xFFD71921)));

    // CROP MODE
    if (_selectedToolIndex == 1) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Crop(
          image: _imageBytes!,
          controller: _cropController,
          // FIX 2: Handle CropResult instead of raw Uint8List
          onCropped: (result) {
            switch (result) {
              case CropSuccess(:final croppedImage):
                _applyCrop(croppedImage);
                break;
              case CropFailure(:final cause):
                debugPrint("Crop failed: $cause");
                setState(() => _isProcessing = false);
                break;
            }
          },
          baseColor: Colors.black,
          maskColor: Colors.black.withValues(alpha: 0.7),
          cornerDotBuilder: (size, edgeAlignment) =>
          const DotControl(color: Color(0xFFD71921)),
        ),
      );
    }

    // ERASER MODE
    if (_selectedToolIndex == 2) {
      return GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _eraserPoints.add(details.localPosition);
          });
        },
        onPanEnd: (details) {
          setState(() => _eraserPoints.add(null));
        },
        child: CustomPaint(
          foregroundPainter: _EraserPainter(points: _eraserPoints, strokeWidth: _eraserStrokeWidth),
          child: Center(
            child: Image.memory(_imageBytes!, fit: BoxFit.contain),
          ),
        ),
      );
    }

    // FILTER MODE
    return Center(
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(_filters[_selectedFilterIndex]),
        child: Image.memory(
          _imageBytes!,
          fit: BoxFit.contain,
          key: ValueKey(_imageBytes.hashCode),
        ),
      ),
    );
  }

  Widget _buildEditorToolbar() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter Selector
          if (_selectedToolIndex == 0)
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemBuilder: (context, index) {
                  final isSelected = _selectedFilterIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilterIndex = index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              border: isSelected
                                  ? Border.all(color: const Color(0xFFD71921), width: 2)
                                  : null,
                              color: Colors.grey[800],
                            ),
                            child: _imageFile != null
                                ? ColorFiltered(
                              colorFilter: ColorFilter.matrix(_filters[index]),
                              child: Image.file(_imageFile!, fit: BoxFit.cover),
                            )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _filterNames[index],
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFD71921) : Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Eraser Size Slider
          if (_selectedToolIndex == 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  const Icon(Icons.brush, color: Colors.grey, size: 16),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFFD71921),
                        thumbColor: const Color(0xFFD71921),
                        trackHeight: 2.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      ),
                      child: Slider(
                        value: _eraserStrokeWidth,
                        min: 5.0,
                        max: 50.0,
                        onChanged: (value) => setState(() => _eraserStrokeWidth = value),
                      ),
                    ),
                  ),
                  const Icon(Icons.circle, color: Colors.grey, size: 16),
                ],
              ),
            ),

          if (_selectedToolIndex == 0 || _selectedToolIndex == 2) const SizedBox(height: 10),

          // Tool Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToolTab(
                icon: Icons.auto_fix_high,
                label: "Filters",
                isSelected: _selectedToolIndex == 0,
                onTap: () {
                  setState(() {
                    _selectedToolIndex = 0;
                    _eraserPoints.clear();
                  });
                },
              ),
              _ToolTab(
                icon: Icons.crop,
                label: "Crop",
                isSelected: _selectedToolIndex == 1,
                onTap: () {
                  setState(() {
                    _selectedToolIndex = 1;
                    _eraserPoints.clear();
                  });
                },
              ),
              _ToolTab(
                icon: Icons.auto_fix_normal,
                label: "Eraser",
                isSelected: _selectedToolIndex == 2,
                onTap: () => setState(() => _selectedToolIndex = 2),
              ),
              _ToolTab(icon: Icons.tune, label: "Adjust", isSelected: false, onTap: () {}),
            ],
          )
        ],
      ),
    );
  }
}

// Painter for drawing eraser strokes
class _EraserPainter extends CustomPainter {
  final List<Offset?> points;
  final double strokeWidth;

  _EraserPainter({required this.points, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD71921).withValues(alpha: 0.5)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ToolTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: isSelected ? const Color(0xFFD71921) : Colors.grey),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}


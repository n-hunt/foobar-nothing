import 'package:flutter/material.dart';
import '../database/image_database.dart';
import '../services/model_initializer.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';
import 'dart:async';

class LocalAnalysisService {
  static final LocalAnalysisService _instance = LocalAnalysisService._internal();
  static LocalAnalysisService get instance => _instance;
  
  factory LocalAnalysisService() => _instance;
  
  LocalAnalysisService._internal();

  final ImageDatabase _db = ImageDatabase();
  bool _isProcessing = false;
  int _processedCount = 0;
  int _totalCount = 0;
  StreamController<double>? _progressController;

  bool get isProcessing => _isProcessing;
  int get processedCount => _processedCount;
  int get totalCount => _totalCount;
  double get progress => _totalCount > 0 ? _processedCount / _totalCount : 0;

  Stream<double> get progressStream {
    _progressController ??= StreamController<double>.broadcast();
    return _progressController!.stream;
  }

  /// Process all unanalyzed images in the background (non-blocking)
  void startBackgroundAnalysis() {
    if (_isProcessing) {
      debugPrint('[LocalAnalysis] Already processing images');
      return;
    }

    // Run in background with microtask
    Future.microtask(() => _processUnanalyzedImages());
  }

  /// Process all unanalyzed images sequentially
  Future<void> _processUnanalyzedImages() async {
    if (_isProcessing) {
      debugPrint('[LocalAnalysis] Already processing images');
      return;
    }

    // Set flag immediately to prevent race condition
    _isProcessing = true;

    final modelInit = ModelInitializer.instance;
    if (!modelInit.isInitialized) {
      debugPrint('[LocalAnalysis] Model not initialized, waiting...');
      // Wait for model to initialize
      int attempts = 0;
      while (!modelInit.isInitialized && attempts < 120) {
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      }
      
      if (!modelInit.isInitialized) {
        debugPrint('[LocalAnalysis] Model failed to initialize after 120s');
        _isProcessing = false;  // Reset flag on failure
        return;
      }
    }

    _processedCount = 0;

    try {
      // Get all images that need local analysis
      final unanalyzedImages = await _db.getImagesNeedingLocalAnalysis();
      
      // Limit to 50 images per session to prevent crashes
      const maxPerSession = 50;
      final imagesToProcess = unanalyzedImages.take(maxPerSession).toList();
      _totalCount = imagesToProcess.length;

      debugPrint('[LocalAnalysis] Found ${unanalyzedImages.length} unanalyzed images total');
      debugPrint('[LocalAnalysis] Processing $_totalCount images this session (max $maxPerSession)');
      _emitProgress();

      for (var imageMap in imagesToProcess) {
        try {
          final imageId = imageMap['image_id'] as String;
          final filePath = imageMap['file_path'] as String;
          final fileName = imageMap['file_name'] as String;

          debugPrint('[LocalAnalysis] Analyzing: $fileName (${_processedCount + 1}/$_totalCount)');

          // Get actual file path from AssetEntity with timeout
          final AssetEntity? asset = await _getAssetById(filePath).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('[LocalAnalysis] Timeout getting asset: $filePath');
              return null;
            },
          );
          
          if (asset == null) {
            debugPrint('[LocalAnalysis] Asset not found for: $filePath');
            _processedCount++;
            _emitProgress();
            continue;
          }

          // Skip videos - only process images
          if (asset.type == AssetType.video) {
            debugPrint('[LocalAnalysis] Skipping video: $fileName');
            _processedCount++;
            _emitProgress();
            continue;
          }

          final File? file = await asset.file?.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('[LocalAnalysis] Timeout getting file: $fileName');
              return null;
            },
          );
          
          if (file == null || !await file.exists()) {
            debugPrint('[LocalAnalysis] File not found for: $fileName');
            _processedCount++;
            _emitProgress();
            continue;
          }

          // Skip very large files that might cause crashes
          final fileSize = await file.length();
          if (fileSize > 20 * 1024 * 1024) { // Skip files > 20MB
            debugPrint('[LocalAnalysis] Skipping large file (${fileSize ~/ (1024 * 1024)}MB): $fileName');
            _processedCount++;
            _emitProgress();
            continue;
          }
          if (fileSize > 20 * 1024 * 1024) { // Skip files > 20MB
            debugPrint('[LocalAnalysis] Skipping large file (${fileSize ~/ (1024 * 1024)}MB): $fileName');
            _processedCount++;
            _emitProgress();
            continue;
          }

          // Analyze image with vision model (error handling in ModelInitializer)
          String? description;
          try {
            description = await modelInit.analyzeImage(file.path);
          } catch (analysisError) {
            debugPrint('[LocalAnalysis] Analysis error for $fileName: $analysisError');
            description = null;
          }
          
          if (description != null && description.isNotEmpty) {
            // Extract basic info from description
            final tags = _extractTags(description);
            final category = _determineCategory(fileName, description);
            final containsPeople = _likelyContainsPeople(description);
            final containsText = _likelyContainsText(description);
            final needsFiltering = containsPeople || containsText;

            // Update database with local analysis (store full description now)
            await _db.updateLocalAnalysis(
              imageId: imageId,
              quickTags: tags,
              basicCategory: category,
              likelyContainsPeople: containsPeople,
              likelyContainsText: containsText,
              quickDescription: description,  // Store full description
              needsPrivacyFiltering: needsFiltering,
            );

            debugPrint('[LocalAnalysis] ✓ Analyzed $fileName: $description');
          } else {
            debugPrint('[LocalAnalysis] ✗ Failed to analyze $fileName');
          }

          _processedCount++;
          _emitProgress();
          
          // Add delay after each image to ensure model is ready
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Longer pause every 5 images to allow GC and model recovery
          if (_processedCount % 5 == 0) {
            debugPrint('[LocalAnalysis] Processed ${_processedCount}/$_totalCount, pausing for GC...');
            await Future.delayed(const Duration(seconds: 3));
          }
        } catch (e, stackTrace) {
          debugPrint('[LocalAnalysis] Error analyzing image: $e');
          debugPrint('[LocalAnalysis] Stack trace: $stackTrace');
          _processedCount++;
          _emitProgress();
          
          // Wait after errors to prevent cascade failures
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      debugPrint('[LocalAnalysis] Completed batch: $_processedCount/$_totalCount images');
      
      // Check if more images remain
      final remainingImages = await _db.getImagesNeedingLocalAnalysis();
      if (remainingImages.isNotEmpty) {
        debugPrint('[LocalAnalysis] ${remainingImages.length} images still need analysis. Restart app to process next batch.');
      } else {
        debugPrint('[LocalAnalysis] All images analyzed!');
      }
    } catch (e) {
      debugPrint('[LocalAnalysis] Error in batch processing: $e');
    } finally {
      _isProcessing = false;
      _processedCount = 0;
      _totalCount = 0;
      _emitProgress();
    }
  }

  void _emitProgress() {
    _progressController?.add(progress);
  }

  Future<AssetEntity?> _getAssetById(String assetId) async {
    try {
      return await AssetEntity.fromId(assetId);
    } catch (e) {
      debugPrint('[LocalAnalysis] Error getting asset by ID: $e');
      return null;
    }
  }

  List<String> _extractTags(String description) {
    final tags = <String>[];
    final lowerDesc = description.toLowerCase();

    // Common objects
    final keywords = [
      'person', 'people', 'man', 'woman', 'child', 'baby',
      'dog', 'cat', 'animal', 'pet',
      'car', 'vehicle', 'bike', 'bicycle',
      'building', 'house', 'tree', 'sky', 'cloud',
      'food', 'drink', 'plate', 'table',
      'phone', 'computer', 'screen', 'text',
      'indoor', 'outdoor', 'nature', 'landscape',
      'portrait', 'selfie', 'group',
      'night', 'day', 'sunset', 'sunrise',
    ];

    for (var keyword in keywords) {
      if (lowerDesc.contains(keyword)) {
        tags.add(keyword);
      }
    }

    return tags.take(5).toList(); // Limit to 5 tags
  }

  String _determineCategory(String fileName, String description) {
    final lowerName = fileName.toLowerCase();
    final lowerDesc = description.toLowerCase();

    if (lowerName.contains('screenshot') || lowerName.contains('screen')) {
      return 'screenshot';
    }

    if (lowerDesc.contains('text') || lowerDesc.contains('document') || 
        lowerDesc.contains('page') || lowerDesc.contains('screen')) {
      return 'screenshot';
    }

    if (lowerDesc.contains('video') || lowerName.contains('.mp4')) {
      return 'video';
    }

    return 'photo';
  }

  bool _likelyContainsPeople(String description) {
    final lowerDesc = description.toLowerCase();
    final peopleKeywords = [
      'person', 'people', 'man', 'woman', 'child', 'baby',
      'face', 'human', 'selfie', 'portrait', 'group'
    ];

    return peopleKeywords.any((keyword) => lowerDesc.contains(keyword));
  }

  bool _likelyContainsText(String description) {
    final lowerDesc = description.toLowerCase();
    final textKeywords = [
      'text', 'word', 'letter', 'document', 'page',
      'screenshot', 'screen', 'written', 'caption',
      'message', 'chat', 'email'
    ];

    return textKeywords.any((keyword) => lowerDesc.contains(keyword));
  }

  void dispose() {
    _progressController?.close();
  }
}

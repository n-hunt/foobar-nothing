import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

class ModelInitializer {
  static final ModelInitializer _instance = ModelInitializer._internal();
  static ModelInitializer get instance => _instance;
  
  factory ModelInitializer() => _instance;
  
  ModelInitializer._internal();

  final CactusLM _lm = CactusLM();
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _error;

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  CactusLM get model => _lm;

  static const String modelName = 'lfm2-vl-450m';

  /// Initialize model on app startup
  Future<bool> initializeOnStartup() async {
    if (_isInitialized || _isInitializing) return _isInitialized;

    _isInitializing = true;
    _error = null;

    try {
      debugPrint('[ModelInitializer] Starting model initialization...');
      
      // Step 1: Download model if needed
      debugPrint('[ModelInitializer] Checking/downloading model...');
      await _lm.downloadModel(
        model: modelName,
        downloadProcessCallback: (progress, status, isError) {
          if (isError) {
            debugPrint('[ModelInitializer] Download error: $status');
          } else {
            debugPrint('[ModelInitializer] Download: $status ${progress != null ? "(${(progress * 100).toStringAsFixed(1)}%)" : ""}');
          }
        },
      );

      // Step 2: Initialize model
      debugPrint('[ModelInitializer] Initializing model...');
      await _lm.initializeModel(
        params: CactusInitParams(model: modelName)
      );

      _isInitialized = true;
      debugPrint('[ModelInitializer] Model initialized successfully!');
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[ModelInitializer] Initialization failed: $e');
      _isInitialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Analyze an image and return description
  Future<String?> analyzeImage(String imagePath) async {
    if (!_isInitialized) {
      debugPrint('[ModelInitializer] Model not initialized, cannot analyze image');
      return null;
    }

    try {
      debugPrint('[ModelInitializer] Analyzing image: $imagePath');
      
      final streamedResult = await _lm.generateCompletionStream(
        params: CactusCompletionParams(maxTokens: 200),
        messages: [
          ChatMessage(
            content: 'You are a helpful AI assistant that can analyze images.',
            role: "system"
          ),
          ChatMessage(
            content: 'Describe this image briefly in one sentence.',
            role: "user",
            images: [imagePath]
          )
        ],
      );

      String response = '';
      await for (final chunk in streamedResult.stream) {
        response += chunk;
      }

      final resp = await streamedResult.result;
      if (resp.success) {
        debugPrint('[ModelInitializer] Analysis complete: ${resp.response}');
        return resp.response;
      } else {
        debugPrint('[ModelInitializer] Analysis failed');
        return null;
      }
    } catch (e) {
      debugPrint('[ModelInitializer] Error analyzing image: $e');
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    _lm.unload();
    _isInitialized = false;
  }
}

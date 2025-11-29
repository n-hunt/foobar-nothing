import 'dart:async';
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
  String _statusMessage = 'Not initialized';

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  String get statusMessage => _statusMessage;
  CactusLM get model => _lm;

  static const String modelName = 'lfm2-vl-450m';
  static const int maxDownloadRetries = 5;
  static const Duration retryDelay = Duration(seconds: 5);

  /// Initialize model on app startup
  Future<bool> initializeOnStartup() async {
    if (_isInitialized || _isInitializing) return _isInitialized;

    _isInitializing = true;
    _error = null;

    try {
      debugPrint('[ModelInitializer] Starting model initialization...');
      
      // Step 1: Download model with retry logic
      await _downloadModelWithRetry();

      // Step 2: Initialize model
      _statusMessage = 'Initializing model...';
      debugPrint('[ModelInitializer] Initializing model...');
      await _lm.initializeModel(
        params: CactusInitParams(model: modelName)
      );

      _isInitialized = true;
      _statusMessage = 'Model ready';
      debugPrint('[ModelInitializer] Model initialized successfully!');
      return true;
    } catch (e) {
      _error = e.toString();
      _statusMessage = 'Initialization failed';
      debugPrint('[ModelInitializer] Initialization failed: $e');
      _isInitialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Download model with retry logic and resume capability
  Future<void> _downloadModelWithRetry() async {
    for (int attempt = 1; attempt <= maxDownloadRetries; attempt++) {
      try {
        _statusMessage = 'Downloading model (attempt $attempt/$maxDownloadRetries)...';
        debugPrint('[ModelInitializer] Download attempt $attempt/$maxDownloadRetries');

        final completer = Completer<void>();
        bool downloadComplete = false;
        bool hasError = false;

        await _lm.downloadModel(
          model: modelName,
          downloadProcessCallback: (progress, status, isError) {
            if (isError) {
              hasError = true;
              _statusMessage = 'Download error: $status';
              debugPrint('[ModelInitializer] Download error: $status');
              if (!completer.isCompleted) {
                completer.completeError(Exception(status));
              }
            } else {
              _statusMessage = status;
              if (progress != null) {
                _statusMessage += ' (${(progress * 100).toStringAsFixed(1)}%)';
              }
              debugPrint('[ModelInitializer] Download: $status');
              
              // Check if download is complete
              if (progress != null && progress >= 1.0 && !downloadComplete) {
                downloadComplete = true;
                if (!completer.isCompleted) {
                  completer.complete();
                }
              }
            }
          },
        ).timeout(
          const Duration(minutes: 10), // 10 minute timeout per attempt
          onTimeout: () {
            throw TimeoutException('Download timeout after 10 minutes');
          },
        );

        // Wait for download callback to confirm completion
        await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () => null, // If callback doesn't fire, assume success
        );

        if (!hasError) {
          debugPrint('[ModelInitializer] Download completed successfully');
          return; // Success - exit retry loop
        }

      } catch (e) {
        debugPrint('[ModelInitializer] Attempt $attempt failed: $e');
        
        if (attempt == maxDownloadRetries) {
          // Last attempt failed
          throw Exception('Failed to download model after $maxDownloadRetries attempts: $e');
        }

        // Wait before retrying with exponential backoff
        final delay = retryDelay * attempt;
        _statusMessage = 'Download failed, retrying in ${delay.inSeconds}s...';
        debugPrint('[ModelInitializer] Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
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
        params: CactusCompletionParams(maxTokens: 200),  // Reduced from 500 to reduce memory
        messages: [
          ChatMessage(
            content: 'You are a helpful AI assistant that analyzes images. Describe images concisely.',
            role: "system"
          ),
          ChatMessage(
            content: 'Describe this image',
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

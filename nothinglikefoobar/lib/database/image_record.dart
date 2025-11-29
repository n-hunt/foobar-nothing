import 'dart:convert';

/// Image record model representing a row in the images table
class ImageRecord {
  // Identity and File Metadata
  final String imageId;
  final String filePath;
  final String fileName;
  final int fileModifiedDate;
  final int fileSizeBytes;

  // Tier 1 (Local Analysis)
  final bool hasLocalAnalysis;
  final int? localAnalysisDate;
  final List<String>? quickTags;
  final String? basicCategory;
  final bool likelyContainsPeople;
  final bool likelyContainsText;
  final String? quickDescription;

  // Privacy Filtering
  final bool needsPrivacyFiltering;
  final bool privacyFilterApplied;
  final int? privacyFilterDate;
  final String? filteredImagePath;
  final List<String>? filterOperations;
  final List<FaceRegion>? faceRegionsBlurred;
  final List<TextRegion>? textRegionsRedacted;
  final bool originalPreserved;

  // Tier 2 (Cloud Analysis)
  final bool hasCloudAnalysis;
  final int? cloudAnalysisDate;
  final String? detailedDescription;
  final List<String>? cloudDetectedObjects;
  final String? cloudSceneUnderstanding;
  final double? cloudConfidence;
  final bool sensitiveInfoConfirmed;
  final String? riskLevel;
  final Map<String, dynamic>? cloudMetadata;
  final bool needsReprocessing;

  ImageRecord({
    required this.imageId,
    required this.filePath,
    required this.fileName,
    required this.fileModifiedDate,
    required this.fileSizeBytes,
    this.hasLocalAnalysis = false,
    this.localAnalysisDate,
    this.quickTags,
    this.basicCategory,
    this.likelyContainsPeople = false,
    this.likelyContainsText = false,
    this.quickDescription,
    this.needsPrivacyFiltering = false,
    this.privacyFilterApplied = false,
    this.privacyFilterDate,
    this.filteredImagePath,
    this.filterOperations,
    this.faceRegionsBlurred,
    this.textRegionsRedacted,
    this.originalPreserved = true,
    this.hasCloudAnalysis = false,
    this.cloudAnalysisDate,
    this.detailedDescription,
    this.cloudDetectedObjects,
    this.cloudSceneUnderstanding,
    this.cloudConfidence,
    this.sensitiveInfoConfirmed = false,
    this.riskLevel,
    this.cloudMetadata,
    this.needsReprocessing = false,
  });

  /// Create ImageRecord from database map
  factory ImageRecord.fromMap(Map<String, dynamic> map) {
    return ImageRecord(
      imageId: map['image_id'],
      filePath: map['file_path'],
      fileName: map['file_name'],
      fileModifiedDate: map['file_modified_date'],
      fileSizeBytes: map['file_size_bytes'],
      hasLocalAnalysis: map['has_local_analysis'] == 1,
      localAnalysisDate: map['local_analysis_date'],
      quickTags: map['quick_tags'] != null
          ? List<String>.from(json.decode(map['quick_tags']))
          : null,
      basicCategory: map['basic_category'],
      likelyContainsPeople: map['likely_contains_people'] == 1,
      likelyContainsText: map['likely_contains_text'] == 1,
      quickDescription: map['quick_description'],
      needsPrivacyFiltering: map['needs_privacy_filtering'] == 1,
      privacyFilterApplied: map['privacy_filter_applied'] == 1,
      privacyFilterDate: map['privacy_filter_date'],
      filteredImagePath: map['filtered_image_path'],
      filterOperations: map['filter_operations'] != null
          ? List<String>.from(json.decode(map['filter_operations']))
          : null,
      faceRegionsBlurred: map['face_regions_blurred'] != null
          ? (json.decode(map['face_regions_blurred']) as List)
              .map((e) => FaceRegion.fromMap(e))
              .toList()
          : null,
      textRegionsRedacted: map['text_regions_redacted'] != null
          ? (json.decode(map['text_regions_redacted']) as List)
              .map((e) => TextRegion.fromMap(e))
              .toList()
          : null,
      originalPreserved: map['original_preserved'] == 1,
      hasCloudAnalysis: map['has_cloud_analysis'] == 1,
      cloudAnalysisDate: map['cloud_analysis_date'],
      detailedDescription: map['detailed_description'],
      cloudDetectedObjects: map['cloud_detected_objects'] != null
          ? List<String>.from(json.decode(map['cloud_detected_objects']))
          : null,
      cloudSceneUnderstanding: map['cloud_scene_understanding'],
      cloudConfidence: map['cloud_confidence'],
      sensitiveInfoConfirmed: map['sensitive_info_confirmed'] == 1,
      riskLevel: map['risk_level'],
      cloudMetadata: map['cloud_metadata'] != null
          ? json.decode(map['cloud_metadata'])
          : null,
      needsReprocessing: map['needs_reprocessing'] == 1,
    );
  }

  /// Convert ImageRecord to database map
  Map<String, dynamic> toMap() {
    return {
      'image_id': imageId,
      'file_path': filePath,
      'file_name': fileName,
      'file_modified_date': fileModifiedDate,
      'file_size_bytes': fileSizeBytes,
      'has_local_analysis': hasLocalAnalysis ? 1 : 0,
      'local_analysis_date': localAnalysisDate,
      'quick_tags': quickTags != null ? json.encode(quickTags) : null,
      'basic_category': basicCategory,
      'likely_contains_people': likelyContainsPeople ? 1 : 0,
      'likely_contains_text': likelyContainsText ? 1 : 0,
      'quick_description': quickDescription,
      'needs_privacy_filtering': needsPrivacyFiltering ? 1 : 0,
      'privacy_filter_applied': privacyFilterApplied ? 1 : 0,
      'privacy_filter_date': privacyFilterDate,
      'filtered_image_path': filteredImagePath,
      'filter_operations':
          filterOperations != null ? json.encode(filterOperations) : null,
      'face_regions_blurred': faceRegionsBlurred != null
          ? json.encode(faceRegionsBlurred!.map((e) => e.toMap()).toList())
          : null,
      'text_regions_redacted': textRegionsRedacted != null
          ? json.encode(textRegionsRedacted!.map((e) => e.toMap()).toList())
          : null,
      'original_preserved': originalPreserved ? 1 : 0,
      'has_cloud_analysis': hasCloudAnalysis ? 1 : 0,
      'cloud_analysis_date': cloudAnalysisDate,
      'detailed_description': detailedDescription,
      'cloud_detected_objects': cloudDetectedObjects != null
          ? json.encode(cloudDetectedObjects)
          : null,
      'cloud_scene_understanding': cloudSceneUnderstanding,
      'cloud_confidence': cloudConfidence,
      'sensitive_info_confirmed': sensitiveInfoConfirmed ? 1 : 0,
      'risk_level': riskLevel,
      'cloud_metadata':
          cloudMetadata != null ? json.encode(cloudMetadata) : null,
      'needs_reprocessing': needsReprocessing ? 1 : 0,
    };
  }

  /// Get the appropriate image path based on privacy state
  String getDisplayImagePath() {
    if (privacyFilterApplied && filteredImagePath != null) {
      return filteredImagePath!;
    }
    return filePath;
  }

  /// Get processing state as human-readable string
  String getProcessingState() {
    if (!hasLocalAnalysis) return 'Pending local analysis';
    if (needsPrivacyFiltering && !privacyFilterApplied) return 'Needs privacy filtering';
    if (privacyFilterApplied && !hasCloudAnalysis) return 'Pending cloud analysis';
    if (hasCloudAnalysis) return 'Complete';
    return 'Ready';
  }

  @override
  String toString() {
    return 'ImageRecord(id: $imageId, path: $filePath, state: ${getProcessingState()})';
  }
}

/// Face region coordinates for blur tracking
class FaceRegion {
  final double x;
  final double y;
  final double width;
  final double height;
  final double? confidence;

  FaceRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.confidence,
  });

  factory FaceRegion.fromMap(Map<String, dynamic> map) {
    return FaceRegion(
      x: map['x'].toDouble(),
      y: map['y'].toDouble(),
      width: map['width'].toDouble(),
      height: map['height'].toDouble(),
      confidence: map['confidence']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'confidence': confidence,
    };
  }
}

/// Text region coordinates for redaction tracking
class TextRegion {
  final double x;
  final double y;
  final double width;
  final double height;
  final String? text;
  final String? category; // e.g., "SSN", "CREDIT_CARD", "PHONE", "ADDRESS"

  TextRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.text,
    this.category,
  });

  factory TextRegion.fromMap(Map<String, dynamic> map) {
    return TextRegion(
      x: map['x'].toDouble(),
      y: map['y'].toDouble(),
      width: map['width'].toDouble(),
      height: map['height'].toDouble(),
      text: map['text'],
      category: map['category'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'text': text,
      'category': category,
    };
  }
}

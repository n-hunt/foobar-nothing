import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ImageDatabase {
  static final ImageDatabase _instance = ImageDatabase._internal();
  static Database? _database;

  factory ImageDatabase() => _instance;

  ImageDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'privacy_gallery.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE images (
        -- Identity and File Metadata
        image_id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL UNIQUE,
        file_name TEXT NOT NULL,
        file_modified_date INTEGER NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        
        -- Tier 1 (Local Analysis) Columns
        has_local_analysis INTEGER NOT NULL DEFAULT 0,
        local_analysis_date INTEGER,
        quick_tags TEXT,
        basic_category TEXT,
        likely_contains_people INTEGER NOT NULL DEFAULT 0,
        likely_contains_text INTEGER NOT NULL DEFAULT 0,
        quick_description TEXT,
        
        -- Privacy Filtering Columns
        needs_privacy_filtering INTEGER NOT NULL DEFAULT 0,
        privacy_filter_applied INTEGER NOT NULL DEFAULT 0,
        privacy_filter_date INTEGER,
        filtered_image_path TEXT,
        filter_operations TEXT,
        face_regions_blurred TEXT,
        text_regions_redacted TEXT,
        original_preserved INTEGER NOT NULL DEFAULT 1,
        
        -- Tier 2 (Cloud Analysis) Columns
        has_cloud_analysis INTEGER NOT NULL DEFAULT 0,
        cloud_analysis_date INTEGER,
        detailed_description TEXT,
        cloud_detected_objects TEXT,
        cloud_scene_understanding TEXT,
        cloud_confidence REAL,
        sensitive_info_confirmed INTEGER NOT NULL DEFAULT 0,
        risk_level TEXT,
        cloud_metadata TEXT,
        needs_reprocessing INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_has_local_analysis ON images(has_local_analysis)');
    await db.execute('CREATE INDEX idx_needs_privacy_filtering ON images(needs_privacy_filtering)');
    await db.execute('CREATE INDEX idx_privacy_filter_applied ON images(privacy_filter_applied)');
    await db.execute('CREATE INDEX idx_has_cloud_analysis ON images(has_cloud_analysis)');
    await db.execute('CREATE INDEX idx_risk_level ON images(risk_level)');
    await db.execute('CREATE INDEX idx_file_modified_date ON images(file_modified_date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations here
  }

  // Generate stable image_id from file path using SHA-256
  String generateImageId(String filePath) {
    final normalized = filePath.toLowerCase().trim();
    final bytes = utf8.encode(normalized);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16); // First 16 characters
  }

  // Insert new image record with file metadata
  Future<void> insertImage({
    required String filePath,
    required String fileName,
    required int fileModifiedDate,
    required int fileSizeBytes,
  }) async {
    final db = await database;
    final imageId = generateImageId(filePath);

    await db.insert(
      'images',
      {
        'image_id': imageId,
        'file_path': filePath,
        'file_name': fileName,
        'file_modified_date': fileModifiedDate,
        'file_size_bytes': fileSizeBytes,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // Update local analysis results (Tier 1)
  Future<void> updateLocalAnalysis({
    required String imageId,
    required List<String> quickTags,
    required String basicCategory,
    required bool likelyContainsPeople,
    required bool likelyContainsText,
    required String quickDescription,
    required bool needsPrivacyFiltering,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'images',
      {
        'has_local_analysis': 1,
        'local_analysis_date': now,
        'quick_tags': jsonEncode(quickTags),
        'basic_category': basicCategory,
        'likely_contains_people': likelyContainsPeople ? 1 : 0,
        'likely_contains_text': likelyContainsText ? 1 : 0,
        'quick_description': quickDescription,
        'needs_privacy_filtering': needsPrivacyFiltering ? 1 : 0,
      },
      where: 'image_id = ?',
      whereArgs: [imageId],
    );
  }

  // Update privacy filtering results
  Future<void> updatePrivacyFilter({
    required String imageId,
    required String filteredImagePath,
    required List<String> filterOperations,
    required List<Map<String, dynamic>> faceRegionsBlurred,
    required List<Map<String, dynamic>> textRegionsRedacted,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'images',
      {
        'privacy_filter_applied': 1,
        'privacy_filter_date': now,
        'filtered_image_path': filteredImagePath,
        'filter_operations': jsonEncode(filterOperations),
        'face_regions_blurred': jsonEncode(faceRegionsBlurred),
        'text_regions_redacted': jsonEncode(textRegionsRedacted),
      },
      where: 'image_id = ?',
      whereArgs: [imageId],
    );
  }

  // Update cloud analysis results (Tier 2)
  Future<void> updateCloudAnalysis({
    required String imageId,
    required String detailedDescription,
    required List<String> cloudDetectedObjects,
    required String cloudSceneUnderstanding,
    required double cloudConfidence,
    required bool sensitiveInfoConfirmed,
    required String riskLevel,
    required Map<String, dynamic> cloudMetadata,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'images',
      {
        'has_cloud_analysis': 1,
        'cloud_analysis_date': now,
        'detailed_description': detailedDescription,
        'cloud_detected_objects': jsonEncode(cloudDetectedObjects),
        'cloud_scene_understanding': cloudSceneUnderstanding,
        'cloud_confidence': cloudConfidence,
        'sensitive_info_confirmed': sensitiveInfoConfirmed ? 1 : 0,
        'risk_level': riskLevel,
        'cloud_metadata': jsonEncode(cloudMetadata),
      },
      where: 'image_id = ?',
      whereArgs: [imageId],
    );
  }

  // Query: Get images needing local analysis
  Future<List<Map<String, dynamic>>> getImagesNeedingLocalAnalysis() async {
    final db = await database;
    return await db.query(
      'images',
      where: 'has_local_analysis = ?',
      whereArgs: [0],
      orderBy: 'file_modified_date DESC',
    );
  }

  // Query: Get images needing privacy filtering
  Future<List<Map<String, dynamic>>> getImagesNeedingPrivacyFiltering() async {
    final db = await database;
    return await db.query(
      'images',
      where: 'needs_privacy_filtering = ? AND privacy_filter_applied = ?',
      whereArgs: [1, 0],
      orderBy: 'file_modified_date DESC',
    );
  }

  // Query: Get images needing cloud analysis
  Future<List<Map<String, dynamic>>> getImagesNeedingCloudAnalysis() async {
    final db = await database;
    return await db.query(
      'images',
      where: 'privacy_filter_applied = ? AND has_cloud_analysis = ?',
      whereArgs: [1, 0],
      orderBy: 'file_modified_date DESC',
    );
  }

  // Query: Get all images with local analysis
  Future<List<Map<String, dynamic>>> getImagesWithLocalAnalysis() async {
    final db = await database;
    return await db.query(
      'images',
      where: 'has_local_analysis = ?',
      whereArgs: [1],
      orderBy: 'file_modified_date DESC',
    );
  }

  // Query: Search by tags
  Future<List<Map<String, dynamic>>> searchByTags(String searchTerm) async {
    final db = await database;
    return await db.query(
      'images',
      where: 'quick_tags LIKE ? AND has_local_analysis = ?',
      whereArgs: ['%$searchTerm%', 1],
      orderBy: 'file_modified_date DESC',
    );
  }

  // Query: Get images by risk level
  Future<List<Map<String, dynamic>>> getImagesByRiskLevel(String riskLevel) async {
    final db = await database;
    return await db.query(
      'images',
      where: 'risk_level = ?',
      whereArgs: [riskLevel],
      orderBy: 'file_modified_date DESC',
    );
  }

  // Query: Get image by ID
  Future<Map<String, dynamic>?> getImageById(String imageId) async {
    final db = await database;
    final results = await db.query(
      'images',
      where: 'image_id = ?',
      whereArgs: [imageId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Query: Get image by file path
  Future<Map<String, dynamic>?> getImageByFilePath(String filePath) async {
    final db = await database;
    final results = await db.query(
      'images',
      where: 'file_path = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Query: Check if image exists
  Future<bool> imageExists(String filePath) async {
    final imageId = generateImageId(filePath);
    final image = await getImageById(imageId);
    return image != null;
  }

  // Delete image record
  Future<void> deleteImage(String imageId) async {
    final db = await database;
    await db.delete(
      'images',
      where: 'image_id = ?',
      whereArgs: [imageId],
    );
  }

  // Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;
    
    final totalCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM images')
    ) ?? 0;
    
    final localAnalyzedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM images WHERE has_local_analysis = 1')
    ) ?? 0;
    
    final needsFilteringCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM images WHERE needs_privacy_filtering = 1 AND privacy_filter_applied = 0')
    ) ?? 0;
    
    final filteredCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM images WHERE privacy_filter_applied = 1')
    ) ?? 0;
    
    final cloudAnalyzedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM images WHERE has_cloud_analysis = 1')
    ) ?? 0;
    
    return {
      'total': totalCount,
      'local_analyzed': localAnalyzedCount,
      'needs_filtering': needsFilteringCount,
      'filtered': filteredCount,
      'cloud_analyzed': cloudAnalyzedCount,
    };
  }

  // Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Clear all data (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('images');
  }
}

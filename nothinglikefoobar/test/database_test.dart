import 'package:flutter_test/flutter_test.dart';
import 'package:nothinglikefoobar/database/image_database.dart';
import 'package:nothinglikefoobar/database/image_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late ImageDatabase db;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = ImageDatabase();
    await db.clearAllData();
  });

  tearDown(() async {
    await db.close();
  });

  group('ImageDatabase Tests', () {
    test('Generate consistent image IDs from file paths', () {
      final path1 = '/storage/emulated/0/DCIM/Camera/IMG_001.jpg';
      final path2 = '/storage/emulated/0/DCIM/Camera/IMG_001.jpg';
      final path3 = '/storage/emulated/0/DCIM/Camera/IMG_002.jpg';

      final id1 = db.generateImageId(path1);
      final id2 = db.generateImageId(path2);
      final id3 = db.generateImageId(path3);

      expect(id1, equals(id2)); // Same path = same ID
      expect(id1, isNot(equals(id3))); // Different path = different ID
      expect(id1.length, equals(16)); // Correct length
    });

    test('Insert and retrieve image', () async {
      await db.insertImage(
        filePath: '/test/path/image.jpg',
        fileName: 'image.jpg',
        fileModifiedDate: 1234567890,
        fileSizeBytes: 1024000,
      );

      final retrieved = await db.getImageByFilePath('/test/path/image.jpg');
      expect(retrieved, isNotNull);
      expect(retrieved!['file_name'], equals('image.jpg'));
      expect(retrieved['file_size_bytes'], equals(1024000));
      expect(retrieved['has_local_analysis'], equals(0));
    });

    test('Update local analysis', () async {
      final filePath = '/test/path/image.jpg';
      await db.insertImage(
        filePath: filePath,
        fileName: 'image.jpg',
        fileModifiedDate: 1234567890,
        fileSizeBytes: 1024000,
      );

      final imageId = db.generateImageId(filePath);
      await db.updateLocalAnalysis(
        imageId: imageId,
        quickTags: ['portrait', 'outdoor'],
        basicCategory: 'photo',
        likelyContainsPeople: true,
        likelyContainsText: false,
        quickDescription: 'Outdoor portrait photo',
        needsPrivacyFiltering: true,
      );

      final retrieved = await db.getImageById(imageId);
      expect(retrieved!['has_local_analysis'], equals(1));
      expect(retrieved['basic_category'], equals('photo'));
      expect(retrieved['likely_contains_people'], equals(1));
      expect(retrieved['needs_privacy_filtering'], equals(1));
    });

    test('Update privacy filter', () async {
      final filePath = '/test/path/image.jpg';
      await db.insertImage(
        filePath: filePath,
        fileName: 'image.jpg',
        fileModifiedDate: 1234567890,
        fileSizeBytes: 1024000,
      );

      final imageId = db.generateImageId(filePath);
      await db.updatePrivacyFilter(
        imageId: imageId,
        filteredImagePath: '/test/filtered/image_filtered.jpg',
        filterOperations: ['face_blur', 'text_redaction'],
        faceRegionsBlurred: [
          {'x': 100.0, 'y': 100.0, 'width': 50.0, 'height': 50.0}
        ],
        textRegionsRedacted: [],
      );

      final retrieved = await db.getImageById(imageId);
      expect(retrieved!['privacy_filter_applied'], equals(1));
      expect(retrieved['filtered_image_path'], equals('/test/filtered/image_filtered.jpg'));
    });

    test('Update cloud analysis', () async {
      final filePath = '/test/path/image.jpg';
      await db.insertImage(
        filePath: filePath,
        fileName: 'image.jpg',
        fileModifiedDate: 1234567890,
        fileSizeBytes: 1024000,
      );

      final imageId = db.generateImageId(filePath);
      await db.updateCloudAnalysis(
        imageId: imageId,
        detailedDescription: 'A beautiful landscape with mountains',
        cloudDetectedObjects: ['mountain', 'sky', 'tree'],
        cloudSceneUnderstanding: 'Outdoor nature scene',
        cloudConfidence: 0.95,
        sensitiveInfoConfirmed: false,
        riskLevel: 'LOW',
        cloudMetadata: {'scene_type': 'outdoor', 'time': 'daytime'},
      );

      final retrieved = await db.getImageById(imageId);
      expect(retrieved!['has_cloud_analysis'], equals(1));
      expect(retrieved['risk_level'], equals('LOW'));
      expect(retrieved['cloud_confidence'], equals(0.95));
    });

    test('Query images needing local analysis', () async {
      await db.insertImage(
        filePath: '/test/image1.jpg',
        fileName: 'image1.jpg',
        fileModifiedDate: 1234567890,
        fileSizeBytes: 1024000,
      );
      await db.insertImage(
        filePath: '/test/image2.jpg',
        fileName: 'image2.jpg',
        fileModifiedDate: 1234567891,
        fileSizeBytes: 1024001,
      );

      final needsAnalysis = await db.getImagesNeedingLocalAnalysis();
      expect(needsAnalysis.length, equals(2));
    });

    test('Query images needing privacy filtering', () async {
      final filePath = '/test/image.jpg';
      await db.insertImage(
        filePath: filePath,
        fileName: 'image.jpg',
        fileModifiedDate: 1234567890,
        fileSizeBytes: 1024000,
      );

      final imageId = db.generateImageId(filePath);
      await db.updateLocalAnalysis(
        imageId: imageId,
        quickTags: ['portrait'],
        basicCategory: 'photo',
        likelyContainsPeople: true,
        likelyContainsText: false,
        quickDescription: 'Portrait photo',
        needsPrivacyFiltering: true,
      );

      final needsFiltering = await db.getImagesNeedingPrivacyFiltering();
      expect(needsFiltering.length, equals(1));
      expect(needsFiltering.first['file_name'], equals('image.jpg'));
    });

    test('Database statistics', () async {
      await db.insertImage(
        filePath: '/test/image1.jpg',
        fileName: 'image1.jpg',
        fileModifiedDate: 1234567890,
        fileSizeBytes: 1024000,
      );
      await db.insertImage(
        filePath: '/test/image2.jpg',
        fileName: 'image2.jpg',
        fileModifiedDate: 1234567891,
        fileSizeBytes: 1024001,
      );

      final stats = await db.getDatabaseStats();
      expect(stats['total'], equals(2));
      expect(stats['local_analyzed'], equals(0));
      expect(stats['needs_filtering'], equals(0));
    });

    test('ImageRecord model serialization', () {
      final record = ImageRecord(
        imageId: 'test123',
        filePath: '/test/image.jpg',
        fileName: 'image.jpg',
        fileModifiedDate: 1234567890,
        fileSizeBytes: 1024000,
        hasLocalAnalysis: true,
        quickTags: ['portrait', 'outdoor'],
        basicCategory: 'photo',
      );

      final map = record.toMap();
      expect(map['image_id'], equals('test123'));
      expect(map['has_local_analysis'], equals(1));

      final reconstructed = ImageRecord.fromMap(map);
      expect(reconstructed.imageId, equals('test123'));
      expect(reconstructed.quickTags, equals(['portrait', 'outdoor']));
    });
  });
}

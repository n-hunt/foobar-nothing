# Image Database Schema

## Overview
This database implements a dual-tier analysis system with local-first privacy filtering followed by cloud enhancement. The schema tracks images through multiple processing stages while preserving privacy metadata.

## Database Design

### Single Table: `images`

All image data and processing states are stored in a single denormalized table for optimal query performance and atomic operations.

## Column Reference

### Identity and File Metadata
| Column | Type | Description |
|--------|------|-------------|
| `image_id` | TEXT PRIMARY KEY | 16-character SHA-256 hash of normalized file path |
| `file_path` | TEXT NOT NULL UNIQUE | Full absolute path to original image file |
| `file_name` | TEXT NOT NULL | Filename only for display purposes |
| `file_modified_date` | INTEGER NOT NULL | Unix timestamp of file modification |
| `file_size_bytes` | INTEGER NOT NULL | File size for tracking and validation |

### Tier 1 (Local Analysis)
| Column | Type | Description |
|--------|------|-------------|
| `has_local_analysis` | INTEGER (BOOLEAN) | Flag indicating local processing completion |
| `local_analysis_date` | INTEGER | Unix timestamp of local analysis |
| `quick_tags` | TEXT (JSON) | Array of searchable keywords |
| `basic_category` | TEXT | Classification: photo, screenshot, document |
| `likely_contains_people` | INTEGER (BOOLEAN) | Probability flag for face detection routing |
| `likely_contains_text` | INTEGER (BOOLEAN) | Probability flag for text recognition routing |
| `quick_description` | TEXT | Brief single-sentence description |

### Privacy Filtering
| Column | Type | Description |
|--------|------|-------------|
| `needs_privacy_filtering` | INTEGER (BOOLEAN) | Determined by vision model |
| `privacy_filter_applied` | INTEGER (BOOLEAN) | Indicates filtering completion |
| `privacy_filter_date` | INTEGER | Unix timestamp of filtering operation |
| `filtered_image_path` | TEXT | Path to locally filtered version |
| `filter_operations` | TEXT (JSON) | Array describing operations performed |
| `face_regions_blurred` | TEXT (JSON) | Array of face coordinates that were blurred |
| `text_regions_redacted` | TEXT (JSON) | Array of text coordinates that were redacted |
| `original_preserved` | INTEGER (BOOLEAN) | Indicates if original is kept (always true) |

### Tier 2 (Cloud Analysis)
| Column | Type | Description |
|--------|------|-------------|
| `has_cloud_analysis` | INTEGER (BOOLEAN) | Flag indicating cloud processing completion |
| `cloud_analysis_date` | INTEGER | Unix timestamp of cloud analysis |
| `detailed_description` | TEXT | Rich contextual description from Gemini |
| `cloud_detected_objects` | TEXT (JSON) | Array of objects identified in filtered image |
| `cloud_scene_understanding` | TEXT | String describing overall scene context |
| `cloud_confidence` | REAL | Floating point confidence score |
| `sensitive_info_confirmed` | INTEGER (BOOLEAN) | Cloud verification of sensitivity |
| `risk_level` | TEXT | Categorization: LOW, MEDIUM, HIGH |
| `cloud_metadata` | TEXT (JSON) | Additional cloud findings |
| `needs_reprocessing` | INTEGER (BOOLEAN) | Flag for re-analysis requirement |

## Indexes

Performance-critical indexes for common queries:

```sql
CREATE INDEX idx_has_local_analysis ON images(has_local_analysis);
CREATE INDEX idx_needs_privacy_filtering ON images(needs_privacy_filtering);
CREATE INDEX idx_privacy_filter_applied ON images(privacy_filter_applied);
CREATE INDEX idx_has_cloud_analysis ON images(has_cloud_analysis);
CREATE INDEX idx_risk_level ON images(risk_level);
CREATE INDEX idx_file_modified_date ON images(file_modified_date);
```

## State Machine Flow

### States:
1. **Initial**: `has_local_analysis = 0`
2. **Local Analyzed**: `has_local_analysis = 1, needs_privacy_filtering = 0`
3. **Needs Filtering**: `has_local_analysis = 1, needs_privacy_filtering = 1, privacy_filter_applied = 0`
4. **Filtered**: `privacy_filter_applied = 1, has_cloud_analysis = 0`
5. **Complete**: `has_cloud_analysis = 1`

### Transitions:
- Initial → Local Analyzed: After local vision model processing
- Local Analyzed → Needs Filtering: Vision model detects sensitive content
- Local Analyzed → Filtered: No sensitive content, skip filtering
- Needs Filtering → Filtered: ML Kit detection and image manipulation complete
- Filtered → Complete: Cloud analysis of filtered image complete

## JSON Field Formats

### quick_tags
```json
["portrait", "outdoor", "sunset", "beach"]
```

### filter_operations
```json
["face_blur", "text_redaction", "document_obscuration"]
```

### face_regions_blurred
```json
[
  {"x": 120.5, "y": 80.3, "width": 100.2, "height": 120.8, "confidence": 0.95},
  {"x": 350.0, "y": 90.0, "width": 95.5, "height": 115.2, "confidence": 0.89}
]
```

### text_regions_redacted
```json
[
  {"x": 200.0, "y": 500.0, "width": 300.0, "height": 50.0, "text": "***-**-****", "category": "SSN"},
  {"x": 100.0, "y": 600.0, "width": 250.0, "height": 40.0, "text": "REDACTED", "category": "CREDIT_CARD"}
]
```

### cloud_detected_objects
```json
["tree", "sky", "building", "car", "bicycle"]
```

### cloud_metadata
```json
{
  "scene_type": "urban_outdoor",
  "time_of_day": "afternoon",
  "weather": "sunny",
  "activity": "transportation",
  "location_type": "street"
}
```

## Common Queries

### Get images needing local analysis:
```sql
SELECT * FROM images WHERE has_local_analysis = 0 ORDER BY file_modified_date DESC;
```

### Get images needing privacy filtering:
```sql
SELECT * FROM images 
WHERE needs_privacy_filtering = 1 AND privacy_filter_applied = 0 
ORDER BY file_modified_date DESC;
```

### Get images ready for cloud processing:
```sql
SELECT * FROM images 
WHERE privacy_filter_applied = 1 AND has_cloud_analysis = 0 
ORDER BY file_modified_date DESC;
```

### Search by tags:
```sql
SELECT * FROM images 
WHERE quick_tags LIKE '%beach%' AND has_local_analysis = 1 
ORDER BY file_modified_date DESC;
```

### Filter by risk level:
```sql
SELECT * FROM images WHERE risk_level = 'HIGH' ORDER BY cloud_analysis_date DESC;
```

## Usage Example

```dart
import 'package:your_app/database/image_database.dart';

final db = ImageDatabase();

// Insert new image
await db.insertImage(
  filePath: '/storage/emulated/0/DCIM/Camera/IMG_20231120_153045.jpg',
  fileName: 'IMG_20231120_153045.jpg',
  fileModifiedDate: 1700493045000,
  fileSizeBytes: 3245678,
);

// Update after local analysis
await db.updateLocalAnalysis(
  imageId: 'a1b2c3d4e5f6g7h8',
  quickTags: ['portrait', 'indoor', 'person'],
  basicCategory: 'photo',
  likelyContainsPeople: true,
  likelyContainsText: false,
  quickDescription: 'Indoor portrait photo',
  needsPrivacyFiltering: true,
);

// Update after privacy filtering
await db.updatePrivacyFilter(
  imageId: 'a1b2c3d4e5f6g7h8',
  filteredImagePath: '/data/user/0/com.app/files/filtered/a1b2c3d4e5f6g7h8_filtered.jpg',
  filterOperations: ['face_blur'],
  faceRegionsBlurred: [
    {'x': 120.5, 'y': 80.3, 'width': 100.2, 'height': 120.8, 'confidence': 0.95}
  ],
  textRegionsRedacted: [],
);

// Update after cloud analysis
await db.updateCloudAnalysis(
  imageId: 'a1b2c3d4e5f6g7h8',
  detailedDescription: 'Indoor scene showing a room with furniture and decor',
  cloudDetectedObjects: ['chair', 'table', 'lamp', 'wall'],
  cloudSceneUnderstanding: 'Residential interior, living room setting',
  cloudConfidence: 0.92,
  sensitiveInfoConfirmed: false,
  riskLevel: 'LOW',
  cloudMetadata: {
    'scene_type': 'indoor_residential',
    'lighting': 'artificial',
    'room_type': 'living_room'
  },
);

// Query images
final needsAnalysis = await db.getImagesNeedingLocalAnalysis();
final needsFiltering = await db.getImagesNeedingPrivacyFiltering();
final stats = await db.getDatabaseStats();
```

## Privacy Guarantees

1. **Original Never Modified**: `original_preserved` always true, file_path points to unmodified DCIM image
2. **Cloud Receives Filtered Only**: Cloud analysis queries filtered_image_path, never file_path
3. **Audit Trail**: All operations timestamped, regions recorded with coordinates
4. **Conditional Processing**: ML Kit only invoked based on vision model flags
5. **Local-First**: Cloud processing is optional enhancement, system functional with local tier only

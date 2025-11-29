import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database/image_database.dart';
import 'database/image_record.dart';

class DebugView extends StatefulWidget {
  const DebugView({super.key});

  @override
  State<DebugView> createState() => _DebugViewState();
}

class _DebugViewState extends State<DebugView> {
  final ImageDatabase _db = ImageDatabase();
  Map<String, int>? _stats;
  List<ImageRecord> _allImages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDebugData();
  }

  Future<void> _loadDebugData() async {
    setState(() => _isLoading = true);

    try {
      final stats = await _db.getDatabaseStats();
      final allImagesRaw = await _db.getImagesWithLocalAnalysis();
      final allImages = allImagesRaw.map((map) => ImageRecord.fromMap(map)).toList();

      setState(() {
        _stats = stats;
        _allImages = allImages;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading debug data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading ? _buildLoading() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFD71921)),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: const Color(0xFFD71921),
      onRefresh: _loadDebugData,
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStatsSection(),
          const SizedBox(height: 24),
          _buildActionsSection(),
          const SizedBox(height: 24),
          _buildImagesSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "DEBUG",
              style: GoogleFonts.shareTechMono(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(width: 8, height: 8, color: const Color(0xFFD71921)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "DATABASE STATE",
          style: GoogleFonts.shareTechMono(
            fontSize: 12,
            color: Colors.grey[600],
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: Colors.grey[800]),
      ],
    );
  }

  Widget _buildStatsSection() {
    if (_stats == null) {
      return const Text("No stats available", style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "STATISTICS",
          style: GoogleFonts.shareTechMono(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD71921),
          ),
        ),
        const SizedBox(height: 16),
        _buildStatCard("TOTAL IMAGES", _stats!['total']!, Colors.white),
        const SizedBox(height: 8),
        _buildStatCard("LOCAL ANALYZED", _stats!['local_analyzed']!, Colors.blue),
        const SizedBox(height: 8),
        _buildStatCard("NEEDS FILTERING", _stats!['needs_filtering']!, Colors.orange),
        const SizedBox(height: 8),
        _buildStatCard("FILTERED", _stats!['filtered']!, Colors.purple),
        const SizedBox(height: 8),
        _buildStatCard("CLOUD ANALYZED", _stats!['cloud_analyzed']!, Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.5,
              color: Colors.grey[400],
            ),
          ),
          Text(
            value.toString(),
            style: GoogleFonts.shareTechMono(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ACTIONS",
          style: GoogleFonts.shareTechMono(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD71921),
          ),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          "REFRESH DATA",
          Icons.refresh,
          _loadDebugData,
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          "CLEAR DATABASE",
          Icons.delete_forever,
          _confirmClearDatabase,
          color: Colors.red[700]!,
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color ?? Colors.white),
        label: Text(
          label,
          style: TextStyle(
            letterSpacing: 1.5,
            color: color ?? Colors.white,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: color ?? Colors.grey[800]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          "CLEAR DATABASE?",
          style: GoogleFonts.shareTechMono(color: Colors.white),
        ),
        content: const Text(
          "This will delete all database records. Image files will not be affected.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.clearAllData();
      await _loadDebugData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Database cleared"),
            backgroundColor: Color(0xFFD71921),
          ),
        );
      }
    }
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "IMAGES (${_allImages.length})",
          style: GoogleFonts.shareTechMono(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD71921),
          ),
        ),
        const SizedBox(height: 16),
        if (_allImages.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.image_not_supported, size: 48, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  Text(
                    "NO IMAGES IN DATABASE",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ..._allImages.map((image) => _buildImageCard(image)),
      ],
    );
  }

  Widget _buildImageCard(ImageRecord image) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  image.fileName,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(image),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "ID: ${image.imageId}",
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          _buildProcessingFlags(image),
          if (image.quickDescription != null) ...[
            const SizedBox(height: 12),
            Text(
              image.quickDescription!,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
          if (image.quickTags != null && image.quickTags!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: image.quickTags!.map((tag) => _buildTag(tag)).toList(),
            ),
          ],
          if (image.riskLevel != null) ...[
            const SizedBox(height: 8),
            Text(
              "Risk: ${image.riskLevel}",
              style: TextStyle(
                fontSize: 11,
                color: _getRiskColor(image.riskLevel!),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ImageRecord image) {
    Color color;
    String text;

    if (!image.hasLocalAnalysis) {
      color = Colors.grey;
      text = "PENDING";
    } else if (image.needsPrivacyFiltering && !image.privacyFilterApplied) {
      color = Colors.orange;
      text = "FILTERING";
    } else if (image.privacyFilterApplied && !image.hasCloudAnalysis) {
      color = Colors.purple;
      text = "CLOUD PENDING";
    } else if (image.hasCloudAnalysis) {
      color = Colors.green;
      text = "COMPLETE";
    } else {
      color = Colors.blue;
      text = "READY";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.2 * 255).round()),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildProcessingFlags(ImageRecord image) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _buildFlag("LOCAL", image.hasLocalAnalysis),
        _buildFlag("PEOPLE", image.likelyContainsPeople),
        _buildFlag("TEXT", image.likelyContainsText),
        _buildFlag("NEEDS FILTER", image.needsPrivacyFiltering),
        _buildFlag("FILTERED", image.privacyFilterApplied),
        _buildFlag("CLOUD", image.hasCloudAnalysis),
      ],
    );
  }

  Widget _buildFlag(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD71921).withAlpha((0.2 * 255).round()) : Colors.transparent,
        border: Border.all(
          color: active ? const Color(0xFFD71921) : Colors.grey[800]!,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: active ? const Color(0xFFD71921) : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha((0.2 * 255).round()),
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag,
        style: const TextStyle(fontSize: 10, color: Colors.blue),
      ),
    );
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

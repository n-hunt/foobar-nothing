import 'package:photo_manager/photo_manager.dart';

class BinService {
  static final BinService _instance = BinService._internal();
  factory BinService() => _instance;
  BinService._internal();

  // Store the actual assets here for instant access
  final List<AssetEntity> _binnedAssets = [];

  // Check if an asset is in the bin
  bool isInBin(AssetEntity asset) {
    return _binnedAssets.any((a) => a.id == asset.id);
  }

  // Move item to bin
  void addToBin(AssetEntity asset) {
    if (!isInBin(asset)) {
      _binnedAssets.add(asset);
    }
  }

  // Restore item from bin
  void restore(AssetEntity asset) {
    _binnedAssets.removeWhere((a) => a.id == asset.id);
  }

  // Empty bin
  Future<void> emptyBin() async {
    // In a real app: await PhotoManager.editor.deleteWithIds(_binnedAssets.map((e) => e.id).toList());
    _binnedAssets.clear();
  }

  // Get the list of deleted items for the Bin View
  List<AssetEntity> get assets => List.unmodifiable(_binnedAssets);

  int get count => _binnedAssets.length;
}
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

class BinService extends ChangeNotifier {
  static final BinService _instance = BinService._internal();
  factory BinService() => _instance;

  BinService._internal();

  // Store binned asset IDs
  final Set<String> _binnedIds = {};

  // Store asset entities for display
  final Map<String, AssetEntity> _binnedAssets = {};

  // ValueNotifier for reactive bin ID list
  final ValueNotifier<List<String>> _binnedIdsNotifier = ValueNotifier<List<String>>([]);

  ValueListenable<List<String>> get binnedIdsListenable => _binnedIdsNotifier;

  // Getters
  bool isInBin(String assetId) => _binnedIds.contains(assetId);


  int get count => _binnedIds.length;

  List<AssetEntity> get assets => _binnedAssets.values.toList();

  // Add to bin
  void addToBin(AssetEntity asset) {
    if (!_binnedIds.contains(asset.id)) {
      _binnedIds.add(asset.id);
      _binnedAssets[asset.id] = asset;
      _updateNotifier();
      notifyListeners();
    }
  }

  // Restore from bin
  void restore(AssetEntity asset) {
    if (_binnedIds.contains(asset.id)) {
      _binnedIds.remove(asset.id);
      _binnedAssets.remove(asset.id);
      _updateNotifier();
      notifyListeners();
    }
  }

  // Empty bin completely
  Future<void> emptyBin() async {
    if (_binnedIds.isEmpty) return;

    // Uncomment for production:
    // await PhotoManager.editor.deleteWithIds(_binnedIds.toList());

    _binnedIds.clear();
    _binnedAssets.clear();
    _updateNotifier();
    notifyListeners();
  }

  // Restore all
  void restoreAll() {
    _binnedIds.clear();
    _binnedAssets.clear();
    _updateNotifier();
    notifyListeners();
  }

  void _updateNotifier() {
    _binnedIdsNotifier.value = _binnedIds.toList();
  }
}
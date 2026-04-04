import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FeedViewController extends ChangeNotifier {
  static const _kKey = 'full_screen_view';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isFullScreenView = false;

  bool get isFullScreenView => _isFullScreenView;

  FeedViewController() {
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await _storage.read(key: _kKey);
      if (saved != null) {
        _isFullScreenView = saved == 'true';
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setFullScreenView(bool value) async {
    if (_isFullScreenView == value) return;
    _isFullScreenView = value;
    notifyListeners();
    try {
      await _storage.write(key: _kKey, value: value.toString());
    } catch (_) {}
  }
}

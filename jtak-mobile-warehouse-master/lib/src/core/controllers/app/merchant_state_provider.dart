import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// Merchant State Provider (Store Open/Closed, Sound Alert, Active Navigation Tab)
/// ---------------------------------------------------------------------------

class MerchantStateProvider extends ChangeNotifier {
  static const String _storeOpenKey = 'merchant_is_store_open';
  static const String _soundAlertKey = 'merchant_is_sound_alert_enabled';

  int _currentIndex = 0;
  bool _isStoreOpen = true;
  bool _isSoundAlertEnabled = true;
  int _pendingOrdersCount = 0;

  int get currentIndex => _currentIndex;
  bool get isStoreOpen => _isStoreOpen;
  bool get isSoundAlertEnabled => _isSoundAlertEnabled;
  int get pendingOrdersCount => _pendingOrdersCount;

  MerchantStateProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isStoreOpen = prefs.getBool(_storeOpenKey) ?? true;
      _isSoundAlertEnabled = prefs.getBool(_soundAlertKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  Future<void> toggleStoreStatus() async {
    _isStoreOpen = !_isStoreOpen;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storeOpenKey, _isStoreOpen);
    } catch (_) {}
  }

  Future<void> setStoreOpen(bool value) async {
    if (_isStoreOpen != value) {
      _isStoreOpen = value;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_storeOpenKey, _isStoreOpen);
      } catch (_) {}
    }
  }

  void playSoundPreview() {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  Future<void> toggleSoundAlert() async {
    _isSoundAlertEnabled = !_isSoundAlertEnabled;
    if (_isSoundAlertEnabled) {
      playSoundPreview();
    } else {
      HapticFeedback.lightImpact();
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundAlertKey, _isSoundAlertEnabled);
    } catch (_) {}
  }

  Future<void> setSoundAlertEnabled(bool value) async {
    if (_isSoundAlertEnabled != value) {
      _isSoundAlertEnabled = value;
      if (_isSoundAlertEnabled) {
        playSoundPreview();
      } else {
        HapticFeedback.lightImpact();
      }
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_soundAlertKey, _isSoundAlertEnabled);
      } catch (_) {}
    }
  }

  void updatePendingOrdersCount(int count) {
    if (_pendingOrdersCount != count) {
      _pendingOrdersCount = count;
      notifyListeners();
    }
  }
}

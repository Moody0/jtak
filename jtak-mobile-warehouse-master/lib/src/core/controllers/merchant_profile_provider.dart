import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../../utils/providers/sol_api.dart';
import '../models/merchant_profile_model.dart';
import '../services/locator.dart';
import 'app/merchant_state_provider.dart';

/// ---------------------------------------------------------------------------
/// Merchant Profile Provider (Handles store details, branding visuals & status)
/// ---------------------------------------------------------------------------

class MerchantProfileProvider extends ChangeNotifier {
  final SolApi _api = locator<SolApi>();

  MerchantProfileModel? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  MerchantProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  /// Clear all cached profile state on account switch or logout
  void reset() {
    _profile = null;
    _isLoading = false;
    _isSaving = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetch merchant profile from backend
  Future<void> loadProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getRequest('/Merchant/Profile');
      if (data is Map<String, dynamic>) {
        _profile = MerchantProfileModel.fromJson(data);
        // Sync active state with MerchantStateProvider
        if (locator.isRegistered<MerchantStateProvider>()) {
          locator<MerchantStateProvider>().setStoreOpen(_profile!.active);
        }
      }
    } catch (e) {
      log('Error loading merchant profile: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update store profile fields & brand visuals
  Future<bool> updateProfile({
    required String title,
    required String shortDescription,
    required String description,
    required String phone1,
    required String phone2,
    required String address,
    required int shippingCoverageInMeters,
    String? logo,
    String? coverBanner,
    double? lat,
    double? lng,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'title': title.trim(),
        'shortDescription': shortDescription.trim(),
        'description': description.trim(),
        'phone1': phone1.trim(),
        'phone2': phone2.trim(),
        'address': address.trim(),
        'shippingCoverageInMeters': shippingCoverageInMeters,
        if (logo != null && logo.isNotEmpty) 'logo': logo,
        if (coverBanner != null && coverBanner.isNotEmpty) 'coverBanner': coverBanner,
        if (lat != null && lat != 0) 'lat': lat,
        if (lng != null && lng != 0) 'lng': lng,
      };

      final data = await _api.putRequest('/Merchant/Profile', body);
      if (data is Map<String, dynamic>) {
        _profile = MerchantProfileModel.fromJson(data);
        if (locator.isRegistered<MerchantStateProvider>()) {
          locator<MerchantStateProvider>().setStoreOpen(_profile!.active);
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      log('Error updating merchant profile: $e');
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Toggle online / offline status on backend
  Future<bool> toggleStoreStatus([bool? targetStatus]) async {
    try {
      final desiredStatus = targetStatus ?? !(_profile?.active ?? true);
      final body = {'active': desiredStatus};
      final res = await _api.putRequest('/Merchant/ToggleStatus', body);
      
      final bool nowActive = res is bool ? res : desiredStatus;
      if (_profile != null) {
        _profile = _profile!.copyWith(active: nowActive);
      }
      if (locator.isRegistered<MerchantStateProvider>()) {
        locator<MerchantStateProvider>().setStoreOpen(nowActive);
      }
      notifyListeners();
      return true;
    } catch (e) {
      log('Error toggling merchant status: $e');
      return false;
    }
  }
}

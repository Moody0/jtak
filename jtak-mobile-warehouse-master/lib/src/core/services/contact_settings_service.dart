import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/providers/sol_api.dart';
import '../models/contact_settings_model.dart';

/// Centralized Service for fetching, caching, and serving unified support & contact settings
/// across JTAK merchant / warehouse application.
class ContactSettingsService extends ChangeNotifier {
  static const String _kStorageKey = 'k_jtak_contact_settings_cache_merchant_v1';
  static final ContactSettingsService instance =
      ContactSettingsService._internal();

  ContactSettingsService._internal();

  factory ContactSettingsService() => instance;

  ContactSettingsModel _settings = const ContactSettingsModel();
  bool _isInitialized = false;
  bool _isLoading = false;

  ContactSettingsModel get settings => _settings;
  bool get isLoading => _isLoading;

  String get phoneNumber => _settings.phoneNumber;
  String get phoneInternational => _settings.phoneInternational;
  String get phoneFormatted => _settings.phoneFormatted;
  String get whatsAppNumber => _settings.whatsAppNumber;
  String get supportEmail => _settings.supportEmail;
  String get facebookUrl => _settings.facebookUrl;
  String get instagramUrl => _settings.instagramUrl;
  String get youtubeUrl => _settings.youtubeUrl;
  String get telegramUrl => _settings.telegramUrl;
  String get workingHoursAr => _settings.workingHoursAr;
  String get workingHoursEn => _settings.workingHoursEn;
  String get addressAr => _settings.addressAr;
  String get addressEn => _settings.addressEn;

  /// Initializes cached settings and fetches fresh ones asynchronously
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kStorageKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        _settings = ContactSettingsModel.fromJsonString(cachedJson);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ContactSettingsService (Merchant): Failed to read cache: $e');
    }

    // Fetch fresh settings in background (non-blocking)
    unawaited(fetchSettings());
  }

  /// Fetches latest contact settings from public backend endpoint
  Future<void> fetchSettings() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final url = Uri.parse('${SolApi.baseURL}/api/v1/Customer/Contact/Settings');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _settings = ContactSettingsModel.fromJson(data);

        // Cache locally for offline and instant startup
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kStorageKey, _settings.toJsonString());
        } catch (_) {}

        notifyListeners();
      }
    } catch (e) {
      debugPrint('ContactSettingsService (Merchant): Failed to fetch live settings: $e');
    } finally {
      _isLoading = false;
    }
  }
}

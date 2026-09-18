import 'dart:async';
import 'dart:convert';

import 'package:app_jtak_warehouse/src/core/controllers/app/merchant_state_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/app_parameters_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/merchant_profile_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/payment_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/products_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/user_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:app_jtak_warehouse/src/core/models/user_model.dart';
import '../../utils/utilities/global_var.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locator.dart';
import '../../config/constants/shard_preference_kay.dart';
import '../../utils/providers/sol_api.dart';
import '../models/authorization_model.dart';
import '../controllers/app/base_provider.dart';
import '../../config/constants/app_constant.dart';

class AuthenticationService extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  AuthorizationModel? _authorizationModel;

  UserModel? _user;

  UserModel? get user => _user;
  set user(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  bool isLogin() {
    return GlobalVar.checkString(getAccessToken);
  }

  String get getAccessToken => _authorizationModel?.accessToken ?? '';

  Future<void> loginByPhone(String phoneNumber, String code) async {
    try {
      await clearUserSessionData();

      Map<String, String> body = {
        "grant_type": "sol:sms_code",
        "username": phoneNumber,
        "code": code,
        "scope": "offline_access profile roles phone email",
      };
      Map<String, String> headers = _api.getHeaders(contentType: 'application/x-www-form-urlencoded');

      debugPrint(headers.toString());
      var data = await _api.postRequest('/connect/token', body, headers: headers, apiPrefex: '');
      _authorizationModel = AuthorizationModel.fromJson(data);
      saveAuthorizationData();
      _api.accessToken = _authorizationModel?.accessToken;
      await loadUserData();
      if (user != null && (user!.role == null || user!.role != kMerchantRole)) {
        user!.role = kMerchantRole;
      }
      if (locator.isRegistered<MerchantProfileProvider>()) {
        await locator<MerchantProfileProvider>().loadProfile();
      }
    } catch (err) {
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await clearUserSessionData();

      Map<String, String> body = {
        "grant_type": "password",
        "username": email,
        "password": password,
        "scope": "offline_access profile roles phone email",
      };
      Map<String, String> headers = _api.getHeaders(contentType: 'application/x-www-form-urlencoded');

      debugPrint(headers.toString());
      var data = await _api.postRequest('/connect/token', body, headers: headers, apiPrefex: '');
      _authorizationModel = AuthorizationModel.fromJson(data);
      saveAuthorizationData();
      _api.accessToken = _authorizationModel?.accessToken;
      await loadUserData();
      if (user != null && (user!.role == null || user!.role != kMerchantRole)) {
        user!.role = kMerchantRole;
      }
      if (locator.isRegistered<MerchantProfileProvider>()) {
        await locator<MerchantProfileProvider>().loadProfile();
      }
    } catch (err) {
      rethrow;
    }
  }

  Future loadUserData() async {
    if (_api.accessToken == null || _api.accessToken!.isEmpty || _api.accessToken == 'test_token_123456') {
      return;
    }
    try {
      var data = await _api.getRequest("/connect/userinfo", apiPrefex: '');
      user = data != null ? UserModel.fromMap(data) : null;
    } catch (e) {
      debugPrint('loadUserData note: $e');
    }
  }

  Future<void> getAuthorizationData() async {
    try {
      if (_authorizationModel == null) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey(authorizationKey)) {
          final rawStr = prefs.getString(authorizationKey);
          if (rawStr == null || rawStr.isEmpty) {
            await prefs.remove(authorizationKey);
            return;
          }
          final authorizationData = json.decode(rawStr) as Map<String, dynamic>;
          final model = AuthorizationModel.fromJson(authorizationData);
          if (model.accessToken == null ||
              model.accessToken!.isEmpty ||
              model.accessToken == 'test_token_123456') {
            // Discard stale dummy test tokens
            await prefs.remove(authorizationKey);
            _authorizationModel = null;
            _api.accessToken = null;
            return;
          }
          _authorizationModel = model;
          _api.accessToken = _authorizationModel?.accessToken;
        }
      }
    } catch (error) {
      rethrow;
    }
  }

  void saveAuthorizationData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(authorizationKey, json.encode(_authorizationModel!.toJson()));
  }

  Future<void> checkAuthorizationToken() async {
    // log('/////////////////////////////////////////////////////////////// check Authorization ');
    await getAuthorizationData();
    try {
      if (_authorizationModel != null && _authorizationModel!.accessToken!.isNotEmpty) {
        Duration diff = DateTime.parse(_authorizationModel!.expiresIn!).difference(DateTime.now());
        if (diff.isNegative || diff.inMinutes < 10) {
          if (kDebugMode) {
            debugPrint('/////////////////////////////////////////////////////////////// Request refresh_token :$diff ');
          }
          Map<String, String> body = {
            "grant_type": "refresh_token",
            "refresh_token": _authorizationModel!.refreshToken!,
            "scope": "offline_access profile roles phone email",
          };
          Map<String, String> headers = _api.getHeaders(contentType: 'application/x-www-form-urlencoded');

          var data = await _api.postRequest('/connect/token', body, headers: headers, apiPrefex: '');
          _authorizationModel = AuthorizationModel.fromJson(data);
          _api.accessToken = _authorizationModel?.accessToken!;
          saveAuthorizationData();
        }
      }
    } catch (error) {
      logOut();
      debugPrint(error.toString());
    }
  }

  /// Clears all authenticated/user-scoped state while preserving global app settings (language, theme)
  Future<void> clearUserSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(authorizationKey)) {
        await prefs.remove(authorizationKey);
      }
      final allKeys = prefs.getKeys().toList();
      for (final key in allKeys) {
        if (key.startsWith('merchant_prep_deadline_') ||
            key.startsWith('merchant_picked_items_')) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}

    // Reset all user-scoped singleton providers
    if (locator.isRegistered<MerchantProfileProvider>()) {
      locator<MerchantProfileProvider>().reset();
    }
    if (locator.isRegistered<MerchantStateProvider>()) {
      locator<MerchantStateProvider>().reset();
    }
    if (locator.isRegistered<OrderProvider>()) {
      locator<OrderProvider>().reset();
    }
    if (locator.isRegistered<PaymentProvider>()) {
      locator<PaymentProvider>().reset();
    }
    if (locator.isRegistered<ProductsProvider>()) {
      locator<ProductsProvider>().reset();
    }
    if (locator.isRegistered<UserProvider>()) {
      locator<UserProvider>().reset();
    }
    if (locator.isRegistered<AppParametersProvider>()) {
      try {
        final prov = locator<AppParametersProvider>();
        await prov.resetData();
      } catch (_) {}
    }

    // Evict cached images in memory so old profile avatar/banner is never rendered
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    _user = null;
    _authorizationModel = null;
    _api.accessToken = null;
    notifyListeners();
  }

  Future logOut() async {
    await clearUserSessionData();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants/shard_preference_kay.dart';
import '../../utils/providers/sol_api.dart';
import '../controllers/app/app_state_manager.dart';
import '../controllers/app/base_provider.dart';
import '../controllers/app_parameters_provider.dart';
import '../models/authorization_model.dart';
import '../models/user/user_model.dart';
import 'locator.dart';

class AuthenticationService extends BaseProvider {
  static const String kUserProfileKey = 'k_jtak_active_user_profile_v2';
  static const String kRegisteredUsersDirectoryKey =
      'k_jtak_users_directory_v2';

  AuthenticationService() {
    getAuthorizationData();
  }

  SolApi get _api => locator<SolApi>();
  AuthorizationModel? _authorizationModel;
  UserModel? _user;

  UserModel? get user => _user;
  set user(UserModel? user) {
    _user = user;
    if (user != null) {
      saveUserData(user);
    }
    notifyListeners();
  }

  bool isLogin() {
    final token = _authorizationModel?.accessToken ?? _api.accessToken;
    return isUsableAccessToken(token);
  }

  static bool isUsableAccessToken(String? token) {
    return token != null &&
        token.trim().isNotEmpty &&
        !token.startsWith('auth_jwt_token_') &&
        !token.startsWith('live_user_token_');
  }

  static bool isIncompleteProfileName(String? name) {
    final value = name?.trim() ?? '';
    return value.isEmpty ||
        value == 'عميل جيتك' ||
        value == 'مستخدم جيتك' ||
        value == 'عميل جتاك' ||
        value == 'مستخدم جتاك';
  }

  bool get hasCompletedProfile =>
      isLogin() && !isIncompleteProfileName(_user?.fullName);

  String get getAccessToken => _authorizationModel?.accessToken ?? '';

  Future<void> loginByPhone(String phoneNumber, String code) async {
    final cleanPhone = phoneNumber.trim();
    final cleanCode = code.replaceAll(RegExp(r'\s+'), '').trim();

    final altPhone =
        cleanPhone.startsWith('+') ? cleanPhone.substring(1) : '+$cleanPhone';
    final localPhone =
        cleanPhone.startsWith('+963') ? ('0${cleanPhone.substring(4)}') : '';
    final candidatePhones = [cleanPhone, altPhone, localPhone]
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

    dynamic lastError;
    bool success = false;

    for (final phoneAttempt in candidatePhones) {
      try {
        Map<String, String> body = {
          "grant_type": "sol:sms_code",
          "username": phoneAttempt,
          "code": cleanCode,
          "scope": "offline_access profile roles phone email",
        };
        Map<String, String> headers = {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept-Language': locator<AppStateManager>().appLanguage,
        };

        debugPrint(
            'Logging in with sol:sms_code for $phoneAttempt, code: $cleanCode');
        var data = await _api.postRequest('/connect/token', body,
            headers: headers, apiPrefex: '');
        if (data is Map<String, dynamic> && data['access_token'] != null) {
          _authorizationModel = AuthorizationModel.fromJson(data);
          await saveAuthorizationData();
          _api.accessToken = _authorizationModel?.accessToken;
          await loadUserData(useLocalFallback: false);
          success = true;
          break;
        }
      } catch (err) {
        lastError = err;
        debugPrint('Token attempt failed for $phoneAttempt: $err');
      }
    }

    if (!success) {
      debugPrint(
          'Authentication failed for $cleanPhone with code $cleanCode: $lastError');
      throw Exception(
          'رمز التحقق غير صحيح أو انتهت صلاحيته. يرجى التأكد من الرمز والمحاولة مجدداً.');
    }

    // Ensure user model is ALWAYS populated and phone number is non-empty
    if (_user == null) {
      _user = UserModel(
        phoneNumber: cleanPhone,
        fullName: 'عميل جيتك',
        countryPhoneCode: '+963',
      );
    } else {
      if (_user!.phoneNumber == null || _user!.phoneNumber!.isEmpty) {
        _user!.phoneNumber = cleanPhone;
      }
    }
    await saveUserData(_user);
    notifyListeners();
  }

  Future<bool> renewToken([String? phone]) async {
    // Refresh tokens are the only safe way to renew without asking the user for
    // a new OTP. Never manufacture a session or request/exchange an OTP here.
    if (_authorizationModel?.refreshToken != null &&
        _authorizationModel!.refreshToken!.isNotEmpty) {
      try {
        Map<String, String> body = {
          "grant_type": "refresh_token",
          "refresh_token": _authorizationModel!.refreshToken!,
          'scope': 'offline_access profile roles phone email',
        };
        Map<String, String> headers = {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept-Language': locator<AppStateManager>().appLanguage,
        };

        var data = await _api.postRequest('/connect/token', body,
            headers: headers, apiPrefex: '');
        if (data is Map<String, dynamic> && data['access_token'] != null) {
          _authorizationModel = AuthorizationModel.fromJson(data);
          _api.accessToken = _authorizationModel?.accessToken;
          await saveAuthorizationData();
          debugPrint('Token successfully renewed via refresh_token!');
          return true;
        }
      } catch (refreshErr) {
        debugPrint('refresh_token failed: $refreshErr');
      }
    }

    return false;
  }

  Future<void> ensureValidAccessToken([String? phone]) async {
    final currentToken =
        _authorizationModel?.accessToken ?? _api.accessToken ?? '';
    final expString = _authorizationModel?.expiresIn;
    bool isExpired = false;
    if (expString != null) {
      final expDate = DateTime.tryParse(expString);
      if (expDate != null) {
        final diff = expDate.difference(DateTime.now());
        if (diff.isNegative || diff.inMinutes < 2) {
          isExpired = true;
        }
      }
    }
    final isInvalidToken = currentToken.isEmpty ||
        currentToken.startsWith('auth_jwt_token_') ||
        currentToken.startsWith('live_user_token_');

    final targetPhone = (phone != null && phone.trim().isNotEmpty)
        ? phone
        : (_user?.phoneNumber ?? '');

    if (isInvalidToken ||
        isExpired ||
        _api.accessToken == null ||
        _api.accessToken!.isEmpty) {
      debugPrint(
          'ensureValidAccessToken: token needs renewal (expired: $isExpired, invalid: $isInvalidToken, solTokenNull: ${_api.accessToken == null}). Target phone: $targetPhone');
      bool renewed = false;
      if (targetPhone.isNotEmpty) {
        renewed = await renewToken(targetPhone);
      }
      if (!renewed && isInvalidToken) {
        _authorizationModel = null;
        _api.accessToken = null;
      } else if (!isInvalidToken && currentToken.isNotEmpty) {
        _api.accessToken = currentToken;
      }
    } else {
      _api.accessToken = currentToken;
    }
  }

  Future<void> login(String email, String password) async {
    Map<String, String> body = {
      "grant_type": "password",
      "username": email,
      "password": password,
      "scope": "offline_access profile roles phone email",
    };
    Map<String, String> headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept-Language': locator<AppStateManager>().appLanguage,
    };

    debugPrint(headers.toString());
    var data = await _api.postRequest('/connect/token', body,
        headers: headers, apiPrefex: '');
    _authorizationModel = AuthorizationModel.fromJson(data);
    await saveAuthorizationData();
    _api.accessToken = _authorizationModel?.accessToken;
    await loadUserData(useLocalFallback: false);
  }

  Future loadUserData({bool useLocalFallback = true}) async {
    try {
      Map<String, dynamic> data =
          await _api.getRequest("/connect/userinfo", apiPrefex: '');
      data['phoneNumber'] = data['phone_number'];
      data['id'] = data['Id'];
      user = UserModel.fromMap(data);
    } catch (err) {
      debugPrint('loadUserData error: $err');
      if (useLocalFallback) {
        await _loadLocalUserData();
      } else {
        _user = null;
      }
    }
  }

  Future<void> getAuthorizationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_authorizationModel == null) {
        if (prefs.containsKey(authorizationKey)) {
          final rawAuth = prefs.getString(authorizationKey);
          if (rawAuth != null && rawAuth.isNotEmpty) {
            try {
              final authorizationData =
                  json.decode(rawAuth) as Map<String, dynamic>;
              final auth = AuthorizationModel.fromJson(authorizationData);
              if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
                if (auth.accessToken!.startsWith('auth_jwt_token_') ||
                    auth.accessToken!.startsWith('live_user_token_')) {
                  debugPrint(
                      'Purging obsolete mock token from storage: ${auth.accessToken}');
                  await prefs.remove(authorizationKey);
                } else {
                  _authorizationModel = auth;
                  _api.accessToken = _authorizationModel?.accessToken;
                }
              }
            } catch (parseErr) {
              debugPrint('Error parsing authorizationData: $parseErr');
              await prefs.remove(authorizationKey);
            }
          }
        }
      }

      // Only load local user profile if an active genuine access token is present
      if (isLogin()) {
        await _loadLocalUserData();
        _api.accessToken = _authorizationModel?.accessToken ?? _api.accessToken;
      }
    } catch (error) {
      debugPrint('getAuthorizationData error: $error');
    }
  }

  Future<void> saveAuthorizationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_authorizationModel != null) {
        await prefs.setString(
            authorizationKey, json.encode(_authorizationModel!.toJson()));
      }
    } catch (e) {
      debugPrint('saveAuthorizationData error: $e');
    }
  }

  static String normalizePhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (clean.startsWith('00')) {
      clean = '+${clean.substring(2)}';
    } else if (clean.startsWith('09') && clean.length == 10) {
      clean = '+963${clean.substring(1)}';
    } else if (clean.startsWith('0') && clean.length >= 9) {
      clean = '+963${clean.substring(1)}';
    } else if (clean.startsWith('9') && clean.length == 9) {
      clean = '+963$clean';
    } else if (clean.startsWith('963') && !clean.startsWith('+')) {
      clean = '+$clean';
    } else if (!clean.startsWith('+') && clean.isNotEmpty) {
      clean = '+$clean';
    }
    return clean;
  }

  Future<void> saveUserData([UserModel? userToSave]) async {
    final target = userToSave ?? _user;
    if (target == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = json.encode(target.toMap());
      await prefs.setString(kUserProfileKey, userJson);

      // Also persist to phone-indexed user directory with all format variations
      if (target.phoneNumber != null && target.phoneNumber!.isNotEmpty) {
        final rawDir = prefs.getString(kRegisteredUsersDirectoryKey);
        Map<String, dynamic> dir = {};
        if (rawDir != null && rawDir.isNotEmpty) {
          try {
            dir = json.decode(rawDir) as Map<String, dynamic>;
          } catch (_) {}
        }
        final targetMap = target.toMap();
        final raw = target.phoneNumber!;
        final norm = normalizePhone(raw);
        final local = (norm.startsWith('+963') && norm.length == 13)
            ? '0${norm.substring(4)}'
            : '';

        dir[raw] = targetMap;
        if (norm.isNotEmpty) dir[norm] = targetMap;
        if (local.isNotEmpty) dir[local] = targetMap;

        await prefs.setString(kRegisteredUsersDirectoryKey, json.encode(dir));
      }
    } catch (err) {
      debugPrint('saveUserData error: $err');
    }
  }

  Future<void> _loadLocalUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(kUserProfileKey)) {
        final raw = prefs.getString(kUserProfileKey);
        if (raw != null && raw.isNotEmpty) {
          final map = json.decode(raw) as Map<String, dynamic>;
          _user = UserModel.fromMap(map);
          notifyListeners();
        }
      }
    } catch (err) {
      debugPrint('_loadLocalUserData error: $err');
    }
  }

  Future<UserModel?> getSavedUserByPhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawDir = prefs.getString(kRegisteredUsersDirectoryKey);
      if (rawDir != null && rawDir.isNotEmpty) {
        final dir = json.decode(rawDir) as Map<String, dynamic>;
        final norm = normalizePhone(phone);
        final local = (norm.startsWith('+963') && norm.length == 13)
            ? '0${norm.substring(4)}'
            : '';

        if (dir.containsKey(phone)) {
          return UserModel.fromMap(dir[phone] as Map<String, dynamic>);
        } else if (norm.isNotEmpty && dir.containsKey(norm)) {
          return UserModel.fromMap(dir[norm] as Map<String, dynamic>);
        } else if (local.isNotEmpty && dir.containsKey(local)) {
          return UserModel.fromMap(dir[local] as Map<String, dynamic>);
        }
      }
    } catch (err) {
      debugPrint('getSavedUserByPhone error: $err');
    }
    return null;
  }

  bool _isCheckingToken = false;

  Future<void> checkAuthorizationToken() async {
    if (_isCheckingToken) return;
    _isCheckingToken = true;
    try {
      await getAuthorizationData();
      if (_authorizationModel != null &&
          _authorizationModel!.accessToken != null &&
          _authorizationModel!.accessToken!.isNotEmpty) {
        final token = _authorizationModel!.accessToken!;
        final expString = _authorizationModel!.expiresIn;
        bool isExpired = false;
        if (expString != null) {
          final expDate = DateTime.tryParse(expString);
          if (expDate != null) {
            final diff = expDate.difference(DateTime.now());
            if (diff.isNegative) {
              isExpired = true;
            }
          }
        }
        final isMockToken = token.startsWith('auth_jwt_token_') ||
            token.startsWith('live_user_token_');

        if (isExpired || isMockToken) {
          debugPrint(
              'checkAuthorizationToken: token expired or mock, renewing...');
          final targetPhone = _user?.phoneNumber ?? '';
          final renewed =
              targetPhone.isNotEmpty && await renewToken(targetPhone);
          if (!renewed && isMockToken) {
            await clearAuthTokensOnly();
          }
        } else {
          _api.accessToken = token;
        }
      }
    } catch (error) {
      debugPrint(
          'checkAuthorizationToken network error (preserving session): $error');
    } finally {
      _isCheckingToken = false;
    }
  }

  Future<void> clearAuthTokensOnly() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(authorizationKey)) {
      await prefs.remove(authorizationKey);
    }
    _authorizationModel = null;
    _api.accessToken = null;
    notifyListeners();
  }

  Future logOut() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(authorizationKey)) {
      await prefs.remove(authorizationKey);
    }
    if (prefs.containsKey(kUserProfileKey)) {
      await prefs.remove(kUserProfileKey);
    }
    locator<AppParametersProvider>().resetData();
    _user = null;
    _authorizationModel = null;
    _api.accessToken = null;
    notifyListeners();
  }
}

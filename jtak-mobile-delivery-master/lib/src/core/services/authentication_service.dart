import 'dart:async';
import 'dart:convert';

import 'package:app_jtak_delivery/src/core/controllers/app_parameters_provider.dart';
import 'package:app_jtak_delivery/src/core/models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants/shard_preference_kay.dart';
import '../../utils/providers/sol_api.dart';
import '../../utils/utilities/global_var.dart';
import '../controllers/app/base_provider.dart';
import '../models/authorization_model.dart';
import 'locator.dart';

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
    } catch (err) {
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    try {
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
    } catch (err) {
      rethrow;
    }
  }

  Future loadUserData() async {
    if (isLogin()) {
      var data = await _api.getRequest("/connect/userinfo", apiPrefex: '');
      user = data != null ? UserModel.fromMap(data) : null;
    }
  }

  Future<void> getAuthorizationData() async {
    try {
      if (_authorizationModel == null) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey(authorizationKey)) {
          final authorizationData = json.decode(prefs.getString(authorizationKey)!) as Map<String, dynamic>;
          _authorizationModel = AuthorizationModel.fromJson(authorizationData);
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
          //Request refresh_token response comes without refreshToken
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

  Future logOut() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(authorizationKey)) {
      prefs.remove(authorizationKey);
    }
    locator<AppParametersProvider>().resetData();
    _user = null;
    _authorizationModel = null;
    _api.accessToken = null;
    notifyListeners();
  }
}

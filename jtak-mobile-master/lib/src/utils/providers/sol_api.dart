import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/controllers/app/app_state_manager.dart';
import '../../core/services/locator.dart';
import '../../core/services/authentication_service.dart';
import 'custom_exception.dart';
import 'internet_provider.dart';
import 'sol_api_response.dart';

class SolApi {
  static const String baseURL = 'https://api.jtak.app';
  static const String imagePreviewUrl = '$baseURL/api/v1/services/previewimage/';
  static const String downloadUrl = '$baseURL/api/v1/services/Download/';
  static const String apiVersionPrefex = '/api/v1';
  static const String apiModelPrefex = '/Customer';
  static const String apiPrefex = apiVersionPrefex + apiModelPrefex;
  static const String shareProductUrl = "$baseURL/product/";

  late InternetProvider internetProvider;

  String? accessToken;
  final String contentType;
  final String acceptLanguage;

  late Map<String, String> apiHeaders;

  SolApi({this.accessToken, this.contentType = 'application/json', this.acceptLanguage = '*'}) {
    internetProvider = InternetProvider();
  }

  Map<String, String> getHeaders({String? contentType, bool includeAuth = true}) {
    apiHeaders = {};
    apiHeaders['Content-Type'] = contentType ?? this.contentType;
    if (locator.isRegistered<AppStateManager>()) {
      try {
        apiHeaders['Accept-Language'] = locator<AppStateManager>().appLanguage;
      } catch (_) {}
    }
    if (includeAuth) {
      String? token = accessToken;
      if (token == null || token.isEmpty) {
        if (locator.isRegistered<AuthenticationService>()) {
          try {
            token = locator<AuthenticationService>().getAccessToken;
          } catch (_) {}
        }
      }
      if (token != null &&
          token.isNotEmpty &&
          !token.startsWith('auth_jwt_token_') &&
          !token.startsWith('live_user_token_')) {
        apiHeaders['authorization'] = 'Bearer $token';
      }
    }

    return apiHeaders;
  }

  bool _isAuthEndpoint(String subUrl) {
    return subUrl == '/connect/token' ||
        subUrl.contains('/RegisterOrSignInByPhoneNumber') ||
        subUrl.contains('/VerifyPhoneNumber');
  }

  Future<dynamic> getRequest(String subUrl, {Map<String, String>? headers, String? apiPrefex}) async {
    final bool isAuth = _isAuthEndpoint(subUrl);
    if (!isAuth && locator.isRegistered<AuthenticationService>()) {
      await locator<AuthenticationService>().checkAuthorizationToken();
    }
    String url = getFullUrl(subUrl, prefex: apiPrefex);
    try {
      final httpResponse = await internetProvider.getRequest(url, headers: headers ?? getHeaders(includeAuth: !isAuth));
      return _responseHandel(httpResponse, url: url);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> postRequest(String subUrl, dynamic body, {Map<String, String>? headers, String? apiPrefex}) async {
    final bool isAuth = _isAuthEndpoint(subUrl);
    if (!isAuth && locator.isRegistered<AuthenticationService>()) {
      await locator<AuthenticationService>().checkAuthorizationToken();
    }
    String url = getFullUrl(subUrl, prefex: apiPrefex);
    try {
      Map<String, String>? header = headers ?? getHeaders(includeAuth: !isAuth);
      Object newBody = _parseBody(body, header);

      final httpResponse = await internetProvider.postRequest(url, newBody, headers: header);
      return _responseHandel(httpResponse, url: url);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> putRequest(String subUrl, dynamic body, {Map<String, String>? headers, String? apiPrefex}) async {
    final bool isAuth = _isAuthEndpoint(subUrl);
    if (!isAuth && locator.isRegistered<AuthenticationService>()) {
      await locator<AuthenticationService>().checkAuthorizationToken();
    }
    String url = getFullUrl(subUrl, prefex: apiPrefex);
    try {
      Map<String, String> header = headers ?? getHeaders(includeAuth: !isAuth);
      Object newBody = _parseBody(body, header);

      final httpResponse = await internetProvider.putRequest(url, newBody, headers: header);
      return _responseHandel(httpResponse, url: url);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> deleteRequest(String subUrl, {Map<String, String>? headers, String? apiPrefex}) async {
    String url = getFullUrl(subUrl, prefex: apiPrefex);
    try {
      Map<String, String> header = headers ?? getHeaders();
      final httpResponse = await internetProvider.deleteRequest(url, headers: header);
      return _responseHandel(httpResponse, url: url);
    } catch (err) {
      rethrow;
    }
  }

  dynamic _parseBody(dynamic body, Map<String, String> header) {
    Object newBody;
    if (header['Content-Type'] == 'application/json') {
      newBody = jsonEncode(body);
    } else {
      newBody = body;
    }

    return newBody;
  }

  String getFullUrl(String subUrl, {String? prefex}) {
    String url = baseURL + (prefex ?? SolApi.apiPrefex) + subUrl;
    if (kIsWeb && kDebugMode) {
      return 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
    }
    return url;
  }

  dynamic _responseHandel(http.Response response, {String url = ''}) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return <String, dynamic>{};
        return json.decode(response.body);
      }

      debugPrint('$url status code ${response.statusCode}: ${response.body}');

      // Attempt to parse structured error response from server
      if (response.body.isNotEmpty) {
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            SolApiErrorResponse apiResponse = SolApiErrorResponse();
            apiResponse.fromJson(decoded);
            final errStr = apiResponse.getErrorsString();
            if (errStr.trim().isNotEmpty) {
              throw FetchDataException(errStr.trim(), response.statusCode, decoded);
            }
          } else if (decoded is String && decoded.trim().isNotEmpty) {
            final localized = SolApiErrorResponse.localizeMessage(decoded.trim());
            throw FetchDataException(localized, response.statusCode, decoded);
          }
        } catch (e) {
          if (e is FetchDataException) rethrow;
          debugPrint('SolApi error response parse: $e');
        }
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw UnauthorisedException('انتهت صلاحية الجلسة، يرجى إعادة تسجيل الدخول.');
      }

      if (response.statusCode == 404) {
        throw NotFoundException('المورد المطلوب غير موجود');
      }

      // If server returned plain text error message (non-HTML)
      if (response.body.isNotEmpty && !response.body.trim().startsWith('<') && response.body.length < 300) {
        final localized = SolApiErrorResponse.localizeMessage(response.body.trim());
        throw FetchDataException(localized, response.statusCode);
      }

      throw FetchDataException('تعذر إتمام العملية من الخادم، يرجى المحاولة لاحقاً.', response.statusCode);
    } on FormatException catch (e) {
      debugPrint('SolApi format exception: $e');
      throw FetchDataException('تعذر معالجة استجابة الخادم، يرجى المحاولة مرة أخرى.');
    } catch (err) {
      debugPrint(err.toString());
      rethrow;
    }
  }
}

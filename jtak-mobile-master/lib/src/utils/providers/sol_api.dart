import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utilities/global_var.dart';

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
    getHeaders();
  }

  Map<String, String> getHeaders({String? contentType}) {
    apiHeaders = {};
    apiHeaders['Content-Type'] = contentType ?? this.contentType;
    apiHeaders['Accept-Language'] = locator<AppStateManager>().appLanguage;
    if (accessToken != null) apiHeaders['authorization'] = 'Bearer $accessToken';

    return apiHeaders;
  }

  Future<dynamic> getRequest(String subUrl, {Map<String, String>? headers, String? apiPrefex}) async {
    if (subUrl != '/connect/token') await locator<AuthenticationService>().checkAuthorizationToken();
    String url = getFullUrl(subUrl, prefex: apiPrefex);
    try {
      final httpResponse = await internetProvider.getRequest(url, headers: headers ?? getHeaders());
      return _responseHandel(httpResponse, url: url);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> postRequest(String subUrl, dynamic body, {Map<String, String>? headers, String? apiPrefex}) async {
    if (subUrl != '/connect/token') await locator<AuthenticationService>().checkAuthorizationToken();
    String url = getFullUrl(subUrl, prefex: apiPrefex);
    try {
      Map<String, String>? header = headers ?? getHeaders();
      Object newBody = _parseBody(body, header);

      final httpResponse = await internetProvider.postRequest(url, newBody, headers: header);
      return _responseHandel(httpResponse, url: url);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> putRequest(String subUrl, dynamic body, {Map<String, String>? headers, String? apiPrefex}) async {
    if (subUrl != '/connect/token') await locator<AuthenticationService>().checkAuthorizationToken();
    String url = getFullUrl(subUrl, prefex: apiPrefex);
    try {
      Map<String, String> header = headers ?? getHeaders();
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

  _parseBody(dynamic body, Map<String, String> header) {
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
      return 'https://corsproxy.io/?' + Uri.encodeComponent(url);
    }
    return url;
  }

  dynamic _responseHandel(http.Response response, {String url = ''}) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      }

      if (kDebugMode) {
        debugPrint('$url status code ${response.statusCode}');
      }

      if (response.statusCode == 404) {
        throw NotFoundException(str.msg.errConnectionServer);
      }

      if (response.statusCode >= 500) {
        throw FetchDataException(str.msg.errConnectionServer);
      }

      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          SolApiErrorResponse apiResponse = SolApiErrorResponse();
          apiResponse.fromJson(decoded);
          final errStr = apiResponse.getErrorsString();
          if (errStr.isNotEmpty) {
            throw FetchDataException(errStr);
          }
        }
      } catch (e) {
        if (e is FetchDataException) rethrow;
      }

      throw FetchDataException(str.msg.errConnectionServer);
    } on FormatException catch (e) {
      debugPrint('SolApi format exception: $e');
      throw FetchDataException(str.msg.errConnectionServer);
    } catch (err) {
      debugPrint(err.toString());
      rethrow;
    }
  }
}

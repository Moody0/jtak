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
  static const String imagePreviewUrl = baseURL + '/api/v1/services/previewimage/';
  static const String downloadUrl = baseURL + '/api/services/Download/';
  static const String apiVersionPrefex = '/api/v1';
  static const String apiModelPrefex = '/delivery';
  static const String apiPrefex = apiVersionPrefex + apiModelPrefex;

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
      final httpResponse = await internetProvider.getRequest(Uri.parse(url), headers: headers ?? getHeaders());
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

      final httpResponse = await internetProvider.postRequest(Uri.parse(url), newBody, headers: header);
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

      final httpResponse = await internetProvider.putRequest(Uri.parse(url), newBody, headers: header);
      return _responseHandel(httpResponse, url: url);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> deleteRequest(String subUrl, {Map<String, String>? headers, String? apiPrefex}) async {
    String url = getFullUrl(subUrl, prefex: apiPrefex);
    try {
      Map<String, String> header = headers ?? getHeaders();
      final httpResponse = await internetProvider.deleteRequest(Uri.parse(url), headers: header);
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

  String getFullUrl(String subUrl, {String? prefex}) => baseURL + (prefex ?? SolApi.apiPrefex) + subUrl;

  dynamic _responseHandel(http.Response response, {String url = ''}) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) return json.decode(response.body);

      SolApiErrorResponse apiResponse = SolApiErrorResponse();
      GlobalVar.log('$url status code ${response.statusCode} : ${json.decode(response.body)}');

      if (response.statusCode == 404) throw NotFoundException('${str.msg.errConnectionServer} \n ${apiResponse.getErrorsString()}');

      if (response.statusCode == 500) throw FetchDataException('${str.msg.errConnectionServer} \n ${apiResponse.getErrorsString()}');

      apiResponse.fromJson(json.decode(response.body) as Map<String, dynamic>);
      if (kDebugMode) debugPrint('///////////////// apiResponse.getErrorsString :' + apiResponse.getErrorsString());
      throw FetchDataException(apiResponse.getErrorsString());
    } on FormatException catch (e) {
      // if faild to parse error json object
      debugPrint(e.toString());
      throw FetchDataException(response.body);
    } catch (err) {
      debugPrint(err.toString());
      rethrow;
    }
  }
}

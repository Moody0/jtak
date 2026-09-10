import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utilities/global_var.dart';
import 'custom_exception.dart';

class InternetProvider {
  static const Duration _defaultTimeout = Duration(seconds: 8);

  Future<dynamic> postRequest(String url, dynamic body, {Map<String, String>? headers}) async {
    try {
      printRequestInfo('POST', url, headers, body: body);
      checkNetConnection();
      final httpResponse = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(_defaultTimeout);
      return _responseHandel(httpResponse, url: url);
    } on SocketException {
      throw InternetException(str.msg.noInternet);
    } on TimeoutException {
      throw InternetException(str.msg.noInternet);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> putRequest(String url, dynamic body, {Map<String, String>? headers}) async {
    try {
      printRequestInfo('POST', url, headers, body: body);
      checkNetConnection();
      final httpResponse = await http
          .put(Uri.parse(url), headers: headers, body: body)
          .timeout(_defaultTimeout);
      return _responseHandel(httpResponse, url: url);
    } on SocketException {
      throw InternetException(str.msg.noInternet);
    } on TimeoutException {
      throw InternetException(str.msg.noInternet);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> getRequest(String url, {Map<String, String>? headers}) async {
    try {
      printRequestInfo('GET', url, headers);
      checkNetConnection();
      final httpResponse = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(_defaultTimeout);
      return _responseHandel(httpResponse, url: url);
    } on SocketException {
      throw InternetException(str.msg.noInternet);
    } on TimeoutException {
      throw InternetException(str.msg.noInternet);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> deleteRequest(String url, {Map<String, String>? headers}) async {
    try {
      printRequestInfo('DELETE', url, headers);
      checkNetConnection();
      final httpResponse = await http
          .delete(Uri.parse(url), headers: headers)
          .timeout(_defaultTimeout);
      return _responseHandel(httpResponse, url: url);
    } on SocketException {
      throw InternetException(str.msg.noInternet);
    } on TimeoutException {
      throw InternetException(str.msg.noInternet);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> uploadFiles(String url, File imageFile, {Map<String, String>? headers}) async {
    var uri = Uri.parse(url);

    try {
      printRequestInfo('UploadFiles', uri.toString(), headers);
      checkNetConnection();
      var request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers!)
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      var response = await request.send();

      if (response.statusCode == 200) log('UploadFiles success!');
      final body = await response.stream.bytesToString();
      var httpResponse = http.Response(body, response.statusCode);
      return _responseHandel(httpResponse, url: uri.toString());
    } on SocketException {
      throw InternetException(str.msg.noInternet);
    } catch (err) {
      rethrow;
    }
  }

  dynamic _responseHandel(http.Response httpResponse, {String url = ''}) {
    if (kDebugMode) {
      log(''' @@@@@@@@@@@@@@@@@@@@@@@@@@ response from $url | statusCode:${httpResponse.statusCode} .''');
      log('response body:${httpResponse.body}  ');
    }
    return httpResponse;
    // try {
    //   if (httpResponse.statusCode.toString().startsWith('2')) return httpResponse.body;
    // } catch (err) {
    //   print(err.toString());
    //   rethrow;
    // }
  }

  void printRequestInfo(String requestType, String url, Map? headers, {dynamic body = ""}) {
    if (kDebugMode) {
      log(''' @@@@@@@@@@@@@@@@@@@@@@@@@@ requestType $requestType  $url \n body: $body \n ''');
      // log(' headers: $headers  ');
    }
  }

  Future<bool> checkNetConnection() async {
    return true;
    // try {
    //   final result = await InternetAddress.lookup('google.com');
    //   if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
    //     return true;
    //   } else
    //     throw InternetException(str.msg.noInternet);
    // } on SocketException catch (_) {
    //   throw InternetException(str.msg.noInternet);
    // }
  }
}

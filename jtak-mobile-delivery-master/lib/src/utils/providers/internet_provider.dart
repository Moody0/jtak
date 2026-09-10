import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utilities/global_var.dart';
import 'custom_exception.dart';

class InternetProvider {
  Future<dynamic> getRequest(Uri uri, {Map<String, String>? headers}) async {
    try {
      printRequestInfo('GET', uri.toString(), headers);
      checkNetConnection();
      final httpResponse = await http.get(uri, headers: headers);
      return _responseHandel(httpResponse, url: uri.toString());
    } on SocketException {
      throw InternetException(str.msg.noInternet);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> postRequest(Uri uri, dynamic body, {Map<String, String>? headers}) async {
    try {
      printRequestInfo('POST', uri.toString(), headers, body: body);
      checkNetConnection();
      final httpResponse = await http.post(uri, headers: headers, body: body);
      return _responseHandel(httpResponse, url: uri.toString());
    } on SocketException {
      throw InternetException(str.msg.noInternet);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> putRequest(Uri uri, dynamic body, {Map<String, String>? headers}) async {
    try {
      printRequestInfo('POST', uri.toString(), headers, body: body);
      checkNetConnection();
      final httpResponse = await http.put(uri, headers: headers, body: body);
      return _responseHandel(httpResponse, url: uri.toString());
    } on SocketException {
      throw InternetException(str.msg.noInternet);
    } catch (err) {
      rethrow;
    }
  }

  Future<dynamic> deleteRequest(Uri uri, {Map<String, String>? headers}) async {
    try {
      printRequestInfo('DELETE', uri.toString(), headers);
      checkNetConnection();
      final httpResponse = await http.delete(uri, headers: headers);
      return _responseHandel(httpResponse, url: uri.toString());
    } on SocketException {
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
    GlobalVar.log(''' @@@@@@@@@@@@@@@@@@@@@@@@@@ response | $url | statusCode:${httpResponse.statusCode}
    body:${httpResponse.body}''');
    return httpResponse;
  }

  void printRequestInfo(String requestType, String url, Map? headers, {dynamic body = ""}) {
    if (kDebugMode) {
      debugPrint(''' @@@@@@@@@@@@@@@@@@@@@@@@@@ | $requestType | $url \n  headers: $headers \n body: $body \n  .''');
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

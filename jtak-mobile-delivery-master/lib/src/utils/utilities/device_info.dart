import 'dart:io';

import 'package:flutter/material.dart';

// import 'package:get_version/get_version.dart';

enum DeviceType { android, ios }

class DeviceInfo {
  late DeviceType deviceType;
  late DeviceType osType;
  String? osVersion;
  String? appVersion;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['DeviceType'] = deviceType.index + 1;
    data['OsType'] = osType.index + 1;
    data['OsVersion'] = osVersion;
    data['AppVersion'] = appVersion;
    return data;
  }

  Future<Map<String, dynamic>> loadDeviceInfo() async {
    deviceType = DeviceType.android;
    osType = DeviceType.android;
    if (Platform.isIOS) {
      deviceType = DeviceType.ios;
      osType = DeviceType.ios;
    }
    osVersion = Platform.version;
    try {
      // osVersion = await GetVersion.platformVersion;
      // appVersion = await GetVersion.projectCode;
    } catch (err) {
      debugPrint(err.toString());
    }
    return toJson();
  }
}

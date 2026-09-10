import 'dart:io';

import 'package:app_jtak_delivery/src/core/models/lat_lng_model.dart';
import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final bool isMandatory;

  LocationService({this.isMandatory = false});

  /// Determine the current position of the device.
  ///
  /// When the location services are not enabled or permissions
  /// are denied the `Future` will return an error.
  Future<LatLng?> getCurrentLocation() async {
    ////////////////{ check Permission } ////////////////
    await checkPermission();

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      Position currentPosition = await Geolocator.getCurrentPosition();
      return LatLng(currentPosition.latitude, currentPosition.longitude);
    } catch (e) {
      if (isMandatory) {
        if (e is LocationServiceDisabledException && isMandatory) {
          throw str.msg.locationServiceDisabled;
        }
        rethrow;
      }
    }
    return null;
  }

  Future<bool> checkLocationService() async {
    bool serviceEnabled;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }
    return serviceEnabled;
  }

  Future<bool> checkPermission() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error(str.msg.locationPermissionsDenied);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.

      if (Platform.isIOS) {
        return Future.error(str.msg.pleaseEnableLocationService);
      } else {
        await Geolocator.openLocationSettings();
        return Future.error(str.msg.locationPermissionsDenied);
      }
    }

    return true;
  }

  Future<LocationPermission> requireAlwaysPermission() async {
    await checkLocationService();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(str.msg.locationPermissionsDenied);
    }

    if (permission == LocationPermission.denied) {
      throw Exception(str.msg.locationPermissionsDenied);
    }

    // If granted only while in use, request again to upgrade to 'always' (Allow all the time)
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    // Enforce LocationPermission.always strictly for continuous background tracking
    if (permission != LocationPermission.always) {
      throw Exception(
        'يتطلب تطبيق التوصيل صلاحية الموقع "دائماً" (Allow all the time) لضمان استمرار تتبع الطلبات في الخلفية وعند قفل الشاشة.',
      );
    }

    return permission;
  }

  Future<void> openRequiredSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }
    await Geolocator.openAppSettings();
  }
}

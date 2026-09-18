import 'dart:io';

import 'package:app_jtak_delivery/src/core/models/lat_lng_model.dart';
import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';
import 'package:geolocator/geolocator.dart';

/// The specific reason live location access isn't available yet. The UI
/// uses this to show a precise explanation and the one action that will
/// actually move the user forward, instead of a generic error with a
/// "try again" button that silently does nothing (which is what a second
/// [Geolocator.requestPermission] call does once permission is already at
/// [LocationPermission.whileInUse] on Android 11+).
enum LocationAccessIssue {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  needsAlwaysUpgrade,
}

class LocationAccessException implements Exception {
  final LocationAccessIssue issue;
  final String message;
  LocationAccessException(this.issue, this.message);
  @override
  String toString() => message;
}

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
      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        currentPosition = await Geolocator.getLastKnownPosition();
      }
      if (currentPosition != null) {
        return LatLng(currentPosition.latitude, currentPosition.longitude);
      }
    } catch (e) {
      if (isMandatory) {
        if (e is LocationServiceDisabledException && isMandatory) {
          throw LocationAccessException(
            LocationAccessIssue.serviceDisabled,
            str.msg.locationServiceDisabled,
          );
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
      throw LocationAccessException(
        LocationAccessIssue.serviceDisabled,
        str.msg.locationServiceDisabled,
      );
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
        throw LocationAccessException(
          LocationAccessIssue.permissionDenied,
          str.msg.locationPermissionsDenied,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever: the OS will not show the system
      // prompt again, so the only way forward is the app's own settings.
      if (Platform.isIOS) {
        throw LocationAccessException(
          LocationAccessIssue.permissionDeniedForever,
          str.msg.pleaseEnableLocationService,
        );
      } else {
        throw LocationAccessException(
          LocationAccessIssue.permissionDeniedForever,
          str.msg.locationPermissionsDenied,
        );
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
      throw LocationAccessException(
        LocationAccessIssue.permissionDeniedForever,
        str.msg.locationPermissionsDenied,
      );
    }

    if (permission == LocationPermission.denied) {
      throw LocationAccessException(
        LocationAccessIssue.permissionDenied,
        str.msg.locationPermissionsDenied,
      );
    }

    // Both 'always' and 'whileInUse' (foreground service) permit active dispatch and tracking
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      return permission;
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

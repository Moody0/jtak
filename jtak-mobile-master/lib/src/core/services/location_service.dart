import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:jtek_app/src/utils/utilities/global_var.dart';

class LocationService {
  final bool isMandatory;

  LocationService({this.isMandatory = false});

  /// Determine the current position of the device.
  ///
  /// Fast path checks last known cached position (<50ms).
  /// Falls back to fresh GPS fix with reasonable timeout.
  Future<LatLng?> getCurrentLocation() async {
    if (kIsWeb) {
      return const LatLng(33.5138, 36.2765);
    }

    ////////////////{ check Permission } ////////////////
    bool hasPermission = false;
    try {
      hasPermission = await checkPermission();
    } catch (e) {
      if (isMandatory) rethrow;
      return null;
    }

    if (!hasPermission) {
      return null;
    }

    // 1. FAST PATH (<50ms): Last known location cached by Google Play Services / OS
    try {
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      }
    } catch (e) {
      debugPrint('LocationService: getLastKnownPosition error: $e');
    }

    // 2. FRESH GPS FIX: Medium accuracy resolves within 1-2s
    try {
      Position currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(currentPosition.latitude, currentPosition.longitude);
    } catch (e) {
      debugPrint('LocationService: getCurrentPosition error: $e');
      if (isMandatory) {
        if (e is LocationServiceDisabledException) {
          throw str.msg.locationServiceDisabled;
        }
        rethrow;
      }
    }
    return null;
  }

  /// Reverse geocode coordinates to the real human-readable address on the map in Arabic
  static Future<String> reverseGeocodeCoordinates(double lat, double lng) async {
    // 1. First attempt: Fast Open Reverse Geocoding via BigDataCloud (instant ~150ms, zero rate limits)
    try {
      final url = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=ar',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null) {
          List<String> parts = [];
          String? locality = data['locality'];
          String? city = data['city'];
          String? principalSubdivision = data['principalSubdivision'];

          if (locality != null && locality.toString().isNotEmpty) parts.add(locality.toString());
          if (city != null && city.toString().isNotEmpty && city != locality) parts.add(city.toString());
          if (principalSubdivision != null && principalSubdivision.toString().isNotEmpty && principalSubdivision != city && principalSubdivision != locality) {
            parts.add(principalSubdivision.toString());
          }

          if (parts.isNotEmpty) {
            return parts.join('، ');
          }
        }
      }
    } catch (e) {
      debugPrint('LocationService: BigDataCloud geocoding failed: $e');
    }

    // 2. Second attempt: OpenStreetMap Nominatim
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ar,en&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'JtakCustomerApp/1.0.0 (contact@jtak.app)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['address'] != null) {
          final addr = data['address'];
          List<String> parts = [];
          String? road = addr['road'] ?? addr['pedestrian'] ?? addr['street'] ?? addr['building'];
          String? district = addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? addr['district'] ?? addr['city_district'];
          String? city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state'] ?? addr['county'];

          if (road != null && road.toString().isNotEmpty) parts.add(road.toString());
          if (district != null && district.toString().isNotEmpty && district != road) parts.add(district.toString());
          if (city != null && city.toString().isNotEmpty && city != district && city != road) parts.add(city.toString());

          if (parts.isNotEmpty) {
            return parts.join('، ');
          }
          if (data['display_name'] != null) {
            final split = data['display_name'].toString().split(',');
            return split.take(3).map((s) => s.trim()).join('، ');
          }
        }
      }
    } catch (e) {
      debugPrint('LocationService: Nominatim geocoding failed: $e');
    }

    // 3. Third attempt: Native device OS geocoding with strict 1.5s timeout
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng).timeout(const Duration(milliseconds: 1500));
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        List<String> parts = [];
        String? street = place.thoroughfare?.isNotEmpty == true ? place.thoroughfare : place.street;
        String? district = place.subLocality?.isNotEmpty == true ? place.subLocality : place.subAdministrativeArea;
        String? city = place.locality?.isNotEmpty == true ? place.locality : place.administrativeArea;

        if (street != null && street.isNotEmpty) parts.add(street);
        if (district != null && district.isNotEmpty && district != street) parts.add(district);
        if (city != null && city.isNotEmpty && city != district && city != street) parts.add(city);

        if (parts.isNotEmpty) return parts.join('، ');
        if (place.name?.isNotEmpty == true) return place.name!;
      }
    } catch (e) {
      debugPrint('LocationService: Native geocoding failed: $e');
    }

    return 'الموقع المحدد (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  static const String _googleApiKey = 'AIzaSyAp9HzSnfyp3c1mSKtOGANwhmFSGa3Rm20';

  /// Search places using Google Places Autocomplete API with OpenStreetMap fallback
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().length < 2) return [];

    // 1. Primary: Google Places Autocomplete API
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&language=ar&key=$_googleApiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['status'] == 'OK' && data['predictions'] != null) {
          final List predictions = data['predictions'];
          List<Map<String, dynamic>> results = [];
          for (var p in predictions.take(6)) {
            final String placeId = p['place_id'] ?? '';
            final String mainText = p['structured_formatting']?['main_text'] ?? p['description'] ?? '';
            final String secondaryText = p['structured_formatting']?['secondary_text'] ?? '';
            final String fullDescription = secondaryText.isNotEmpty ? '$mainText، $secondaryText' : mainText;

            results.add({
              'display_name': fullDescription,
              'main_text': mainText,
              'secondary_text': secondaryText,
              'place_id': placeId,
            });
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (e) {
      debugPrint('LocationService: Google Places search failed ($e), trying fallback...');
    }

    // 2. Fallback: OpenStreetMap Nominatim
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&accept-language=ar,en&limit=5',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'JtakCustomerApp/1.0.0 (contact@jtak.app)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          final String rawName = item['display_name'] ?? '';
          final parts = rawName.split(',');
          final shortName = parts.take(3).map((s) => s.trim()).join('، ');

          return {
            'display_name': shortName.isNotEmpty ? shortName : rawName,
            'lat': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
            'lon': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('LocationService: searchPlaces fallback failed: $e');
    }

    return [];
  }

  /// Get place coordinates by Google place_id
  static Future<LatLng?> getPlaceCoordinates(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$_googleApiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['status'] == 'OK' && data['result']?['geometry']?['location'] != null) {
          final loc = data['result']['geometry']['location'];
          final double lat = double.tryParse(loc['lat']?.toString() ?? '') ?? 0.0;
          final double lng = double.tryParse(loc['lng']?.toString() ?? '') ?? 0.0;
          if (lat != 0.0 && lng != 0.0) {
            return LatLng(lat, lng);
          }
        }
      }
    } catch (e) {
      debugPrint('LocationService: getPlaceCoordinates failed: $e');
    }
    return null;
  }

  Future<bool> checkLocationService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (isMandatory) {
        return Future.error(str.msg.locationServiceDisabled);
      }
      return false;
    }
    return true;
  }

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (isMandatory) {
        return Future.error(str.msg.locationServiceDisabled);
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (isMandatory) {
          return Future.error(str.msg.locationPermissionsDenied);
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (isMandatory) {
        if (!kIsWeb && Platform.isIOS) {
          return Future.error(str.msg.pleaseEnableLocationService);
        } else {
          await Geolocator.openLocationSettings();
          return Future.error(str.msg.locationPermissionsDenied);
        }
      }
      return false;
    }

    return true;
  }
}

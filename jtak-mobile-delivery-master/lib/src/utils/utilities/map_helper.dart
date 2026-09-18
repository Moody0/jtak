import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/merchant_order_details.dart';
import '../../core/models/order_model.dart';

/// Test launcher signature for unit testing map url launches.
typedef UrlLauncherFn = Future<bool> Function(Uri uri, LaunchMode mode);

class MapHelper {
  static DateTime? _lastLaunchTime;
  static int debounceDurationMs = 1000;

  /// Optional injected launcher function for unit tests.
  @visibleForTesting
  static UrlLauncherFn? testLauncher;

  /// Resets test overrides and debouncer state.
  static void resetForTesting() {
    _lastLaunchTime = null;
    testLauncher = null;
    debounceDurationMs = 1000;
  }

  /// Validates whether a latitude/longitude pair represents a real, non-zero geographic point.
  /// Rejects null, NaN, Infinite, out-of-range (-90..90, -180..180), and (0,0) Null Island.
  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN || lat.isInfinite || lng.isInfinite) return false;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lng < -180.0 || lng > 180.0) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return true;
  }

  /// Validates whether an address string is usable for geocoding / fallback search.
  static bool isValidAddress(String? address) {
    if (address == null) return false;
    final trimmed = address.trim();
    return trimmed.isNotEmpty && trimmed != 'null' && trimmed != 'العنوان غير محدد';
  }

  /// Builds a Google Maps navigation/directions URL.
  /// If coordinates are valid, uses GPS lat/lng destination.
  /// Else if address is valid, uses address string as destination query.
  /// Returns null if neither is available.
  static String? buildDirectionsUrl({
    double? lat,
    double? lng,
    String? address,
  }) {
    if (isValidCoordinate(lat, lng)) {
      return 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    }
    if (isValidAddress(address)) {
      return 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address!.trim())}';
    }
    return null;
  }

  /// Builds a geo: intent URI for native map handlers.
  static String? buildGeoUri({
    required double lat,
    required double lng,
    String? label,
  }) {
    if (!isValidCoordinate(lat, lng)) return null;
    if (label != null && label.trim().isNotEmpty && label.trim() != 'null') {
      return 'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(label.trim())})';
    }
    return 'geo:$lat,$lng?q=$lat,$lng';
  }

  /// Checks whether a tap action should be ignored due to rapid double tapping.
  static bool isDebounced() {
    final now = DateTime.now();
    if (_lastLaunchTime != null &&
        now.difference(_lastLaunchTime!).inMilliseconds < debounceDurationMs) {
      return true;
    }
    _lastLaunchTime = now;
    return false;
  }

  /// Launches navigation to the store/merchant location for a specific order detail.
  static Future<bool> launchStoreMap({
    required BuildContext context,
    required MerchentOrderDetailsModel item,
  }) async {
    return launchMapDirections(
      context: context,
      lat: item.lat,
      lng: item.lng,
      address: item.merchantAddress,
      label: item.merchantTitle,
      isMerchant: true,
    );
  }

  /// Launches navigation to the customer delivery destination for a specific order.
  static Future<bool> launchCustomerMap({
    required BuildContext context,
    required OrderModel order,
  }) async {
    return launchMapDirections(
      context: context,
      lat: order.lat,
      lng: order.lng,
      address: order.address,
      label: order.user,
      isMerchant: false,
    );
  }

  /// Core resilient navigation launcher.
  /// Validates coordinates, debounces rapid taps, attempts multi-tier intent/URL launches,
  /// and displays descriptive localized feedback on failures or missing coordinates.
  static Future<bool> launchMapDirections({
    BuildContext? context,
    double? lat,
    double? lng,
    String? address,
    String? label,
    required bool isMerchant,
  }) async {
    // 1. Debounce rapid double taps
    if (isDebounced()) {
      return false;
    }

    final isArabic = context == null ||
        (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';

    // 2. Validate coordinates or fallback address
    final hasValidCoords = isValidCoordinate(lat, lng);
    final hasValidAddress = isValidAddress(address);

    if (!hasValidCoords && !hasValidAddress) {
      if (context != null && context.mounted) {
        final errorMsg = isMerchant
            ? (isArabic ? 'موقع المتجر غير متوفر حالياً' : 'Store location is currently unavailable')
            : (isArabic ? 'موقع العميل غير متوفر حالياً' : 'Customer location is currently unavailable');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    // 3. Prepare target URLs
    final directionsUrl = buildDirectionsUrl(lat: lat, lng: lng, address: address);
    if (directionsUrl == null) {
      return false;
    }

    // 4. Multi-tier launch execution
    bool launched = false;

    // Tier A: Try standard Google Maps navigation URL with external application
    try {
      final uri = Uri.parse(directionsUrl);
      if (testLauncher != null) {
        launched = await testLauncher!(uri, LaunchMode.externalApplication);
      } else {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      launched = false;
    }

    // Tier B: If not launched and coordinates are valid, try geo: URI (Android native intent)
    if (!launched && hasValidCoords) {
      try {
        final geoUriString = buildGeoUri(lat: lat!, lng: lng!, label: label);
        if (geoUriString != null) {
          final geoUri = Uri.parse(geoUriString);
          if (testLauncher != null) {
            launched = await testLauncher!(geoUri, LaunchMode.externalApplication);
          } else {
            if (await canLaunchUrl(geoUri)) {
              launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
            }
          }
        }
      } catch (_) {
        launched = false;
      }
    }

    // Tier C: Fallback to platform default / browser
    if (!launched) {
      try {
        final uri = Uri.parse(directionsUrl);
        if (testLauncher != null) {
          launched = await testLauncher!(uri, LaunchMode.platformDefault);
        } else {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } catch (_) {
        launched = false;
      }
    }

    // 5. If all launch tiers failed, notify user
    if (!launched && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'تعذر فتح تطبيق الخرائط على الجهاز' : 'Could not open maps application',
            style: GoogleFonts.ibmPlexSansArabic(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return launched;
  }
}

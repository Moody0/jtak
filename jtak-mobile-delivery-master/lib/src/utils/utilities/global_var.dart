import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import '../../../generated/locale_base.dart';
import '../providers/sol_api.dart';

late LocaleBase str;

class GlobalVar {
  ////////////{ Methods}

  static String getAssetsImage(String imageName) => "assets/images/$imageName";

  static String getImageUrl(String imageName, {int width = 300, int height = 200, bool crop = true}) {
    final raw = getString(imageName).trim();
    if (raw.isEmpty || raw == 'null') return '';
    final clean = raw.split(',').first.trim();
    if (clean.isEmpty || clean == 'null') return '';
    if (clean.startsWith('http://') || clean.startsWith('https://') || clean.startsWith('assets/') || clean.startsWith('./assets/')) {
      return clean;
    }
    final lower = clean.toLowerCase();
    if (lower.endsWith('.webp') || lower.endsWith('.svg') || lower.endsWith('.gif') || lower.endsWith('.avif')) {
      return '${SolApi.downloadUrl}$clean';
    }
    return '${SolApi.imagePreviewUrl}$clean?w=$width&h=$height&crop=$crop';
  }

  static String getFirstPhoto(String? photo) {
    if (photo == null || photo.trim().isEmpty) return '';
    final parts = photo
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s != 'null')
        .toList();
    if (parts.isEmpty) return '';
    return parts.first;
  }

  static String getMerchantLogo(String? photo) {
    if (photo == null || photo.trim().isEmpty) return '';
    final parts = photo
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s != 'null')
        .toList();
    if (parts.isEmpty) return '';
    // JTTech stores merchant photos as "cover,logo". If 2+ parts, parts[1] is the logo; otherwise parts[0].
    if (parts.length > 1) {
      return parts[1];
    }
    return parts[0];
  }

  /// Builds direct Google Maps navigation URL to the customer's delivery destination.
  /// Prioritizes GPS coordinates (lat, lng), then falls back to encoded address text.
  static String? getCustomerNavigationUrl({double? lat, double? lng, String? address}) {
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      return 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    }
    if (address != null && address.trim().isNotEmpty && address.trim() != 'null') {
      return 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address.trim())}';
    }
    return null;
  }

  static String getDownloadUrl(String subUrl) => SolApi.downloadUrl + GlobalVar.getString(subUrl);

  static String getString(String? string, [String defultValue = ""]) => string ?? defultValue;
  static bool checkString(String? string) => string != null && string.trim().isNotEmpty && string.trim() != 'null';

  static String numToString(dynamic value, [String defultValue = '0']) => value != null ? value.toString() : defultValue;
  static String doubleToString(dynamic value, [String defultValue = '0.0']) => value != null ? value.toStringAsFixed(2) : defultValue;

  static String currencyForamt(num amount, {String currencySymbol = '', int decimalCount = 2}) {
    final formatCurrency = NumberFormat.simpleCurrency(decimalDigits: decimalCount, locale: 'EN', name: currencySymbol);
    return formatCurrency.format(amount);
  }

  static String priceForamt(dynamic price) {
    if (price == null) return '0';
    double val = (price is num) ? price.toDouble() : (double.tryParse(price.toString()) ?? 0.0);
    if (val == val.roundToDouble()) {
      return val.toInt().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return val.toStringAsFixed(2);
  }

  static String? dateForamt(dynamic date, [String foramt = 'y-M-d']) {
    DateTime? temp;
    if (date is String) {
      temp = DateTime.tryParse(date);
    } else {
      temp = date;
    }
    if (temp != null) {
      return DateFormat(foramt).format(temp.toLocal());
    } else {
      return null;
    }
  }

  static DateTime dateResetClock({DateTime? date}) {
    date ??= DateTime.now();
    return DateTime(date.year, date.month, date.day);
  }

  static dynamic getFirstListItem(List list) => checkListNotEmpty(list) ? list.first : null;

  static bool checkListNotEmpty(List? list) => list != null && list.isNotEmpty;

  static String getIdFromUrl(String url) {
    return url.split('/').last;
  }

  static void log(String message) {
    if (kDebugMode) {
      developer.log(message);
    }
  }
}

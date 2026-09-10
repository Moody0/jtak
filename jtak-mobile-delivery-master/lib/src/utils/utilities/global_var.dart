import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import '../../../generated/locale_base.dart';
import '../providers/sol_api.dart';

late LocaleBase str;

class GlobalVar {
  ////////////{ Methods}

  static String getAssetsImage(String imageName) => "assets/images/$imageName";

  static String getImageUrl(String imageName, {int width = 300, int height = 200, bool crop = true}) =>
      SolApi.imagePreviewUrl + getString(imageName) + '?w=$width&h=$height&crop=$crop';

  static String getDownloadUrl(String subUrl) => SolApi.downloadUrl + GlobalVar.getString(subUrl);

  static String getString(String? string, [String defultValue = ""]) => string ?? defultValue;
  static bool checkString(String? string) => string != null && string.isNotEmpty;

  static String numToString(dynamic value, [String defultValue = '0']) => value != null ? value.toString() : defultValue;
  static String doubleToString(dynamic value, [String defultValue = '0.0']) => value != null ? value.toStringAsFixed(2) : defultValue;

  static String currencyForamt(num amount, {String currencySymbol = '', int decimalCount = 2}) {
    final formatCurrency = NumberFormat.simpleCurrency(decimalDigits: decimalCount, locale: 'EN', name: currencySymbol);
    return formatCurrency.format(amount);
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

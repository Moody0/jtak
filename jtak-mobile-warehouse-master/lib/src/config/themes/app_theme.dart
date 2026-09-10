import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';

class AppTheme {
  static const String fontFamily = 'Tajawal';

  static const standardPadding = EdgeInsets.all(16);

  static const boxShadow = [BoxShadow(blurRadius: 22, color: Colors.black12, offset: Offset(0, 6))];

  static const double borderRadiusValue = 5.0;
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(borderRadiusValue));

  static InputDecoration getBorderdTextFieldDecoration({String? lable, String? hint, EdgeInsets? contentPadding}) {
    return InputDecoration(
      labelText: lable,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 12),
      isDense: true,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      border: const OutlineInputBorder(borderSide: BorderSide(color: kPrimaryColor)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kAccentColor)),
    );
  }

  static InputDecoration getTextFieldDecoration({String? lable, String? hint, EdgeInsets? contentPadding}) {
    return InputDecoration(
      labelText: lable,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 12),
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    );
  }

  static Decoration getContainerBorderDecoration() {
    return BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(borderRadiusValue));
  }

  static void setstatusBarColor({Color color = kCardBackground, Brightness? brightness}) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: color,
      statusBarIconBrightness: brightness ?? Brightness.dark,
    ));
  }

  static const flatButtonTextStyle1 = TextStyle(
    color: kAccentColor,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  static const numberStyle = TextStyle(fontSize: 15.0, color: Colors.black, height: 1.1, fontFamily: fontFamily);
  static const linkStyle = TextStyle(fontSize: 15.0, color: Colors.blue, decoration: TextDecoration.underline);

  static const currencyIntegerStyleLarg =
      TextStyle(fontSize: 20.0, height: 1, color: kAccentColor, fontWeight: FontWeight.w400, fontFamily: fontFamily);
  static const currencyIntegerStyleSmall =
      TextStyle(fontSize: 14.0, height: 0.7, color: kAccentColor, fontWeight: FontWeight.w400, fontFamily: fontFamily);
  static const currencyStringStyleLarg = TextStyle(fontSize: 20.0, color: kAccentColor, fontWeight: FontWeight.w600, fontFamily: fontFamily);
  static const currencyStringStyleSmall = TextStyle(fontSize: 13.0, color: kAccentColor, fontWeight: FontWeight.w600, fontFamily: fontFamily);

  static const discountCurrencyStyle = TextStyle(fontSize: 12.0, color: Colors.black, decoration: TextDecoration.lineThrough, fontFamily: fontFamily);
}

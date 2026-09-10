import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';

class AppTheme {
  static const String fontFamily = 'IBMPlexSansArabic';

  static const standardPadding = EdgeInsets.all(16);

  static const List<BoxShadow> boxShadow = [];

  static const double borderRadiusValue = 16.0;
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(borderRadiusValue));

  static const EdgeInsets contentPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  static InputDecoration getBorderdTextFieldDecoration({String? lable, String? hint, EdgeInsets? contentPadding}) {
    return InputDecoration(
      labelText: lable,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: kCharcoalMuted),
      hintStyle: const TextStyle(fontSize: 13, color: kCharcoalLight),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kCardBorderColor, width: 1.1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kCardBorderColor, width: 1.1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5),
      ),
    );
  }

  static InputDecoration getTextFieldDecoration({String? lable, String? hint, EdgeInsets? contentPadding}) {
    return InputDecoration(
      labelText: lable,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: kCharcoalMuted),
      hintStyle: const TextStyle(fontSize: 13, color: kCharcoalLight),
      filled: true,
      fillColor: kGreyBackground,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5),
      ),
    );
  }

  static Decoration getContainerBorderDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: kCardBorderColor, width: 1),
      borderRadius: BorderRadius.circular(borderRadiusValue),
      boxShadow: boxShadow,
    );
  }

  static void setstatusBarColor({Color color = kCardBackground, Brightness? brightness}) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: color,
      statusBarIconBrightness: brightness ?? Brightness.dark,
    ));
  }

  static const flatButtonTextStyle1 = TextStyle(
    color: kPrimaryOrange,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  static const numberStyle = TextStyle(fontSize: 15.0, color: kCharcoalDark, height: 1.1, fontFamily: fontFamily);
  static const linkStyle = TextStyle(fontSize: 14.0, color: kPrimaryOrange, decoration: TextDecoration.underline);

  static const currencyIntegerStyleLarg = TextStyle(fontSize: 20.0, color: kPrimaryOrange, fontWeight: FontWeight.w700, fontFamily: fontFamily);
  static const currencyIntegerStyleSmall = TextStyle(fontSize: 15.0, color: kPrimaryOrange, fontWeight: FontWeight.w700, fontFamily: fontFamily);
  static const currencyStringStyleLarg = TextStyle(fontSize: 14.0, color: kPrimaryOrange, fontWeight: FontWeight.w700, fontFamily: fontFamily);
  static const currencyStringStyleSmall = TextStyle(fontSize: 12.0, color: kPrimaryOrange, fontWeight: FontWeight.w700, fontFamily: fontFamily);
  static const currencyDecimalStyleLarg = TextStyle(fontSize: 14.0, color: kPrimaryOrange, fontFamily: fontFamily);
  static const currencyDecimalStyleSmall = TextStyle(fontSize: 11.0, color: kPrimaryOrange, fontFamily: fontFamily);

  static const discountCurrencyStyle = TextStyle(
    color: kCharcoalLight,
    decoration: TextDecoration.lineThrough,
    fontSize: 12,
  );
}

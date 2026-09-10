import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

const colorBlack = Color.fromRGBO(48, 47, 48, 1.0);
const colorGrey = Color.fromRGBO(141, 141, 141, 1.0);
const TextTheme textThemeDefault = TextTheme(
  displayLarge:
      TextStyle(color: colorBlack, fontWeight: FontWeight.w500, fontSize: 26),
  displayMedium:
      TextStyle(color: colorBlack, fontWeight: FontWeight.w500, fontSize: 22),
  displaySmall:
      TextStyle(color: colorBlack, fontWeight: FontWeight.w500, fontSize: 20),
  headlineMedium:
      TextStyle(color: colorBlack, fontWeight: FontWeight.w500, fontSize: 16),
  headlineSmall:
      TextStyle(color: colorBlack, fontWeight: FontWeight.w700, fontSize: 14),
  titleLarge:
      TextStyle(color: colorBlack, fontWeight: FontWeight.w700, fontSize: 12),
  bodyLarge: TextStyle(
      color: colorBlack,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.normal),
  bodyMedium: TextStyle(color: colorBlack, fontSize: 12, height: 1.5),
  titleMedium: TextStyle(color: colorBlack, fontSize: 13),
  titleSmall:
      TextStyle(color: colorGrey, fontSize: 12, fontWeight: FontWeight.w400),
  labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
);

const TextTheme textThemeSmall = TextTheme(
  displayLarge: TextStyle(
      fontSize: 18, color: kPrimaryColorDark, fontWeight: FontWeight.w900),
  displayMedium:
      TextStyle(color: colorBlack, fontWeight: FontWeight.w700, fontSize: 20),
  displaySmall: TextStyle(
      color: colorBlack,
      fontWeight: FontWeight.w700,
      fontSize: 18,
      height: 1.2),
  headlineMedium:
      TextStyle(color: colorBlack, fontWeight: FontWeight.w700, fontSize: 14),
  headlineSmall:
      TextStyle(color: colorBlack, fontWeight: FontWeight.w700, fontSize: 12),
  titleLarge:
      TextStyle(color: colorBlack, fontWeight: FontWeight.w700, fontSize: 10),
  bodyLarge: TextStyle(
      color: colorBlack,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.5),
  bodyMedium: TextStyle(
      color: colorGrey, fontSize: 12, fontWeight: FontWeight.w500, height: 1.5),
  titleMedium:
      TextStyle(color: colorBlack, fontSize: 10, fontWeight: FontWeight.w400),
  titleSmall:
      TextStyle(color: colorGrey, fontSize: 10, fontWeight: FontWeight.w400),
  labelLarge:
      TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
);

const numberStyle =
    TextStyle(fontSize: 15.0, color: Colors.black, fontFamily: 'NumberFont');
const linkStyle = TextStyle(
    fontSize: 15.0, color: Colors.blue, decoration: TextDecoration.lineThrough);

final darkTheme = ThemeData(
  primarySwatch: Colors.grey,
  primaryColor: Colors.black,
  primaryColorLight: Colors.black87,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF212121),
  dividerColor: Colors.black12,
  textTheme: textThemeDefault,
);

final lightTheme = ThemeData(
  primaryColor: kPrimaryColor,
  colorScheme: const ColorScheme(
    primary: kPrimaryColor,
    secondary: kAccentColor,
    surface: kCardBackground,
    error: Colors.amber,
    onPrimary: Colors.white,
    onSecondary: Colors.pink,
    onSurface: Colors.black,
    onError: Colors.blueGrey,
    brightness: Brightness.light,
  ),

  brightness: Brightness.light,
  scaffoldBackgroundColor: kPageBackground,
  textTheme: GoogleFonts.tajawalTextTheme(
      textThemeDefault), // same in appTheme.fontFamily

  ////////////////{ AppBar Theme } ////////////////
  appBarTheme: const AppBarTheme(
    elevation: 1,
  ),

  ////////////////{ Buttons Theme } ////////////////
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kAccentColor,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16),
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: kAccentColor)),
  textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kAccentColor)),

  ////////////////{ Card Theme } ////////////////
  cardTheme: CardThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    margin: const EdgeInsets.all(4),
    shadowColor: Colors.black38,
    elevation: 6,
    color: kCardBackground,
    clipBehavior: Clip.antiAlias,
  ),
);
////////////////{ Orginal } ////////////////
//  final lightTheme = ThemeData(
//   primarySwatch: Colors.grey,
//   primaryColor: Colors.white,
//   brightness: Brightness.light,
//   backgroundColor: const Color(0xFFE5E5E5),
//   accentColor: Colors.black,
//   accentIconTheme: IconThemeData(color: Colors.white),
//   dividerColor: Colors.white54,
// );

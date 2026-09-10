import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
export 'colors.dart';

final darkTheme = ThemeData(
  primarySwatch: kPrimaryColor,
  primaryColor: kPrimaryOrange,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0F172A),
  dividerColor: Colors.white12,
  textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(textThemeDefault),
  visualDensity: VisualDensity.adaptivePlatformDensity,
);

final lightTheme = ThemeData(
  primarySwatch: kPrimaryColor,
  primaryColor: kPrimaryOrange,
  colorScheme: const ColorScheme(
    primary: kPrimaryOrange,
    secondary: kPrimaryOrangeLight,
    surface: kCardBackground,
    error: kRed,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: kCharcoalDark,
    onError: Colors.white,
    brightness: Brightness.light,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: kPageBackground,
  textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(textThemeDefault),

  ////////////////{ AppBar Theme } ////////////////
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Colors.white,
    foregroundColor: kCharcoalDark,
    surfaceTintColor: Colors.transparent,
    iconTheme: IconThemeData(color: kCharcoalDark, size: 24),
    actionsIconTheme: IconThemeData(color: kCharcoalDark, size: 24),
    titleTextStyle: TextStyle(
      color: kCharcoalDark,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      fontFamily: 'IBMPlexSansArabic',
    ),
    titleSpacing: 16,
  ),

  ////////////////{ Buttons Theme } ////////////////
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        height: 1.2,
      ),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kPrimaryOrange,
      side: const BorderSide(color: kPrimaryOrange, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        height: 1.2,
      ),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kPrimaryOrange,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    ),
  ),

  ////////////////{ Card Theme } ////////////////
  cardTheme: CardThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: kBorderColor, width: 1),
    ),
    margin: const EdgeInsets.all(0),
    shadowColor: const Color(0x0A000000),
    elevation: 2,
    color: kCardBackground,
    clipBehavior: Clip.antiAlias,
  ),
);

////////////////{ Text Styles (IBM Plex Sans Arabic Spec) } ////////////////

const TextTheme textThemeDefault = TextTheme(
  displayLarge: TextStyle(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 28, height: 1.25),
  displayMedium: TextStyle(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 24, height: 1.25),
  displaySmall: TextStyle(color: kCharcoalDark, fontWeight: FontWeight.w600, fontSize: 20, height: 1.3),
  headlineMedium: TextStyle(color: kCharcoalDark, fontWeight: FontWeight.w600, fontSize: 18, height: 1.3),
  headlineSmall: TextStyle(color: kCharcoalDark, fontWeight: FontWeight.w600, fontSize: 16, height: 1.3),
  titleLarge: TextStyle(color: kCharcoalDark, fontWeight: FontWeight.w600, fontSize: 15, height: 1.3),
  bodyLarge: TextStyle(color: kCharcoalDark, fontSize: 15, height: 1.45, fontWeight: FontWeight.w400),
  bodyMedium: TextStyle(color: kCharcoalMedium, fontSize: 13, height: 1.45, fontWeight: FontWeight.w400),
  titleMedium: TextStyle(color: kCharcoalDark, fontSize: 14, height: 1.3, fontWeight: FontWeight.w500),
  titleSmall: TextStyle(color: kCharcoalMuted, fontSize: 12, height: 1.3, fontWeight: FontWeight.w400),
  labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
);

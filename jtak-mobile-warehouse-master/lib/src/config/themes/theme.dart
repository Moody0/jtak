import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
export 'colors.dart';

const colorBlack = kCharcoalDark;
const colorGrey = kCharcoalMuted;

final TextTheme textThemeDefault = TextTheme(
  displayLarge: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w800, fontSize: 26),
  displayMedium: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 22),
  displaySmall: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 20),
  headlineMedium: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 16),
  headlineSmall: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 14),
  titleLarge: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 12),
  bodyLarge: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontSize: 14, height: 1.5, fontWeight: FontWeight.normal),
  bodyMedium: GoogleFonts.ibmPlexSansArabic(color: kCharcoalMedium, fontSize: 12, height: 1.5),
  titleMedium: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontSize: 13, fontWeight: FontWeight.w600),
  titleSmall: GoogleFonts.ibmPlexSansArabic(color: kCharcoalMuted, fontSize: 12, fontWeight: FontWeight.w500),
  labelLarge: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
);

final TextTheme textThemeSmall = TextTheme(
  displayLarge: GoogleFonts.ibmPlexSansArabic(fontSize: 18, color: kPrimaryOrangeDark, fontWeight: FontWeight.w900),
  displayMedium: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 20),
  displaySmall: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 18, height: 1.2),
  headlineMedium: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 14),
  headlineSmall: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 12),
  titleLarge: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontWeight: FontWeight.w700, fontSize: 10),
  bodyLarge: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontSize: 12, fontWeight: FontWeight.w500, height: 1.5),
  bodyMedium: GoogleFonts.ibmPlexSansArabic(color: kCharcoalMuted, fontSize: 12, fontWeight: FontWeight.w500, height: 1.5),
  titleMedium: GoogleFonts.ibmPlexSansArabic(color: kCharcoalDark, fontSize: 10, fontWeight: FontWeight.w500),
  titleSmall: GoogleFonts.ibmPlexSansArabic(color: kCharcoalMuted, fontSize: 10, fontWeight: FontWeight.w500),
  labelLarge: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
);

const numberStyle = TextStyle(fontSize: 15.0, color: kCharcoalDark, fontFamily: 'NumberFont');
const linkStyle = TextStyle(fontSize: 15.0, color: kPrimaryOrange, decoration: TextDecoration.underline);

final darkTheme = ThemeData(
  primarySwatch: kPrimaryColor,
  primaryColor: kPrimaryOrange,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0F172A),
  dividerColor: Colors.white12,
  textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(textThemeDefault),
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
    iconTheme: IconThemeData(color: kCharcoalDark, size: 22),
    actionsIconTheme: IconThemeData(color: kCharcoalDark, size: 22),
    titleTextStyle: TextStyle(
      color: kCharcoalDark,
      fontSize: 17,
      fontWeight: FontWeight.w800,
      fontFamily: 'IBMPlexSansArabic',
    ),
    centerTitle: true,
  ),

  ////////////////{ Buttons Theme } ////////////////
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 15),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kPrimaryOrange,
      side: const BorderSide(color: kPrimaryOrange, width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 15),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: kPrimaryOrange),
  ),

  ////////////////{ Card Theme } ////////////////
  cardTheme: CardThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: kCardBorderColor, width: 1.0),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    elevation: 0,
    color: kCardBackground,
    clipBehavior: Clip.antiAlias,
  ),
);

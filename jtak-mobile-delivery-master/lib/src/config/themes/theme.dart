import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
export 'colors.dart';

final darkTheme = ThemeData(
  primarySwatch: kPrimaryColor,
  primaryColor: kPrimaryOrange,
  colorScheme: const ColorScheme(
    primary: kPrimaryOrange,
    secondary: kPrimaryOrangeLight,
    surface: Color(0xFF1E293B),
    error: kRed,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,
    onError: Colors.white,
    brightness: Brightness.dark,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0F172A),
  dividerColor: const Color(0xFF334155),
  textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(textThemeDark),

  ////////////////{ AppBar Theme } ////////////////
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFF1E293B),
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    iconTheme: IconThemeData(color: Colors.white, size: 24),
    actionsIconTheme: IconThemeData(color: Colors.white, size: 24),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      fontFamily: 'IBMPlexSansArabic',
    ),
    titleSpacing: 16,
  ),

  ////////////////{ Dialog & BottomSheet Theme } ////////////////
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFF1E293B),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFF334155), width: 1.1),
    ),
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 16.5,
      fontWeight: FontWeight.w700,
      fontFamily: 'IBMPlexSansArabic',
    ),
    contentTextStyle: const TextStyle(
      color: Color(0xFFCBD5E1),
      fontSize: 13.5,
      fontFamily: 'IBMPlexSansArabic',
    ),
  ),

  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xFF1E293B),
    modalBackgroundColor: Color(0xFF1E293B),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  ),

  snackBarTheme: SnackBarThemeData(
    backgroundColor: const Color(0xFF1E293B),
    contentTextStyle: const TextStyle(
      color: Colors.white,
      fontFamily: 'IBMPlexSansArabic',
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFF334155), width: 1),
    ),
    behavior: SnackBarBehavior.floating,
  ),

  popupMenuTheme: PopupMenuThemeData(
    color: const Color(0xFF1E293B),
    surfaceTintColor: Colors.transparent,
    textStyle: const TextStyle(
      color: Colors.white,
      fontFamily: 'IBMPlexSansArabic',
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFF334155), width: 1),
    ),
  ),

  dividerTheme: const DividerThemeData(
    color: Color(0xFF334155),
    thickness: 1,
    space: 1,
  ),

  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith((states) =>
        states.contains(MaterialState.selected)
            ? kPrimaryOrange
            : const Color(0xFF94A3B8)),
    trackColor: MaterialStateProperty.resolveWith((states) =>
        states.contains(MaterialState.selected)
            ? kPrimaryOrange.withOpacity(0.4)
            : const Color(0xFF334155)),
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
      side: const BorderSide(color: Color(0xFF334155), width: 1),
    ),
    margin: const EdgeInsets.all(0),
    shadowColor: Colors.transparent,
    elevation: 0,
    color: const Color(0xFF1E293B),
    clipBehavior: Clip.antiAlias,
  ),

  ////////////////{ Drawer Theme } ////////////////
  drawerTheme: const DrawerThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    elevation: 0,
    backgroundColor: Color(0xFF1E293B),
  ),

  ////////////////{ Input Decoration Theme } ////////////////
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1E293B),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
    labelStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF334155), width: 1.1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF334155), width: 1.1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kPrimaryOrange, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kRed, width: 1.2),
    ),
  ),
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
      fontSize: 17,
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
    shadowColor: Colors.transparent,
    elevation: 0,
    color: kCardBackground,
    clipBehavior: Clip.antiAlias,
  ),

  ////////////////{ Drawer Theme } ////////////////
  drawerTheme: const DrawerThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    elevation: 0,
    backgroundColor: Colors.white,
  ),

  ////////////////{ Input Decoration Theme } ////////////////
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kCardBorderColor, width: 1.1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kCardBorderColor, width: 1.1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kPrimaryOrange, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kRed, width: 1.2),
    ),
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
  labelSmall: TextStyle(color: kCharcoalMuted, fontSize: 11, height: 1.2),
);

const TextTheme textThemeDark = TextTheme(
  displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 28, height: 1.25),
  displayMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 24, height: 1.25),
  displaySmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20, height: 1.3),
  headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18, height: 1.3),
  headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16, height: 1.3),
  titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15, height: 1.3),
  bodyLarge: TextStyle(color: Colors.white, fontSize: 15, height: 1.45, fontWeight: FontWeight.w400),
  bodyMedium: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.45, fontWeight: FontWeight.w400),
  titleMedium: TextStyle(color: Colors.white, fontSize: 14, height: 1.3, fontWeight: FontWeight.w500),
  titleSmall: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3, fontWeight: FontWeight.w400),
  labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
  labelSmall: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.2),
);

const TextTheme textThemeSmall = textThemeDefault;

const numberStyle = TextStyle(fontSize: 15.0, color: kCharcoalDark, fontFamily: 'NumberFont');
const linkStyle = TextStyle(fontSize: 14.0, color: kPrimaryOrange, decoration: TextDecoration.underline);

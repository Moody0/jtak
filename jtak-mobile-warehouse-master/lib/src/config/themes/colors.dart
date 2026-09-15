import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// JTAK Design Tokens & Color Palette (Dominant Orange System)
/// Store Owner & Merchant Operations
/// ---------------------------------------------------------------------------

// 🟠 Dominant Brand & Action Orange
const kPrimaryOrange = Color(0xFFFF5400);
const kPrimaryOrangeDark = Color(0xFFE04800);
const kPrimaryOrangeLight = Color(0xFFFF7A33);
const kSoftPeach = Color(0xFFFFF3EB);

// 🎨 Primary Swatch based on Dominant Orange (#FF5400)
const kPrimaryColor = MaterialColor(0xFFFF5400, <int, Color>{
  50: Color(0xFFFFF3EB),
  100: Color(0xFFFFDEC9),
  200: Color(0xFFFFC5A3),
  300: Color(0xFFFFA77A),
  400: Color(0xFFFF7D42),
  500: Color(0xFFFF5400),
  600: Color(0xFFE54A00),
  700: Color(0xFFC43E00),
  800: Color(0xFFA33300),
  900: Color(0xFF752400),
});

const kAccentColor = Color(0xFFFF5400);
const kPrimaryColorDark = Color(0xFFE04800);
const kPrimaryColorLight = Color(0xFFFF7A33);

// 🖤 Modern Neutral Charcoals (Crisp Arabic Typography & Structure)
const kCharcoalDark = Color(0xFF0F172A);    // Primary text & titles (deep slate)
const kCharcoalMedium = Color(0xFF334155);  // Secondary body text
const kCharcoalMuted = Color(0xFF64748B);   // Subtitles, metadata, captions
const kCharcoalLight = Color(0xFF94A3B8);   // Placeholders, disabled icons

// Legacy constant aliases for backward-compatibility
const colorBlack = Color(0xFF0F172A);
const colorGrey = Color(0xFF64748B);

// 🤍 Clean Surfaces & Backgrounds (Tactile, Crisp, Zero Muddy Shadows)
const kCanvasBackground = Color(0xFFF8FAFC); // Soft serene page background
const kPageBackground = Color(0xFFF8FAFC);   // Soft slate page background
const kCardBackground = Color(0xFFFFFFFF);   // Pure white card surface
const kCardSurface = Color(0xFFFFFFFF);      // Pure white card surface
const kGreyBackground = Color(0xFFF1F5F9);   // Neutral light grey
const kSurfaceWarm = Color(0xFFFFF7ED);      // Peach/Orange tint for chips & badges
const kBorderColor = Color(0xFFE2E8F0);      // Crisp architectural card border
const kBorderSubtle = Color(0xFFE2E8F0);     // 1px clean border stroke
const kBorderHairline = Color(0xFFF1F5F9);   // Micro-hairline divider
const kCardBorderColor = Color(0xFFE2E8F0);  // Crisp card outline border token

// 🚦 Status & Semantic Colors
const kGreen = Color(0xFF10B981);           // Success, Open store, Ready order
const kGreenLight = Color(0xFFECFDF5);      // Open store pill background
const kRed = Color(0xFFEF4444);             // Error, Closed store, Cancelled
const kRedLight = Color(0xFFFEF2F2);        // Closed store pill background
const kAmber = Color(0xFFF59E0B);           // Warning, Busy store, Preparing
const kAmberLight = Color(0xFFFFFBEB);      // Busy / Preparing badge background
const kGrey = Color(0xFF94A3B8);
const kGreyLight = Color(0xFFCBD5E1);
const kGreyDark = Color(0xFF64748B);
const kIconColor = Color(0xFFFF5400);
const jtakOrange = kPrimaryOrange;

class JtakColors {
  static const primary = kPrimaryOrange;
  static const primaryDark = kPrimaryOrangeDark;
  static const primaryLight = kPrimaryOrangeLight;
}

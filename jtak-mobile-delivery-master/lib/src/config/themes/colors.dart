import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// JTAK Design Tokens & Color Palette (Dominant Orange System)
/// ---------------------------------------------------------------------------

// 🟠 Dominant Brand & Action Orange
const kPrimaryOrange = Color(0xFFFF5400);
const kPrimaryOrangeDark = Color(0xFFE04800);
const kPrimaryOrangeLight = Color(0xFFFF7A33);
const kPrimaryOrangeGlow = Color(0x33FF5400);

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
const kCharcoalDark = Color(0xFF111827);    // Primary text & titles
const kCharcoalMedium = Color(0xFF374151);  // Secondary body text
const kCharcoalMuted = Color(0xFF6B7280);   // Subtitles, metadata, captions
const kCharcoalLight = Color(0xFF9CA3AF);   // Placeholders, disabled icons

// Legacy constant aliases for backward-compatibility
const colorBlack = Color(0xFF111827);
const colorGrey = Color(0xFF6B7280);
const kGreyLight = Color(0xFFE5E7EB);
const kGreyDark = Color(0xFF4B5563);

// 🤍 Clean Surfaces & Backgrounds
const kPageBackground = Color(0xFFF8FAFC);  // Soft slate page background
const kCardBackground = Color(0xFFFFFFFF);  // Pure white card surface
const kGreyBackground = Color(0xFFF3F4F6);  // Neutral light grey
const kSurfaceWarm = Color(0xFFFFF3EB);     // Peach/Orange tint for chips & badges
const kBorderColor = Color(0xFFF1F5F9);     // Subtle card border stroke
const kCardBorderColor = Color(0xFFE2E8F0); // Crisp card outline border token

// 🚦 Status & Semantic Colors
const kGreen = Color(0xFF10B981);           // Success, Delivered, Active
const kGreenLight = Color(0xFFECFDF5);      // Soft green tint
const kRed = Color(0xFFEF4444);             // Error, Cancelled
const kRedLight = Color(0xFFFEF2F2);        // Soft red tint
const kAmber = Color(0xFFF59E0B);           // Warning, In Transit, Ratings
const kAmberLight = Color(0xFFFFFBEB);      // Soft amber tint
const kBlue = Color(0xFF3B82F6);            // Navigation / Info
const kBlueLight = Color(0xFFEFF6FF);       // Soft blue tint
const kGrey = Color(0xFF9CA3AF);
const kIconColor = Color(0xFFFF5400);

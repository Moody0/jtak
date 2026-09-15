import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants/app_constant.dart';

/// ---------------------------------------------------------------------------
/// JTAK Centralized External URL, WhatsApp & Call Launcher Helper
/// Robust fallback handling across Android 11+ and iOS
/// ---------------------------------------------------------------------------
class LunchUrl {
  /// Opens native phone dialer with specified phone number.
  /// Defaults to [kSupportPhoneNumber] ('0985615705') if null or empty.
  static Future<bool> makeCall(String? phone, {BuildContext? context}) async {
    final rawPhone = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : kSupportPhoneNumber;
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
      return await launchUrl(uri);
    } catch (_) {
      try {
        return await launchUrl(uri);
      } catch (err) {
        debugPrint("LunchUrl: Can't call $cleanPhone: $err");
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تعذر الاتصال بالرقم $cleanPhone',
                style:
                    GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return false;
      }
    }
  }

  /// Opens WhatsApp conversation with target phone and optional pre-filled message.
  /// Falls back gracefully from wa.me universal link to whatsapp:// scheme.
  static Future<bool> openWhatsApp({
    String? phone,
    String? message,
    BuildContext? context,
  }) async {
    String target = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : kSupportWhatsAppNumber;

    // Sanitize phone to international digits without '+' or spaces
    target = target.replaceAll(RegExp(r'[^\d]'), '');
    if (target.startsWith('09') && target.length == 10) {
      target = '963${target.substring(1)}';
    } else if (target.startsWith('0') && target.length >= 9) {
      target = '963${target.substring(1)}';
    }

    final query = (message != null && message.trim().isNotEmpty)
        ? '?text=${Uri.encodeComponent(message.trim())}'
        : '';
    final waMeUri = Uri.parse('https://wa.me/$target$query');
    final nativeUri = Uri.parse(
        'whatsapp://send?phone=$target${(message != null && message.trim().isNotEmpty) ? '&text=${Uri.encodeComponent(message.trim())}' : ''}');

    // 1. Try wa.me via external application
    try {
      final launched =
          await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {}

    // 2. Try native whatsapp:// scheme
    try {
      final launchedNative =
          await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      if (launchedNative) return true;
    } catch (_) {}

    // 3. Try platform default fallback
    try {
      final launchedFallback = await launchUrl(waMeUri);
      if (launchedFallback) return true;
    } catch (_) {}

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر فتح تطبيق واتساب. يرجى التأكد من تثبيت التطبيق.',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return false;
  }

  /// Generic URL launcher with external application mode preference
  static Future<bool> openUrl(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
      return await launchUrl(uri);
    } catch (err) {
      debugPrint("LunchUrl: Can't launch $urlStr: $err");
      return false;
    }
  }

  /// Backward compatibility
  static Future<bool> canLaunch(String url) async {
    return openUrl(url);
  }
}

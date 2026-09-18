import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// ---------------------------------------------------------------------------
/// Syrian Phone Number Helper & Formatter (Delivery / Driver App)
/// ---------------------------------------------------------------------------
/// Handles:
/// 1. Arabic-Indic (٠-٩) and Persian (۰-۹) numerals conversion to ASCII (0-9).
/// 2. Normalization to 9-digit local Syrian mobile number (without 963 / 0).
/// 3. Normalization before length limiting to prevent premature truncation.
/// 4. Formatting for dialing (tel:), WhatsApp (wa.me), and international APIs (+963).
/// ---------------------------------------------------------------------------
class PhoneHelper {
  /// Converts Eastern Arabic (٠-٩) and Persian (۰-۹) digits to standard Western digits (0-9)
  /// and removes all non-numeric characters (preserving a leading '+' by default).
  static String cleanDigits(String? input, {bool preservePlus = true}) {
    if (input == null) return '';
    String text = input.trim();
    if (text.isEmpty || text == 'null') return '';

    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabic = '۰۱۲۳۴۵۶۷۸۹';
    for (int i = 0; i < 10; i++) {
      text = text.replaceAll(arabicIndic[i], i.toString());
      text = text.replaceAll(easternArabic[i], i.toString());
    }

    final hasLeadingPlus = text.startsWith('+');
    text = text.replaceAll(RegExp(r'[^0-9]'), '');
    return (preservePlus && hasLeadingPlus) ? '+$text' : text;
  }

  /// Normalizes any Syrian phone number input to exactly the 9-digit local format:
  /// (e.g. `912345678`), stripping `+963`, `00963`, `963`, and leading `0`.
  /// Converts Eastern Arabic & Persian numerals to Western digits.
  /// Enforces max length of 9 digits.
  ///
  /// Examples:
  /// - `963912345678` -> `912345678`
  /// - `+963912345678` -> `912345678`
  /// - `+963 912 345 678` -> `912345678`
  /// - `963-912-345-678` -> `912345678`
  /// - `00963912345678` -> `912345678`
  /// - `0912345678` -> `912345678`
  /// - `912345678` -> `912345678`
  /// - `٩٦٣٩١٢٣٤٥٦٧٨` -> `912345678`
  /// - `٠٩١٢٣٤٥٦٧٨` -> `912345678`
  /// - `۰۹۱۲۳۴۵۶۷۸` -> `912345678`
  static String normalizeSyrianLocalPhone(String? input) {
    if (input == null || input.isEmpty) return '';

    String text = input.trim();
    if (text.isEmpty || text == 'null') return '';

    // Convert Arabic/Persian digits
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabic = '۰۱۲۳۴۵۶۷۸۹';
    for (int i = 0; i < 10; i++) {
      text = text.replaceAll(arabicIndic[i], i.toString());
      text = text.replaceAll(easternArabic[i], i.toString());
    }

    final bool hadExplicitPrefix = text.startsWith('+') || text.startsWith('00');
    String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    // 1. Strip international dial code 00963 or 963
    if (digits.startsWith('00963')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('963') && (hadExplicitPrefix || digits.length >= 10)) {
      digits = digits.substring(3);
    }

    // 2. Strip leading zeros (e.g. 0912345678 -> 912345678)
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // 3. In case of double prefix like +963 0912345678
    if (digits.startsWith('963') && digits.length >= 10) {
      digits = digits.substring(3);
      while (digits.startsWith('0')) {
        digits = digits.substring(1);
      }
    }

    // 4. Max 9 digits
    if (digits.length > 9) {
      digits = digits.substring(0, 9);
    }

    return digits;
  }

  /// Formats a Syrian phone number into the international format (+9639xxxxxxxx).
  static String formatSyrianInternational(String? input) {
    final local = normalizeSyrianLocalPhone(input);
    if (local.isEmpty) return '';
    return '+963$local';
  }

  /// Checks whether the input represents a valid 9-digit Syrian mobile phone number.
  static bool isValidSyrianPhone(String? input) {
    final local = normalizeSyrianLocalPhone(input);
    return local.length == 9 && local.startsWith('9');
  }

  /// Checks whether the phone number is non-empty and valid (Syrian or clean digits >= 7).
  static bool isValidPhone(String? input) {
    if (input == null) return false;
    final clean = cleanDigits(input);
    if (clean.isEmpty) return false;
    return isValidSyrianPhone(input) || clean.length >= 7;
  }

  /// Formats for WhatsApp (wa.me requires international without leading '+')
  static String? formatForWhatsApp(String? input) {
    final local = normalizeSyrianLocalPhone(input);
    if (local.length == 9) {
      return '963$local';
    }
    final raw = cleanDigits(input);
    if (raw.length >= 7) return raw;
    return null;
  }

  /// Formats for native phone dialer (tel:...)
  static String? formatForCalling(String? input) {
    if (input == null || input.isEmpty) return null;
    final raw = cleanDigits(input, preservePlus: true);
    if (raw.isNotEmpty) return 'tel:$raw';
    return null;
  }

  /// Launches native phone dialer for the given number.
  static Future<bool> launchCall(BuildContext? context, String? phone) async {
    final telUrl = formatForCalling(phone);
    if (telUrl == null) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رقم الهاتف غير صالح أو غير متوفر'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    try {
      final uri = Uri.parse(telUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إجراء المكالمة، يرجى التأكد من صلاحيات الجهاز'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  /// Launches WhatsApp with an optional pre-filled message.
  static Future<bool> launchWhatsApp(
    BuildContext? context,
    String? phone, {
    String? message,
  }) async {
    final waNumber = formatForWhatsApp(phone);
    if (waNumber == null) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رقم الواتساب غير صالح أو غير متوفر'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final query = message != null && message.trim().isNotEmpty
        ? '?text=${Uri.encodeComponent(message.trim())}'
        : '';
    final urlString = 'https://wa.me/$waNumber$query';

    try {
      final uri = Uri.parse(urlString);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح تطبيق واتساب على الجهاز'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return launched;
    } catch (_) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح واتساب، يرجى التحقق من تثبيت التطبيق'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }
}

/// Custom TextInputFormatter for Syrian Phone numbers that:
/// 1. Converts Eastern Arabic / Persian digits to Western digits (0-9).
/// 2. Strips prefixes (`+963`, `963`, `00963`, `0`).
/// 3. Automatically normalizes pasted numbers before length limiting.
/// 4. Caps maximum length to exactly 9 digits.
/// 5. Fully supports Copy, Cut, Paste, and Select All.
class SyrianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final normalized = PhoneHelper.normalizeSyrianLocalPhone(newValue.text);

    // If identical and selection is valid, return newValue as is to preserve selection/cursor
    if (normalized == newValue.text && newValue.selection.isValid) {
      return newValue;
    }

    // Determine cursor offset
    int newOffset = normalized.length;
    if (newValue.selection.isValid &&
        newValue.selection.baseOffset <= normalized.length &&
        oldValue.text.length < newValue.text.length &&
        !newValue.text.contains(RegExp(r'[\+\s\-\(\)٠-٩۰-۹]'))) {
      newOffset = newValue.selection.baseOffset.clamp(0, normalized.length);
    }

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

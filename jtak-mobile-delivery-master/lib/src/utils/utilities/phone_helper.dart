import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneHelper {
  /// Converts Eastern Arabic (Arabic-Indic) and Persian digits to standard Western digits (0-9)
  /// and removes all formatting characters like spaces, dashes, parentheses.
  static String cleanDigits(String? input) {
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
    return hasLeadingPlus ? '+$text' : text;
  }

  /// Checks whether the input represents a valid, callable phone number.
  static bool isValidPhone(String? input) {
    final cleaned = cleanDigits(input);
    final rawDigits = cleaned.replaceAll('+', '');
    return rawDigits.length >= 7;
  }

  /// Formats a Syrian or international phone number for WhatsApp URLs (`https://wa.me/<number>`).
  /// wa.me requires international country code with NO leading '+', '00', or local '0'.
  /// Examples:
  /// - `0985615705` -> `963985615705`
  /// - `+963985615705` -> `963985615705`
  /// - `00963985615705` -> `963985615705`
  /// - `985615705` -> `963985615705`
  static String? formatForWhatsApp(String? input) {
    if (!isValidPhone(input)) return null;
    String digits = cleanDigits(input).replaceAll('+', '');

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    // Syrian local mobile starting with 09 (10 digits)
    if (digits.startsWith('09') && digits.length == 10) {
      digits = '963${digits.substring(1)}';
    } else if (digits.startsWith('9') && digits.length == 9) {
      // Missing country code and leading zero
      digits = '963$digits';
    } else if (digits.startsWith('0') && digits.length >= 9) {
      // General local number with leading zero, assume Syria 963 if 10 digits
      digits = '963${digits.substring(1)}';
    }

    return digits;
  }

  /// Formats a phone number for dialing via the phone app (`tel:<number>`).
  static String? formatForCalling(String? input) {
    if (!isValidPhone(input)) return null;
    final cleaned = cleanDigits(input);
    return 'tel:$cleaned';
  }

  /// Launches the native phone dialer for the given number.
  /// Returns true on success, false otherwise.
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

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/contact_settings_service.dart';

class LunchUrl {
  static Future<bool> canLaunch(String url) async {
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        return await launchUrl(Uri.parse(url));
      } catch (err) {
        debugPrint("can't launch : $url \n ${err.toString()}");
        return false;
      }
    }
  }

  static Future<bool> makeCall([String? phone]) async {
    final rawPhone = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : ContactSettingsService.instance.phoneNumber;
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    return canLaunch('tel:$cleanPhone');
  }

  static Future<bool> openWhatsApp({String? phone, String? message}) async {
    String target = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : ContactSettingsService.instance.whatsAppNumber;
    target = target.replaceAll(RegExp(r'[^\d]'), '');
    if (target.startsWith('09') && target.length == 10) {
      target = '963${target.substring(1)}';
    }
    final encodedMsg = (message != null && message.trim().isNotEmpty)
        ? '?text=${Uri.encodeComponent(message.trim())}'
        : '';
    return canLaunch('https://wa.me/$target$encodedMsg');
  }
}

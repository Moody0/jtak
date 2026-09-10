import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class LunchUrl {
  static Future<bool> canLaunch(String url) async {
    try {
      return await launchUrl(Uri.parse(url));
    } catch (err) {
      debugPrint("can't launch : $url \n ${err.toString()}");
      return false;
    }
  }
}

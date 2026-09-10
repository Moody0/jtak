import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class LunchUrl {
  static Future<bool> canLaunch(String url) async {
    try {
      await launch(url);
      return true;
    } catch (err) {
      debugPrint("can't launch : $url \n ${err.toString()}");
      return false;
    }
  }
}

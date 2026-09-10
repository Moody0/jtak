import 'dart:developer';

import 'package:flutter/material.dart';
import 'src/core/services/locator.dart';
import 'src/core/controllers/app/app_state_manager.dart';

import 'generated/locale_base.dart';

class LocalDelegate extends LocalizationsDelegate<LocaleBase> {
  const LocalDelegate();
  static const idMap = {
    'ar': 'locales/ar.json',
    'en': 'locales/en.json',
  };

  // List all of the app's supported locales here
  static const supportedLocales = [
    Locale('ar'),
    Locale('en'),
  ];

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<LocaleBase> load(Locale locale) async {
    var lang = 'ar';
    if (isSupported(locale)) lang = locale.languageCode;
    final loc = LocaleBase();
    try {
      await loc.load(idMap[lang] ?? lang);
    } catch (err) {
      log(err.toString());
      lang = 'ar';
      await loc.load(idMap[lang] ?? lang);
    }
    locator<AppStateManager>().setAppLanguage(lang);
    return loc;
  }

  @override
  bool shouldReload(LocalDelegate old) => true;
}

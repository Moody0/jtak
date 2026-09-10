import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'src/core/services/locator.dart';
import 'src/core/controllers/app/app_state_manager.dart';

import 'generated/locale_base.dart';

class LocalDelegate extends LocalizationsDelegate<LocaleBase> {
  const LocalDelegate();
  static const idMap = {
    'ar': 'locales/ar.json',
    'en': 'locales/en.json',
  };

  static const Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    LocalDelegate(),
    GlobalCupertinoLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  // Returns a locale which will be used by the app
  static Locale? localeResolutionCallback(Locale? local, Iterable<Locale> supportedLocales) {
    AppStateManager appStateManager = locator<AppStateManager>();
    if (appStateManager.appLanguage.isNotEmpty) {
      for (var supportedLocale in supportedLocales) {
        if (supportedLocale.languageCode == appStateManager.appLanguage) return supportedLocale;
      }
    }
    // If the locale of the device is not supported, use the first one
    // from the list (English, in this case).
    return supportedLocales.first;
  }

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

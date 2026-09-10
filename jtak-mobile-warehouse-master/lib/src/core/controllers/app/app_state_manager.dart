import 'package:flutter/material.dart';
import '../../../config/constants/shard_preference_kay.dart';
import '../../enums/theme_type.dart';
import '../../../config/themes/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStateManager extends ChangeNotifier {
  AppStateManager();

  Future initializAppState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(themeTypeKey)) {
      _appThemeType = prefs.getInt(themeTypeKey) == ThemeType.dark.index ? ThemeType.dark : ThemeType.light;
      if (appThemeType == ThemeType.dark) setAppTheme(appThemeType);
    }
    if (prefs.containsKey(langKey)) {
      _appLanguage = prefs.getString(langKey) ?? 'ar';
    }
    if (prefs.containsKey(appFirsLunchKey)) {
      _initialized = prefs.getBool(appFirsLunchKey) ?? false;
    }
  }

  // app is run before and initialized
  bool _initialized = false;
  bool get isInitialized => _initialized;
  void setAppInitialized() async {
    _initialized = true;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(appFirsLunchKey, _initialized);
  }

  // app Language
  String _appLanguage = 'ar';
  String get appLanguage => _appLanguage;
  bool get appLanguageIsArabic => _appLanguage == 'ar';
  Future setAppLanguage(String lang) async {
    _appLanguage = lang;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(langKey, lang);
  }

  String getOppositeLanguage() => appLanguage == 'ar' ? 'en' : 'ar';

  // app Theme Type
  ThemeType _appThemeType = ThemeType.light;
  ThemeType get appThemeType => _appThemeType;

  ThemeData _appThemeData = lightTheme;
  ThemeData getAppThemeData() => _appThemeData;
  setAppTheme(ThemeType themeType) async {
    _appThemeType = themeType;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt(themeTypeKey, _appThemeType.index);
    if (appThemeType == ThemeType.dark) {
      _appThemeData = darkTheme;
    } else {
      _appThemeData = lightTheme;
    }
    notifyListeners();
  }
}

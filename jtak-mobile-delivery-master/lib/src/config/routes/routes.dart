import 'package:app_jtak_delivery/src/ui/pages/account/change_password_page.dart';
import 'package:app_jtak_delivery/src/ui/pages/account/login_page.dart';
import 'package:app_jtak_delivery/src/ui/pages/account/profile_page.dart';
import 'package:flutter/material.dart';

import '../../ui/pages/main_page.dart';
import '../../ui/pages/setting_page.dart';
import '../../ui/pages/splash_page.dart';

final Map<String, Widget Function(BuildContext)> appRoutes = {
  SplashPage.routeName: (ctx) => const SplashPage(),
  MainPage.routeName: (ctx) => const MainPage(),
  SettingPage.routeName: (ctx) => const SettingPage(),

  // user pages
  LoginPage.routeName: (ctx) => const LoginPage(),
  ProfilePage.routeName: (ctx) => ProfilePage(),
  ChangePasswordPage.routeName: (ctx) => ChangePasswordPage(),
};

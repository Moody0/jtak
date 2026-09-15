import 'package:app_jtak_warehouse/src/ui/pages/account/change_password_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/account/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:app_jtak_warehouse/src/ui/pages/account/login_page.dart';

import '../../ui/pages/main_page.dart';
import '../../ui/pages/pages/about_app_page.dart';
import '../../ui/pages/setting_page.dart';
import '../../ui/pages/splash_page.dart';
import '../../ui/pages/store/store_location_page.dart';
import '../../ui/pages/store/store_profile_page.dart';

final Map<String, Widget Function(BuildContext)> appRoutes = {
  SplashPage.routeName: (ctx) => const SplashPage(),
  MainPage.routeName: (ctx) => const MainPage(),
  SettingPage.routeName: (ctx) => const SettingPage(),

  // user pages
  LoginPage.routeName: (ctx) => const LoginPage(),
  ProfilePage.routeName: (ctx) => const ProfilePage(),
  ChangePasswordPage.routeName: (ctx) => const ChangePasswordPage(),
  StoreProfilePage.routeName: (ctx) => const StoreProfilePage(),
  StoreLocationPage.routeName: (ctx) => const StoreLocationPage(),
  AboutAppPage.routeName: (ctx) => const AboutAppPage(),
};

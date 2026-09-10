import 'package:flutter/material.dart';
import 'package:jtek_app/src/ui/pages/cart/order_payment_page.dart';
import '../../ui/pages/account/login_page.dart';
import '../../ui/pages/account/profile_page.dart';
import '../../ui/pages/app_notifications_page.dart';
import '../../ui/pages/cart/cart_page.dart';
import '../../ui/pages/cart/check_out_page.dart';
import '../../ui/pages/orders/orders_page.dart';
import '../../ui/pages/address/choose_location_map_page.dart';

import '../../ui/pages/catalog/restaurant_menu_page.dart';
import '../../ui/pages/catalog/restaurants_list_page.dart';
import '../../ui/pages/catalog/search_page.dart';
import '../../ui/pages/main_page.dart';
import '../../ui/pages/splash_page.dart';

final Map<String, Widget Function(BuildContext)> appRoutes = {
  SplashPage.routeName: (ctx) => const SplashPage(),
  MainPage.routeName: (ctx) => const MainPage(),
  AppNotificationsPage.routeName: (ctx) => AppNotificationsPage(),
  RestaurantsListPage.routeName: (ctx) => const RestaurantsListPage(),
  RestaurantMenuPage.routeName: (ctx) => const RestaurantMenuPage(),
  SearchPage.routeName: (ctx) => const SearchPage(),

  // user pages
  LoginPage.routeName: (ctx) => const LoginPage(),
  ProfilePage.routeName: (ctx) => ProfilePage(),

  // cart Pages
  CartPage.routeName: (ctx) => CartPage(),
  CheckOutPage.routeName: (ctx) => CheckOutPage(),
  OrderPaymentPage.routeName: (ctx) => OrderPaymentPage(),
  OrderPage.routeName: (ctx) => OrderPage(),

  // services pages
  ChooseLocationMapPage.routeName: (ctx) => ChooseLocationMapPage(),
};

import 'package:flutter/material.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/controllers/order/order_provider.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import '../../services/locator.dart';
import '../catalog/categories_provider.dart';
import '../catalog/favorite_product_provider.dart';
import '../catalog/markets_provider.dart';
import '../initial_data_provider.dart';
import '../order/cart_provider.dart';
import '../app_notification_provider.dart';
import '../../services/authentication_service.dart';
import 'app_state_manager.dart';
import 'home_navigation_provider.dart';
import 'package:provider/provider.dart';

class RootProvider extends StatelessWidget {
  final Widget child;
  const RootProvider({required this.child, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => locator<AppStateManager>()),
        ChangeNotifierProvider(create: (ctx) => locator<AuthenticationService>()),
        ChangeNotifierProvider(create: (ctx) => locator<AppParametersProvider>()),
        ChangeNotifierProvider(create: (ctx) => locator<AppNotificationProvider>()),
        ChangeNotifierProvider(create: (ctx) => locator<AddressProvider>()),
        ChangeNotifierProvider(create: (ctx) => locator<CartProvider>()),
        ChangeNotifierProvider(create: (ctx) => HomeNavigationProvider()),
        ChangeNotifierProvider(create: (ctx) => locator<CategoriesProvider>()),
        ChangeNotifierProvider(create: (ctx) => InitialDataProvider()),
        ChangeNotifierProvider(create: (ctx) => FavoriteProductProvider()),
        ChangeNotifierProvider(create: (ctx) => OrderProvider()),
        ChangeNotifierProvider(create: (ctx) => locator<MarketsProvider>()),
      ],
      child: child,
    );
  }
}

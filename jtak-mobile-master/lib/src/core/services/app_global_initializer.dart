import 'package:flutter/material.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';
import 'locator.dart';
import '../controllers/app/app_state_manager.dart';
import 'firebase_notification_services.dart';
import '../controllers/catalog/favorite_product_provider.dart';
import '../controllers/initial_data_provider.dart';
import '../controllers/order/cart_provider.dart';
import 'package:provider/provider.dart';

class AppGlobalInitializer {
  static Future mainInitializer() async {
    print("  -> ensureInitialized");
    WidgetsFlutterBinding.ensureInitialized();
    print("  -> FireBaseNotificationServices.basicInitialize");
    await FireBaseNotificationServices.basicInitialize();
    print("  -> setupLocator");
    setupLocator();
    print("  -> initializAppState");
    await locator<AppStateManager>().initializAppState();
    print("  -> getAuthorizationData");
    await locator<AuthenticationService>().getAuthorizationData();
    print("  -> loadLocal address");
    await locator<AppParametersProvider>().mainAddressService.loadLocal();
    print("  -> DONE mainInitializer");
  }

  static Future appLoadMainData(BuildContext context) async {
    try {
      print("appLoadMainData: checkAuthorizationToken");
      try {
        await Provider.of<AuthenticationService>(context, listen: false)
            .checkAuthorizationToken()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        print("  -> checkAuthorizationToken error: $e");
      }
      
      print("appLoadMainData: Future.wait START");
      await Future.wait([
        Provider.of<CartProvider>(context, listen: false)
            .loadLocalCart()
            .then((_) => print("  -> CartProvider done"))
            .catchError((e) => print("  -> CartProvider error: $e")),
        Provider.of<AppParametersProvider>(context, listen: false)
            .loadMainParameters(context)
            .then((_) => print("  -> AppParametersProvider done"))
            .catchError((e) => print("  -> AppParametersProvider error: $e")),
        Provider.of<InitialDataProvider>(context, listen: false)
            .getInitData(context)
            .timeout(const Duration(seconds: 3))
            .then((_) => print("  -> InitialDataProvider done"))
            .catchError((e) => print("  -> InitialDataProvider error: $e")),
        if (locator<AuthenticationService>().isLogin()) ...[
          Provider.of<FavoriteProductProvider>(context, listen: false)
              .loadData()
              .timeout(const Duration(seconds: 3))
              .then((_) => print("  -> FavoriteProductProvider done"))
              .catchError((e) => print("  -> FavoriteProductProvider error: $e")),
          Provider.of<AddressProvider>(context, listen: false)
              .loadData()
              .timeout(const Duration(seconds: 3))
              .then((_) => print("  -> AddressProvider done"))
              .catchError((e) => print("  -> AddressProvider error: $e")),
        ]
      ]).timeout(const Duration(seconds: 4));
      print("appLoadMainData: Future.wait END");
    } catch (err) {
      print("appLoadMainData ERROR: $err");
    }
  }
}

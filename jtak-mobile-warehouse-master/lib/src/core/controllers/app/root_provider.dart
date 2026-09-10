import 'package:app_jtak_warehouse/src/core/controllers/initial_data_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/products_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/transactions_provider.dart';
import 'package:flutter/material.dart';
import 'package:app_jtak_warehouse/src/core/controllers/app_parameters_provider.dart';
import 'package:app_jtak_warehouse/src/core/services/authentication_service.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:provider/provider.dart';

import 'app_state_manager.dart';

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
        ChangeNotifierProvider(create: (ctx) => InitialDataProvider()),
        ChangeNotifierProvider(create: (ctx) => locator<ProductsProvider>()),
        ChangeNotifierProvider(create: (ctx) => locator<OrderProvider>()),
        ChangeNotifierProvider(create: (ctx) => TransactionsProvider()),
      ],
      child: child,
    );
  }
}

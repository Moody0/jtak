import 'dart:developer';

import 'package:app_jtak_warehouse/src/core/models/order_model.dart';
import 'package:app_jtak_warehouse/src/core/models/product_model.dart';
import 'package:app_jtak_warehouse/src/ui/pages/account/phone_code_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/catalog/product_detials_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/catalog/product_edit_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/order/order_details_page.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../src/utils/custom_widgets/image_slider_page.dart';
import '../../../src/utils/custom_widgets/image_view_page.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Getting arguments passed in while calling Navigator.pushNamed
    final args = settings.arguments;
    log('settings.name:${settings.name}');
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const MyApp());

      case PhoneCodePage.routeName:
        if (args is String && GlobalVar.checkString(args)) return CupertinoPageRoute(builder: (context) => PhoneCodePage(args));
        return _errorRoute();

      ////////////////{ catalog routes } ////////////////
      case ProductDetailsPage.routeName:
        return CupertinoPageRoute(builder: (context) => ProductDetailsPage(args as ProductModel));

      case ProductEditPage.routeName:
        if (args is Map) {
          return CupertinoPageRoute(
            builder: (context) => ProductEditPage(
              product: args['product'] as ProductModel?,
              initialCategoryId: args['initialCategoryId'] as int?,
            ),
          );
        }
        return CupertinoPageRoute(builder: (context) => ProductEditPage(product: args as ProductModel?));

      ////////////////{ order routes } ////////////////
      case OrderDetailsPage.routeName:
        return CupertinoPageRoute(builder: (context) => OrderDetailsPage(args as OrderModel));

      ////////////////{ image Route } ////////////////
      case ImageViewPage.routeName:
        return MaterialPageRoute(builder: (_) => ImageViewPage(image: args));

      case ImageSliderPage.routeName:
        if (args is List) return MaterialPageRoute(builder: (_) => ImageSliderPage(args[0], cuurentActiveItem: args[1]));
        return _errorRoute();

      default:
        // If there is no such named route in the switch statement, e.g. /third
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(appBar: AppBar(title: const Text('Error!')), body: const Center(child: Text('Route Page Error')));
    });
  }
}

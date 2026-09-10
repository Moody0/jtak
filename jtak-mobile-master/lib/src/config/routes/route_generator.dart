import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jtek_app/src/core/models/catalog/product_model.dart';
import 'package:jtek_app/src/ui/pages/account/phone_code_page.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';
import '../../core/data/mock_catalog_data.dart';
import '../../core/models/catalog/product_review_model.dart';
import '../../core/models/order/order_model.dart';
import '../../ui/pages/address/add_address_page.dart';
import '../../ui/pages/address/address_page.dart';
import '../../ui/pages/catalog/favorite_page.dart';
import '../../ui/pages/catalog/market_page.dart';
import '../../ui/pages/catalog/product_detials_page.dart';
import '../../ui/pages/catalog/product_reviews_page.dart';
import '../../ui/pages/catalog/restaurant_menu_page.dart';
import '../../ui/pages/catalog/restaurant_reviews_page.dart';
import '../../ui/pages/catalog/restaurants_list_page.dart';
import '../../ui/pages/catalog/search_page.dart';
import '../../ui/pages/catalog/single_product_review_page.dart';
import '../../ui/pages/orders/order_details_page.dart';

import '../../../main.dart';
import '../../../src/utils/custom_widgets/image_slider_page.dart';
import '../../../src/utils/custom_widgets/image_view_page.dart';

class RouteGenerator {
  static Route<Object> generateRoute(RouteSettings settings) {
    // Getting arguments passed in while calling Navigator.pushNamed
    final args = settings.arguments;
    log('settings.name:${settings.name}');
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const MyApp(), settings: settings);

      ////////////////{ catalog routes } ////////////////
      case SearchPage.routeName:
        return CupertinoPageRoute(builder: (context) => SearchPage(initialQuery: args as String?));

      case RestaurantsListPage.routeName:
        return CupertinoPageRoute(builder: (context) => const RestaurantsListPage());

      case RestaurantMenuPage.routeName:
        return CupertinoPageRoute(builder: (context) => const RestaurantMenuPage());

      case MarketPage.routeName:
        return CupertinoPageRoute(builder: (context) => const MarketPage());

      case RestaurantReviewsPage.routeName:
        return CupertinoPageRoute(
          builder: (context) => RestaurantReviewsPage(
            restaurantData: args as MockRestaurantData,
          ),
        );

      case ProductDetailsPage.routeName:
        return CupertinoPageRoute(builder: (context) => ProductDetailsPage(args as ProductModel));

      case FavoritePage.routeName:
        return CupertinoPageRoute(builder: (context) => FavoritePage());

      case ProductReviewsPage.routeName:
        return CupertinoPageRoute(builder: (context) => ProductReviewsPage());

      case SingleProductReviewPage.routeName:
        return CupertinoPageRoute(builder: (context) => SingleProductReviewPage(args as ProductReviewModel));

      ////////////////{ order routes } ////////////////
      case OrderDetailsPage.routeName:
        return CupertinoPageRoute(builder: (context) => OrderDetailsPage(args as OrderModel));

      ////////////////{ Address Routes } ////////////////
      case AddressPage.routeName:
        return CupertinoPageRoute(builder: (context) => AddressPage());
      case AddAddressPage.routeName:
        return CupertinoPageRoute(builder: (context) => const AddAddressPage());

      case PhoneCodePage.routeName:
        if (args is String && GlobalVar.checkString(args)) return CupertinoPageRoute(builder: (context) => PhoneCodePage(args));
        return _errorRoute();

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

  static Route<Object> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(appBar: AppBar(title: const Text('Error!')), body: const Center(child: Text('Route Page Error')));
    });
  }
}

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jtek_app/src/core/controllers/app/base_provider.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/enums/viewstate.dart';
import 'package:jtek_app/src/core/models/catalog/category_model.dart';
import 'package:jtek_app/src/core/models/catalog/product_model.dart';
import 'package:jtek_app/src/core/controllers/catalog/markets_provider.dart';
import 'package:jtek_app/src/core/data/mock_catalog_data.dart';
import 'package:jtek_app/src/core/models/user/address_model.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/utils/providers/sol_api.dart';

class CategoryProductsProvider extends BaseProvider<ShopModel> {
  final SolApi _api = locator<SolApi>();
  static const gridColumnValue = 3;
  static const double headerCategoryHieght = 45;

  bool productScrollControllerAnimate = false;
  ScrollController productScrollController = ScrollController();
  ScrollController headerScrollController = ScrollController();
  CategoryModel category;
  int selectedCategoryIndex = 0;
  late Timer timer;

  CategoryProductsProvider(this.category) {
    setCategory();
    log('@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ category Provider : ${category.title}');
    timer = Timer.periodic(
      const Duration(minutes: 30),
      (timer) => setCategory(),
    );
  }

  Future setCategory() async {
    try {
      setState(ViewState.busy);
      dataList.clear();
      LatLng? latLng = getLatLng();
      Map body = {
        "productCategoryId": category.id,
        "lng": latLng?.longitude,
        "lat": latLng?.latitude,
      };
      List res = await _api.postRequest('/Products/SearchGrouped', body);
      for (var element in res) {
        CategoryModel category = CategoryModel(parentId: this.category.id, parent: this.category.title, title: element['category']);
        List<ProductModel> products = [];
        for (var product in element['products']) {
          products.add(ProductModel.fromMap(product));
        }
        dataList.add(ShopModel(category: category, products: products));
      }

      await loadMerchants();
      setState(ViewState.idle);
    } catch (error) {
      debugPrint('CategoryProductsProvider setCategory error: $error');
      setState(ViewState.idle);
    }
  }

  /// Merchants that genuinely carry something in this category, as reported
  /// by the backend.
  ///
  /// This used to be decided in the app by comparing the category title
  /// against merchant names, cuisines and a list of hardcoded restaurants. Any
  /// category that matched none of them fell through to returning every
  /// merchant, which is why a cleaning-products category listed restaurants.
  List<MockRestaurantData> matchedMerchants = [];

  Future<void> loadMerchants() async {
    final categoryId = category.id;
    if (categoryId == null) {
      matchedMerchants = [];
      notifyListeners();
      return;
    }

    try {
      final latLng = getLatLng();
      final query = latLng == null
          ? ''
          : '?lat=${latLng.latitude}&lng=${latLng.longitude}';
      final res =
          await _api.getRequest('/Products/MerchantsByCategory/$categoryId$query');

      final merchants = <MockRestaurantData>[];
      if (res is List) {
        for (final item in res) {
          final map = Map<String, dynamic>.from(item as Map);
          final kind = (map['merchantKind'] as num?)?.toInt() ?? 0;
          merchants.add(
            kind == 0
                ? RestaurantStoreModel.fromJson(map).toRestaurantData()
                : MarketStoreModel.fromJson(map).toRestaurantData(),
          );
        }
      }
      matchedMerchants = merchants;
    } catch (error) {
      // An empty list is the honest answer here. Falling back to every
      // merchant is exactly the behaviour this replaced.
      debugPrint('CategoryProductsProvider loadMerchants error: $error');
      matchedMerchants = [];
    }
    notifyListeners();
  }

  void setSelectedCategoryIndex(int index) {
    selectedCategoryIndex = index;
    notifyListeners();
  }

  @override
  void dispose() {
    log('@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ dispose category Provider : ${category.title}');
    productScrollController.dispose();
    headerScrollController.dispose();
    timer.cancel();
    super.dispose();
  }

  LatLng? getLatLng() {
    AddressModel mainAddress = locator<AppParametersProvider>().mainAddressService.mainAddress;
    return LatLng(mainAddress.lat!, mainAddress.lng!);
  }
}

////////////////{ ShopModel  file} ////////////////
class ShopModel {
  final GlobalKey catKey = GlobalKey();
  final GlobalKey itemKey = GlobalKey();
  final CategoryModel category;
  final List<ProductModel> products;
  double position = 0;

  ShopModel({required this.category, required this.products});
}

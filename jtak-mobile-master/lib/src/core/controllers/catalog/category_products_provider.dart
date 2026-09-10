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

      setState(ViewState.idle);
    } catch (error) {
      debugPrint('CategoryProductsProvider setCategory error: $error');
      setState(ViewState.idle);
    }
  }

  List<MockRestaurantData> get matchedMerchants {
    List<MockRestaurantData> allMerchants = [];
    if (locator.isRegistered<MarketsProvider>()) {
      final prov = locator<MarketsProvider>();
      final rList = prov.restaurants.isNotEmpty
          ? prov.restaurants
          : MarketsProvider.defaultLiveSeededRestaurants;
      final mList = prov.markets.isNotEmpty
          ? prov.markets
          : MarketsProvider.defaultLiveSeededMarkets;

      allMerchants.addAll(rList.map((r) => r.toRestaurantData()));
      allMerchants.addAll(mList.map((m) => m.toRestaurantData()));
    } else {
      allMerchants.addAll(MockCatalogData.restaurants);
    }

    final catTitle = (category.title ?? '').trim().toLowerCase();
    if (catTitle.isEmpty || catTitle == 'الأقسام' || catTitle == 'الكل') {
      return allMerchants;
    }

    // 1. Markets / Supermarkets filter
    if (catTitle.contains('ماركت') ||
        catTitle.contains('سوبرماركت') ||
        catTitle.contains('بقالة') ||
        catTitle.contains('market')) {
      final markets = allMerchants.where((m) => m.isMarket).toList();
      return markets.isNotEmpty ? markets : allMerchants;
    }

    // 2. Filter by category keyword match on restaurants / markets
    final matches = allMerchants.where((m) {
      if (m.cuisine.toLowerCase().contains(catTitle) ||
          m.categoryTag.toLowerCase().contains(catTitle) ||
          m.name.toLowerCase().contains(catTitle)) {
        return true;
      }
      return m.categories.any((c) =>
          c.toLowerCase().contains(catTitle) || catTitle.contains(c.toLowerCase()));
    }).toList();

    if (matches.isNotEmpty) {
      return matches;
    }

    // 3. Category specific keywords matching
    if (catTitle.contains('فطور') || catTitle.contains('breakfast')) {
      return allMerchants.where((m) =>
          m.name.contains('فلافل') ||
          m.name.contains('بوز الجدي') ||
          m.name.contains('فول') ||
          m.categoryTag.contains('فطور') ||
          m.isMarket).toList();
    }
    if (catTitle.contains('حلويات') || catTitle.contains('كيك') || catTitle.contains('sweet')) {
      return allMerchants.where((m) =>
          m.name.contains('بكداش') ||
          m.name.contains('داوود') ||
          m.name.contains('مهنا') ||
          m.cuisine.contains('حلويات') ||
          m.categoryTag.contains('حلويات')).toList();
    }
    if (catTitle.contains('قهوة') || catTitle.contains('مشروبات') || catTitle.contains('cafe')) {
      return allMerchants.where((m) =>
          m.name.contains('النوفرة') ||
          m.name.contains('نوفرة') ||
          m.name.contains('أرت') ||
          m.cuisine.contains('مشروبات') ||
          m.cuisine.contains('كافيه') ||
          m.categoryTag.contains('كافيه')).toList();
    }
    if (catTitle.contains('برغر') || catTitle.contains('burger')) {
      return allMerchants.where((m) =>
          m.name.contains('برغر') || m.cuisine.contains('برغر') || m.categoryTag.contains('برجر') || m.categoryTag.contains('البرجر')).toList();
    }
    if (catTitle.contains('شاورما') || catTitle.contains('shawarma')) {
      return allMerchants.where((m) =>
          m.name.contains('شاورما') || m.name.contains('أنس') || m.cuisine.contains('شاورما')).toList();
    }
    if (catTitle.contains('مشاوي') || catTitle.contains('grill')) {
      return allMerchants.where((m) =>
          m.name.contains('مشاوي') || m.name.contains('بوابة دمشق') || m.cuisine.contains('مشاوي') || m.categoryTag.contains('مشاوي')).toList();
    }

    return allMerchants;
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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/mock_catalog_data.dart';
import '../../models/catalog/favorite_products_model.dart';
import '../../models/catalog/product_model.dart';
import '../../services/authentication_service.dart';
import '../../services/locator.dart';
import '../../../utils/providers/sol_api.dart';
import '../../../utils/utilities/global_var.dart';
import '../../../ui/pages/catalog/market_page.dart';
import '../../../ui/widgets/catalog/meal_card_widget.dart';
import '../../../ui/widgets/catalog/restaurant_card_widget.dart';
import '../app/base_provider.dart';
import 'markets_provider.dart';

/// ---------------------------------------------------------------------------
/// JTAK Unified Favorites Provider (Restaurants & Dishes)
///
/// Features:
/// - Supports both Guest (unauthenticated) and Logged-In users seamlessly
/// - Instant in-memory toggle with persistent SharedPreferences storage
/// - Automatic migration: Guest favorites are preserved & merged upon login
/// - Restaurant & Store favorites + Meal & Dish favorites
/// - Full item metadata caching so non-mock / backend / market products are
///   never dropped from the Favorites screen
/// - Live backend API synchronization when authenticated
/// ---------------------------------------------------------------------------

class FavoriteProductProvider extends BaseProvider<FavoriteProductModel> {
  final SolApi _api = locator<SolApi>();

  final Set<int> _favoriteRestaurantIds = {};
  final Set<int> _favoriteMealIds = {};

  final Map<int, MockRestaurantData> _cachedFavoriteRestaurants = {};
  final Map<int, MockMenuItemData> _cachedFavoriteMeals = {};

  FavoriteProductProvider() {
    _loadFavoritesFromPrefs();
  }

  Set<int> get favoriteRestaurantIds => _favoriteRestaurantIds;
  Set<int> get favoriteMealIds => _favoriteMealIds;

  List<MockRestaurantData> get favoriteRestaurants {
    final List<MockRestaurantData> list = [];
    for (final restId in _favoriteRestaurantIds) {
      final rest = _resolveRestaurantById(restId);
      if (rest != null) {
        list.add(rest);
      }
    }
    return list;
  }

  List<MockMenuItemData> get favoriteMeals {
    final List<MockMenuItemData> list = [];
    for (final mealId in _favoriteMealIds) {
      final meal = _resolveMealById(mealId);
      if (meal != null) {
        list.add(meal);
      }
    }
    return list;
  }

  int get totalFavoritesCount =>
      favoriteRestaurants.length + favoriteMeals.length;

  bool isRestaurantFavorite(int restaurantId) =>
      _favoriteRestaurantIds.contains(restaurantId);

  bool isMealFavorite(int mealId) => _favoriteMealIds.contains(mealId);

  void toggleRestaurantFavorite(int restaurantId, [dynamic restaurant]) {
    if (_favoriteRestaurantIds.contains(restaurantId)) {
      _favoriteRestaurantIds.remove(restaurantId);
      _cachedFavoriteRestaurants.remove(restaurantId);
      notifyListeners();
      _saveFavoritesToPrefs();
    } else {
      _favoriteRestaurantIds.add(restaurantId);
      final converted = convertToMockRestaurantData(restaurant);
      if (converted != null) {
        _cachedFavoriteRestaurants[restaurantId] = converted;
      } else {
        _resolveRestaurantById(restaurantId);
      }
      notifyListeners();
      _saveFavoritesToPrefs();
    }
  }

  void toggleMealFavorite(int mealId, [dynamic item]) {
    if (_favoriteMealIds.contains(mealId)) {
      _favoriteMealIds.remove(mealId);
      _cachedFavoriteMeals.remove(mealId);
      dataList.removeWhere((element) => element.productId == mealId);
      notifyListeners();
      _saveFavoritesToPrefs();

      if (locator<AuthenticationService>().isLogin()) {
        _api.deleteRequest('/FavoriteProducts/$mealId').catchError((e) {
          debugPrint('Error deleting server favorite: $e');
        });
      }
    } else {
      _favoriteMealIds.add(mealId);
      final converted = convertToMockMenuItemData(item);
      if (converted != null) {
        _cachedFavoriteMeals[mealId] = converted;
      } else {
        _resolveMealById(mealId);
      }
      notifyListeners();
      _saveFavoritesToPrefs();

      if (locator<AuthenticationService>().isLogin()) {
        _api.postRequest('/FavoriteProducts/$mealId', {}).catchError((e) {
          debugPrint('Error adding server favorite: $e');
        });
      }
    }
  }

  Future loadData() async {
    await _loadFavoritesFromPrefs();
    if (locator<AuthenticationService>().isLogin()) {
      try {
        final List data = await _api.getRequest('/FavoriteProducts/Mine');
        dataList = data.map((e) => FavoriteProductModel.fromMap(e)).toList();
        bool hasChanges = false;
        for (final fav in dataList) {
          final pid = fav.productId;
          if (pid != null && pid > 0) {
            if (!_favoriteMealIds.contains(pid)) {
              _favoriteMealIds.add(pid);
              hasChanges = true;
            }
            if (!_cachedFavoriteMeals.containsKey(pid)) {
              final img = fav.productImage ?? '';
              _cachedFavoriteMeals[pid] = MockMenuItemData(
                id: pid,
                restaurantId: 0,
                restaurantName: 'جيتك',
                category: 'المفضلة',
                title: fav.productTitle ?? 'وجبة #$pid',
                description: fav.productTitle ?? '',
                price: '',
                basePriceValue: 0,
                imageUrl: (img.isNotEmpty && img != 'null')
                    ? (img.startsWith('http')
                        ? img
                        : GlobalVar.getImageUrl(img))
                    : '',
              );
              hasChanges = true;
            }
          }
        }
        if (hasChanges) {
          await _saveFavoritesToPrefs();
        }
      } catch (e) {
        debugPrint('Failed to load server favorites: $e');
      }
    }
    notifyListeners();
  }

  Future add(ProductModel product) async {
    if (product.id != null) {
      toggleMealFavorite(product.id!, product);
    }
  }

  Future delete(int productId) async {
    if (_favoriteMealIds.contains(productId)) {
      toggleMealFavorite(productId);
    } else if (_favoriteRestaurantIds.contains(productId)) {
      toggleRestaurantFavorite(productId);
    }
  }

  bool find(int productId) {
    return _favoriteMealIds.contains(productId) ||
        _favoriteRestaurantIds.contains(productId);
  }

  MockMenuItemData? _resolveMealById(int mealId) {
    // 1. Check in-memory item cache
    if (_cachedFavoriteMeals.containsKey(mealId)) {
      return _cachedFavoriteMeals[mealId]!;
    }

    // 2. Check MockCatalogData (which searches restaurants and market items)
    final mockItem = MockCatalogData.getMenuItemById(mealId);
    if (mockItem != null) {
      _cachedFavoriteMeals[mealId] = mockItem;
      return mockItem;
    }

    // 3. Check MarketsProvider
    if (locator.isRegistered<MarketsProvider>()) {
      try {
        final provItem = locator<MarketsProvider>().findMenuItemById(mealId);
        if (provItem != null) {
          _cachedFavoriteMeals[mealId] = provItem;
          return provItem;
        }
      } catch (_) {}
    }

    // 4. Check dataList from server (/FavoriteProducts/Mine)
    for (final fav in dataList) {
      if (fav.productId == mealId) {
        final img = fav.productImage ?? '';
        final resolved = MockMenuItemData(
          id: fav.productId!,
          restaurantId: 0,
          restaurantName: 'جيتك',
          category: 'المفضلة',
          title: fav.productTitle ?? 'وجبة #$mealId',
          description: fav.productTitle ?? '',
          price: '',
          basePriceValue: 0,
          imageUrl: (img.isNotEmpty && img != 'null')
              ? (img.startsWith('http')
                  ? img
                  : GlobalVar.getImageUrl(img))
              : '',
        );
        _cachedFavoriteMeals[mealId] = resolved;
        return resolved;
      }
    }

    // 5. Fallback placeholder - NEVER drop a favorited item
    final fallback = MockMenuItemData(
      id: mealId,
      restaurantId: 0,
      restaurantName: 'جيتك',
      category: 'المفضلة',
      title: 'وجبة #$mealId',
      description: '',
      price: '',
      basePriceValue: 0,
      imageUrl: '',
    );
    _cachedFavoriteMeals[mealId] = fallback;
    return fallback;
  }

  MockRestaurantData? _resolveRestaurantById(int restaurantId) {
    // 1. Check in-memory cache
    if (_cachedFavoriteRestaurants.containsKey(restaurantId)) {
      return _cachedFavoriteRestaurants[restaurantId]!;
    }

    // 2. Check MockCatalogData
    try {
      final mock = MockCatalogData.restaurants
          .where((r) => r.id == restaurantId)
          .firstOrNull;
      if (mock != null) {
        _cachedFavoriteRestaurants[restaurantId] = mock;
        return mock;
      }
    } catch (_) {}

    // 3. Check MarketsProvider
    if (locator.isRegistered<MarketsProvider>()) {
      try {
        final provRest =
            locator<MarketsProvider>().findRestaurantById(restaurantId);
        if (provRest != null) {
          _cachedFavoriteRestaurants[restaurantId] = provRest;
          return provRest;
        }
      } catch (_) {}
    }

    // 4. Fallback placeholder
    final fallback = MockRestaurantData(
      id: restaurantId,
      name: 'مطعم #$restaurantId',
      cuisine: 'مطاعم',
      categoryTag: 'مطاعم',
      rating: 4.8,
      ratingCount: 100,
      eta: '25-35 دقيقة',
      distance: '2.5 كم',
      deliveryFee: '5,000 ل.س',
      coverUrl: '',
      logoUrl: '',
      categories: const ['الكل'],
      menuItems: const [],
    );
    _cachedFavoriteRestaurants[restaurantId] = fallback;
    return fallback;
  }

  static MockMenuItemData? convertToMockMenuItemData(dynamic obj) {
    if (obj == null) return null;
    if (obj is MockMenuItemData) return obj;
    if (obj is MealItemData) {
      final numPrice = obj.numericPrice > 0
          ? obj.numericPrice.toInt()
          : (int.tryParse(obj.price.replaceAll(RegExp(r'[^\d]'), '')) ?? 0);
      return MockMenuItemData(
        id: obj.id,
        restaurantId: obj.merchantId,
        restaurantName:
            obj.merchantName.isNotEmpty ? obj.merchantName : 'جيتك',
        title: obj.title,
        description: obj.title,
        price: obj.price,
        basePriceValue: numPrice,
        imageUrl: obj.coverUrl,
        category: 'وجبات',
        eta: obj.eta,
        distance: obj.distance,
      );
    }
    if (obj is MarketProductItem) {
      return obj.toMockMenuItemData(12, 'جيتك ماركت');
    }
    if (obj is ProductModel) {
      final priceVal = obj.finalPrice ?? obj.price ?? 0;
      final img = (obj.photos != null && obj.photos!.isNotEmpty)
          ? obj.photos!.first
          : '';
      return MockMenuItemData(
        id: obj.id ?? 0,
        restaurantId: obj.merchantId ?? 0,
        restaurantName: obj.merchant ?? 'المتجر',
        title: obj.title ?? '',
        description: obj.description ?? obj.title ?? '',
        price: '$priceVal ل.س',
        basePriceValue: priceVal.toInt(),
        imageUrl: img.isNotEmpty
            ? (img.startsWith('http') ? img : GlobalVar.getImageUrl(img))
            : '',
        category: obj.category ?? 'منتجات',
      );
    }
    if (obj is Map) {
      try {
        return MockMenuItemData.fromMap(Map<String, dynamic>.from(obj));
      } catch (_) {}
    }
    return null;
  }

  static MockRestaurantData? convertToMockRestaurantData(dynamic obj) {
    if (obj == null) return null;
    if (obj is MockRestaurantData) return obj;
    if (obj is RestaurantItemData) {
      return MockRestaurantData(
        id: obj.id,
        name: obj.name,
        cuisine: obj.category,
        categoryTag: obj.category,
        rating: obj.rating,
        ratingCount: obj.ratingCount,
        eta: obj.eta,
        distance: obj.distance,
        deliveryFee: obj.deliveryFee,
        coverUrl: obj.coverUrl,
        logoUrl: obj.logoUrl,
        categories: const ['الكل'],
        menuItems: const [],
      );
    }
    if (obj is RestaurantStoreModel) {
      return obj.toRestaurantData();
    }
    if (obj is MarketStoreModel) {
      return obj.toRestaurantData();
    }
    if (obj is Map) {
      try {
        return MockRestaurantData.fromMap(Map<String, dynamic>.from(obj));
      } catch (_) {}
    }
    return null;
  }

  static String _getUserFavKey(String suffix) {
    final user = locator<AuthenticationService>().user;
    final phone = user?.phoneNumber ?? user?.id ?? 'guest';
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return 'jtak_fav_${suffix}_${cleanPhone.isNotEmpty ? cleanPhone : "guest"}';
  }

  Future resetData() async {
    _favoriteRestaurantIds.clear();
    _favoriteMealIds.clear();
    _cachedFavoriteRestaurants.clear();
    _cachedFavoriteMeals.clear();
    dataList.clear();
    notifyListeners();
  }

  Future _saveFavoritesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final restIdsKey = _getUserFavKey('restaurants');
      final mealIdsKey = _getUserFavKey('meals');
      final restDataKey = _getUserFavKey('restaurants_data');
      final mealDataKey = _getUserFavKey('meals_data');

      await prefs.setString(
        restIdsKey,
        jsonEncode(_favoriteRestaurantIds.toList()),
      );
      await prefs.setString(
        mealIdsKey,
        jsonEncode(_favoriteMealIds.toList()),
      );

      final Map<String, dynamic> mealsMap = {};
      _cachedFavoriteMeals.forEach((k, v) {
        mealsMap[k.toString()] = v.toMap();
      });
      await prefs.setString(mealDataKey, jsonEncode(mealsMap));

      final Map<String, dynamic> restMap = {};
      _cachedFavoriteRestaurants.forEach((k, v) {
        restMap[k.toString()] = v.toMap();
      });
      await prefs.setString(restDataKey, jsonEncode(restMap));

      // Maintain guest copy if not logged in
      if (!locator<AuthenticationService>().isLogin()) {
        await prefs.setString(
          'jtak_fav_restaurants_guest',
          jsonEncode(_favoriteRestaurantIds.toList()),
        );
        await prefs.setString(
          'jtak_fav_meals_guest',
          jsonEncode(_favoriteMealIds.toList()),
        );
        await prefs.setString(
          'jtak_fav_meals_data_guest',
          jsonEncode(mealsMap),
        );
        await prefs.setString(
          'jtak_fav_restaurants_data_guest',
          jsonEncode(restMap),
        );
      }
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  Future _loadFavoritesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final restIdsKey = _getUserFavKey('restaurants');
      final mealIdsKey = _getUserFavKey('meals');
      final restDataKey = _getUserFavKey('restaurants_data');
      final mealDataKey = _getUserFavKey('meals_data');

      // 1. Load restaurant favorites
      if (prefs.containsKey(restIdsKey)) {
        final List list = jsonDecode(prefs.getString(restIdsKey) ?? '[]');
        _favoriteRestaurantIds.clear();
        _favoriteRestaurantIds.addAll(list.map((e) => (e as num).toInt()));
      } else if (prefs.containsKey('jtak_fav_restaurants_guest')) {
        final List list =
            jsonDecode(prefs.getString('jtak_fav_restaurants_guest') ?? '[]');
        _favoriteRestaurantIds.addAll(list.map((e) => (e as num).toInt()));
      }

      // 2. Load meal favorites
      if (prefs.containsKey(mealIdsKey)) {
        final List list = jsonDecode(prefs.getString(mealIdsKey) ?? '[]');
        _favoriteMealIds.clear();
        _favoriteMealIds.addAll(list.map((e) => (e as num).toInt()));
      } else if (prefs.containsKey('jtak_fav_meals_guest')) {
        final List list =
            jsonDecode(prefs.getString('jtak_fav_meals_guest') ?? '[]');
        _favoriteMealIds.addAll(list.map((e) => (e as num).toInt()));
      }

      // 3. Load meal details cache
      String? mealsDataStr = prefs.getString(mealDataKey);
      if (mealsDataStr == null || mealsDataStr.isEmpty) {
        mealsDataStr = prefs.getString('jtak_fav_meals_data_guest');
      }
      if (mealsDataStr != null && mealsDataStr.isNotEmpty) {
        try {
          final Map decoded = jsonDecode(mealsDataStr);
          decoded.forEach((k, v) {
            final id = int.tryParse(k.toString());
            if (id != null && v is Map) {
              _cachedFavoriteMeals[id] =
                  MockMenuItemData.fromMap(Map<String, dynamic>.from(v));
            }
          });
        } catch (_) {}
      }

      // 4. Load restaurant details cache
      String? restDataStr = prefs.getString(restDataKey);
      if (restDataStr == null || restDataStr.isEmpty) {
        restDataStr = prefs.getString('jtak_fav_restaurants_data_guest');
      }
      if (restDataStr != null && restDataStr.isNotEmpty) {
        try {
          final Map decoded = jsonDecode(restDataStr);
          decoded.forEach((k, v) {
            final id = int.tryParse(k.toString());
            if (id != null && v is Map) {
              _cachedFavoriteRestaurants[id] =
                  MockRestaurantData.fromMap(Map<String, dynamic>.from(v));
            }
          });
        } catch (_) {}
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }
}

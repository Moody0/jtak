import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/mock_catalog_data.dart';
import '../../models/catalog/favorite_products_model.dart';
import '../../models/catalog/product_model.dart';
import '../../services/authentication_service.dart';
import '../../services/locator.dart';
import '../../../utils/providers/sol_api.dart';
import '../app/base_provider.dart';

/// ---------------------------------------------------------------------------
/// JTAK Unified Favorites Provider (Restaurants & Dishes)
///
/// Features:
/// - Supports both Guest (unauthenticated) and Logged-In users seamlessly
/// - Instant in-memory toggle with persistent SharedPreferences storage
/// - Automatic migration: Guest favorites are preserved & merged upon login
/// - Restaurant & Store favorites + Meal & Dish favorites
/// ---------------------------------------------------------------------------

class FavoriteProductProvider extends BaseProvider<FavoriteProductModel> {
  final SolApi _api = locator<SolApi>();

  final Set<int> _favoriteRestaurantIds = {};
  final Set<int> _favoriteMealIds = {};

  FavoriteProductProvider() {
    _loadFavoritesFromPrefs();
  }

  Set<int> get favoriteRestaurantIds => _favoriteRestaurantIds;
  Set<int> get favoriteMealIds => _favoriteMealIds;

  List<MockRestaurantData> get favoriteRestaurants {
    return MockCatalogData.restaurants
        .where((r) => _favoriteRestaurantIds.contains(r.id))
        .toList();
  }

  List<MockMenuItemData> get favoriteMeals {
    final List<MockMenuItemData> list = [];
    for (final mealId in _favoriteMealIds) {
      final mockItem = MockCatalogData.getMenuItemById(mealId);
      if (mockItem != null) {
        list.add(mockItem);
      }
    }
    return list;
  }

  int get totalFavoritesCount => favoriteRestaurants.length + favoriteMeals.length;

  bool isRestaurantFavorite(int restaurantId) =>
      _favoriteRestaurantIds.contains(restaurantId);

  bool isMealFavorite(int mealId) => _favoriteMealIds.contains(mealId);

  void toggleRestaurantFavorite(int restaurantId) {
    if (_favoriteRestaurantIds.contains(restaurantId)) {
      _favoriteRestaurantIds.remove(restaurantId);
    } else {
      _favoriteRestaurantIds.add(restaurantId);
    }
    notifyListeners();
    _saveFavoritesToPrefs();
  }

  void toggleMealFavorite(int mealId) {
    if (_favoriteMealIds.contains(mealId)) {
      _favoriteMealIds.remove(mealId);
    } else {
      _favoriteMealIds.add(mealId);
    }
    notifyListeners();
    _saveFavoritesToPrefs();
  }

  Future loadData() async {
    await _loadFavoritesFromPrefs();
    if (locator<AuthenticationService>().isLogin()) {
      try {
        List data = await _api.getRequest('/FavoriteProducts/Mine');
        dataList = data.map((e) => FavoriteProductModel.fromMap(e)).toList();
      } catch (e) {
        debugPrint('Failed to load server favorites: $e');
      }
    }
    notifyListeners();
  }

  Future add(ProductModel product) async {
    if (product.id != null) {
      _favoriteMealIds.add(product.id!);
      notifyListeners();
      _saveFavoritesToPrefs();
    }
    if (locator<AuthenticationService>().isLogin() && product.id != null) {
      try {
        await _api.postRequest('/FavoriteProducts/${product.id}', {});
      } catch (_) {}
    }
  }

  Future delete(int productId) async {
    _favoriteMealIds.remove(productId);
    _favoriteRestaurantIds.remove(productId);
    dataList.removeWhere((element) => element.productId == productId);
    notifyListeners();
    _saveFavoritesToPrefs();

    if (locator<AuthenticationService>().isLogin()) {
      try {
        await _api.deleteRequest('/FavoriteProducts/$productId');
      } catch (_) {}
    }
  }

  bool find(int productId) {
    return _favoriteMealIds.contains(productId) ||
        _favoriteRestaurantIds.contains(productId);
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
    dataList.clear();
    notifyListeners();
  }

  Future _saveFavoritesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _getUserFavKey('restaurants'),
        jsonEncode(_favoriteRestaurantIds.toList()),
      );
      await prefs.setString(
        _getUserFavKey('meals'),
        jsonEncode(_favoriteMealIds.toList()),
      );
      // Also maintain guest copy if not logged in
      if (!locator<AuthenticationService>().isLogin()) {
        await prefs.setString(
          'jtak_fav_restaurants_guest',
          jsonEncode(_favoriteRestaurantIds.toList()),
        );
        await prefs.setString(
          'jtak_fav_meals_guest',
          jsonEncode(_favoriteMealIds.toList()),
        );
      }
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  Future _loadFavoritesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final restKey = _getUserFavKey('restaurants');
      final mealKey = _getUserFavKey('meals');

      // Load restaurant favorites
      if (prefs.containsKey(restKey)) {
        final List list = jsonDecode(prefs.getString(restKey) ?? '[]');
        _favoriteRestaurantIds.clear();
        _favoriteRestaurantIds.addAll(list.cast<int>());
      } else if (prefs.containsKey('jtak_fav_restaurants_guest')) {
        // Fallback / merge from guest list
        final List list = jsonDecode(prefs.getString('jtak_fav_restaurants_guest') ?? '[]');
        _favoriteRestaurantIds.addAll(list.cast<int>());
        await _saveFavoritesToPrefs();
      }

      // Load meal favorites
      if (prefs.containsKey(mealKey)) {
        final List list = jsonDecode(prefs.getString(mealKey) ?? '[]');
        _favoriteMealIds.clear();
        _favoriteMealIds.addAll(list.cast<int>());
      } else if (prefs.containsKey('jtak_fav_meals_guest')) {
        // Fallback / merge from guest list
        final List list = jsonDecode(prefs.getString('jtak_fav_meals_guest') ?? '[]');
        _favoriteMealIds.addAll(list.cast<int>());
        await _saveFavoritesToPrefs();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }
}

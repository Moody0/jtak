import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/category_model.dart';
import 'package:app_jtak_warehouse/src/core/models/product_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/foundation.dart';

enum ProductStockFilter {
  all,
  inStock,
  outOfStock,
}

class ProductsProvider extends BaseProvider<ProductModel> {
  final SolApi _api = locator<SolApi>();

  String? search;
  int? selectedCategoryId;
  ProductStockFilter stockFilter = ProductStockFilter.all;
  List<CategoryModel> categories = [];
  List<CategoryModel> allCategories = [];
  final ValueNotifier<Map<int, double>> newPricesMap =
      ValueNotifier<Map<int, double>>({});
  final Set<int> _togglingIds = {};

  bool isToggling(int? id) => id != null && _togglingIds.contains(id);

  List<ProductModel> get productList => filteredProducts;

  int get totalProductsCount => dataList.length;
  int get inStockCount => dataList.where((p) => p.productActive).length;
  int get outOfStockCount => dataList.where((p) => !p.productActive).length;

  /// Categories available for selection when creating or editing products.
  /// Only categories already used by this restaurant are shown; the global
  /// catalog contains unrelated categories for other merchant types.
  List<CategoryModel> get categoriesForSelection {
    return categories.where((c) => c.id > 0).toList();
  }

  List<ProductModel> get filteredProducts {
    var list = dataList;

    // 1. Filter by category tab
    if (selectedCategoryId != null) {
      final selectedCat = categories.cast<CategoryModel?>().firstWhere(
            (c) => c?.id == selectedCategoryId,
            orElse: () => null,
          );
      list = list.where((p) {
        if (p.productCategoryId != null &&
            p.productCategoryId == selectedCategoryId) {
          return true;
        }
        if (selectedCat != null &&
            p.productCat1 != null &&
            p.productCat1!.trim().isNotEmpty) {
          return p.productCat1!.trim().toLowerCase() ==
              selectedCat.title.trim().toLowerCase();
        }
        return false;
      }).toList();
    }

    // 2. Filter by stock availability
    if (stockFilter == ProductStockFilter.inStock) {
      list = list.where((p) => p.productActive).toList();
    } else if (stockFilter == ProductStockFilter.outOfStock) {
      list = list.where((p) => !p.productActive).toList();
    }

    // 3. Filter by search query
    if (GlobalVar.checkString(search)) {
      final q = search!.trim().toLowerCase();
      list = list.where((p) {
        final title = (p.product ?? '').toLowerCase();
        final desc = (p.productDescription ?? '').toLowerCase();
        final cat = (p.productCat1 ?? '').toLowerCase();
        return title.contains(q) || desc.contains(q) || cat.contains(q);
      }).toList();
    }

    return list;
  }

  int countForCategory(int? catId) {
    if (catId == null) return dataList.length;
    final cat = categories
        .cast<CategoryModel?>()
        .firstWhere((c) => c?.id == catId, orElse: () => null);
    return dataList.where((p) {
      if (p.productCategoryId == catId) return true;
      if (cat != null &&
          p.productCat1 != null &&
          p.productCat1!.trim().isNotEmpty) {
        return p.productCat1!.trim().toLowerCase() ==
            cat.title.trim().toLowerCase();
      }
      return false;
    }).length;
  }

  void setSelectedCategory(int? catId) {
    if (selectedCategoryId != catId) {
      selectedCategoryId = catId;
      notifyListeners();
    }
  }

  void setStockFilter(ProductStockFilter filter) {
    if (stockFilter != filter) {
      stockFilter = filter;
      notifyListeners();
    }
  }

  void setSearch(String? value) {
    search = value;
    notifyListeners();
  }

  void resetFilters() {
    search = null;
    selectedCategoryId = null;
    stockFilter = ProductStockFilter.all;
    notifyListeners();
  }

  Future loadData({int? productCategoryId}) async {
    await loadBaseData(loadBody: () async {
      // 1. Fetch system categories
      List<CategoryModel> fetchedCategories = [];
      try {
        var catRes = await _api.getRequest('/Products/Categories');
        if (catRes is List) {
          fetchedCategories =
              catRes.map((c) => CategoryModel.fromMap(c)).toList();
        }
      } catch (_) {}
      allCategories = fetchedCategories;

      // 2. Fetch merchant products
      var data = await _api.getRequest('/Products');
      dataList.clear();
      if (data is List) {
        for (var element in data) {
          dataList.add(ProductModel.fromMap(element));
        }
      }

      // 3. Extract ONLY the categories that the restaurant actually has products in
      _refreshRestaurantCategories();
    });
    notifyListeners();
  }

  /// Recomputes the categories that the restaurant actually has based on existing products
  void _refreshRestaurantCategories() {
    final Map<String, CategoryModel> systemCatsByTitle = {
      for (final c in allCategories) c.title.trim().toLowerCase(): c,
    };
    final Map<int, CategoryModel> systemCatsById = {
      for (final c in allCategories) c.id: c,
    };

    final Map<String, CategoryModel> restaurantCatsMap = {};
    int syntheticId = -1000;

    for (final prod in dataList) {
      CategoryModel? matchedCat;

      // 1) Match by productCategoryId against system categories
      if (prod.productCategoryId != null &&
          systemCatsById.containsKey(prod.productCategoryId)) {
        matchedCat = systemCatsById[prod.productCategoryId];
      }

      // 2) Match by productCat1 title against system categories
      final rawTitle = prod.productCat1?.trim();
      if (matchedCat == null && rawTitle != null && rawTitle.isNotEmpty) {
        final titleLower = rawTitle.toLowerCase();
        if (systemCatsByTitle.containsKey(titleLower)) {
          matchedCat = systemCatsByTitle[titleLower];
        }
      }

      // 3) Dynamic category from product's category title (if not general/uncategorized)
      if (matchedCat == null &&
          rawTitle != null &&
          rawTitle.isNotEmpty &&
          rawTitle != 'عام' &&
          rawTitle.toLowerCase() != 'uncategorized') {
        matchedCat = CategoryModel(
          id: prod.productCategoryId ?? syntheticId--,
          title: rawTitle,
          icon: prod.categoryIcon,
          active: true,
        );
      }

      if (matchedCat != null) {
        final normKey = matchedCat.title.trim().toLowerCase();
        if (!restaurantCatsMap.containsKey(normKey)) {
          restaurantCatsMap[normKey] = matchedCat;
        }
      }
    }

    final restaurantCategories = restaurantCatsMap.values.toList();
    restaurantCategories.sort((a, b) {
      if (a.order != b.order) return a.order.compareTo(b.order);
      return a.title.compareTo(b.title);
    });

    categories = restaurantCategories;

    // Reset selected category if it no longer exists
    if (selectedCategoryId != null &&
        !categories.any((c) => c.id == selectedCategoryId)) {
      selectedCategoryId = null;
    }
  }

  /// Instant In-Stock / Out-of-Stock Toggle (Optimistic Update with in-flight guard)
  Future<bool> toggleProductAvailability(ProductModel product) async {
    if (product.productId == null || _togglingIds.contains(product.productId)) {
      return false;
    }
    final id = product.productId!;
    _togglingIds.add(id);

    final originalState = product.productActive;
    product.productActive = !product.productActive;
    notifyListeners();

    try {
      var res = await _api.putRequest(
        '/Products/$id/Availability',
        {'active': product.productActive},
      );
      _togglingIds.remove(id);
      notifyListeners();
      return res != null;
    } catch (err) {
      // Revert on error
      product.productActive = originalState;
      _togglingIds.remove(id);
      notifyListeners();
      rethrow;
    }
  }

  /// Quick in-place price update
  Future<bool> quickUpdatePrice(ProductModel product, double newPrice) async {
    if (product.productId == null || newPrice <= 0) return false;
    final oldFinal = product.finalPrice;
    final oldMerchant = product.merchantPrice;

    product.finalPrice = newPrice;
    product.merchantPrice = newPrice.toInt();
    notifyListeners();

    try {
      final res = await _api.putRequest('/Products/${product.productId}', {
        'title': product.product ?? '',
        'description': product.productDescription ?? '',
        'price': newPrice,
        'unit': product.productUnit ?? 'وجبة',
        'productCategoryId': product.productCategoryId,
        'photos': product.productPhotos,
        'active': product.productActive,
      });
      if (res != null) {
        return true;
      }
    } catch (e) {
      product.finalPrice = oldFinal;
      product.merchantPrice = oldMerchant;
      notifyListeners();
      rethrow;
    }
    return false;
  }

  /// Create new dish / product
  Future<bool> createProduct(Map<String, dynamic> body) async {
    bool success = false;
    await loadBaseData(loadBody: () async {
      var res = await _api.postRequest('/Products', body);
      if (res != null) {
        success = true;
        await loadData();
      }
    });
    return success;
  }

  /// Update dish / product
  Future<bool> updateProduct(int productId, Map<String, dynamic> body) async {
    bool success = false;
    await loadBaseData(loadBody: () async {
      var res = await _api.putRequest('/Products/$productId', body);
      if (res != null) {
        success = true;
        await loadData();
      }
    });
    return success;
  }

  /// Delete dish / product
  Future<bool> deleteProduct(int productId) async {
    bool success = false;
    await loadBaseData(loadBody: () async {
      var res = await _api.deleteRequest('/Products/$productId');
      if (res == true || res != null) {
        dataList.removeWhere((p) => p.productId == productId);
        _refreshRestaurantCategories();
        success = true;
      }
    });
    notifyListeners();
    return success;
  }

  // --- Batch Price Management (Legacy Support) ---
  Future<void> updateProductPrices() async {
    await loadBaseData(
      loadBody: () async {
        List<Map> body = [];
        newPricesMap.value.forEach((key, value) {
          body.add({'productId': key, 'merchantPrice': value});
        });
        await _api.putRequest('/Products/Prices/', body);
        updateNewPrices();
        newPricesMap.value.clear();
      },
    );
  }

  void updateNewPrices() {
    for (var productId in newPricesMap.value.keys) {
      final index =
          dataList.indexWhere((element) => element.productId == productId);
      if (index != -1) {
        dataList[index].finalPrice = newPricesMap.value[productId];
        dataList[index].merchantPrice = newPricesMap.value[productId]?.toInt();
      }
    }
    notifyListeners();
  }

  void setNewPrice(ProductModel product, double newPrice) {
    if (newPrice >= 0 && product.productId != null) {
      newPricesMap.value[product.productId!] = newPrice;
      newPricesMap.notifyListeners();
    }
  }

  void resetPrice(int productId) {
    newPricesMap.value.remove(productId);
    notifyListeners();
  }

  @override
  void dispose() {
    newPricesMap.dispose();
    super.dispose();
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../app/base_provider.dart';
import '../../data/mock_catalog_data.dart';
import '../../services/locator.dart';
import '../../services/authentication_service.dart';
import '../../../ui/widgets/catalog/restaurant_card_widget.dart';
import '../../../utils/utilities/global_var.dart';

class MarketStoreModel {
  final int id;
  final String name;
  final String nameAr;
  final String nameEn;
  final String eta;
  final String? tagline;
  final String? logoUrl;
  final String? assetPath;
  final Color logoColor;
  final String logoText;
  final String? logoBoxedText;
  final double? lat;
  final double? lng;
  final int shippingCoverageInMeters;
  final int minOrderAmount;
  final double deliveryFeeAmount;
  final bool isUsd;
  final int merchantKind;

  const MarketStoreModel({
    required this.id,
    required this.name,
    this.nameAr = '',
    this.nameEn = '',
    required this.eta,
    this.tagline,
    this.logoUrl,
    this.assetPath,
    this.logoColor = const Color(0xFFFF5C00),
    this.logoText = '',
    this.logoBoxedText,
    this.lat,
    this.lng,
    this.shippingCoverageInMeters = 25000,
    this.minOrderAmount = 0,
    this.deliveryFeeAmount = 5000.0,
    this.isUsd = false,
    this.merchantKind = 1,
  });

  static String extractArabicName(String raw) {
    if (raw.isEmpty) return '';
    final parts = raw
        .split(' - ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final ar = parts.firstWhere((p) => RegExp(r'[\u0600-\u06FF]').hasMatch(p),
        orElse: () => '');
    if (ar.isNotEmpty) return ar;
    return raw;
  }

  static String extractEnglishName(String raw) {
    if (raw.isEmpty) return '';
    final parts = raw
        .split(' - ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final en = parts.firstWhere((p) => !RegExp(r'[\u0600-\u06FF]').hasMatch(p),
        orElse: () => '');
    if (en.isNotEmpty) return en;
    return raw;
  }

  static String extractLocalizedName(String raw, String langCode) {
    if (raw.isEmpty) return 'المتجر';
    return langCode == 'ar' ? extractArabicName(raw) : extractEnglishName(raw);
  }

  String localizedName(String langCode) {
    if (langCode == 'ar') return nameAr.isNotEmpty ? nameAr : name;
    return nameEn.isNotEmpty ? nameEn : name;
  }

  factory MarketStoreModel.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString().trim();
    final shortDesc = (json['shortDescription'] ?? '').toString().trim();
    final photo = (json['photo'] ?? '').toString().trim();
    final nameAr = extractArabicName(title);
    final nameEn = extractEnglishName(title);

    // Parse ETA from shortDescription if available (e.g. "توصيل فوري • 15-20 دقيقة")
    String eta = '15-25 دقيقة';
    String? tagline;
    if (shortDesc.contains('•')) {
      final parts = shortDesc.split('•');
      tagline = parts[0].trim();
      eta = parts[1].trim();
    } else if (shortDesc.contains('دقيقة')) {
      eta = shortDesc;
    } else if (shortDesc.isNotEmpty) {
      tagline = shortDesc;
    }

    // Determine logo styling
    Color logoColor = const Color(0xFFFF5C00);
    String logoText = title.split(' ').first;
    String? logoBoxedText = 'ماركت';

    if (title.contains('Best') || title.contains('بست')) {
      logoColor = const Color(0xFF1D4ED8);
      logoText = 'Best';
      logoBoxedText = 'Market';
    } else if (title.contains('Clover') ||
        title.contains('كلوفر') ||
        title.contains('Mall')) {
      logoColor = const Color(0xFF047857);
      logoText = 'Clover';
      logoBoxedText = 'Mall';
    } else if (title.contains('شمسين')) {
      logoColor = const Color(0xFF0F766E);
      logoText = 'شمسين';
      logoBoxedText = 'سوبرماركت';
    } else if (title.contains('قاسيون')) {
      logoColor = const Color(0xFF7C2D12);
      logoText = 'قاسيون';
      logoBoxedText = 'هايبر';
    } else if (title.contains('الهدى')) {
      logoColor = const Color(0xFF1E3A8A);
      logoText = 'الهدى';
      logoBoxedText = 'ماركت';
    } else if (title.contains('البركة')) {
      logoColor = const Color(0xFF047857);
      logoText = 'البركة';
      logoBoxedText = 'سوبرماركت';
    } else if (title.contains('الدوحة')) {
      logoColor = const Color(0xFF4338CA);
      logoText = 'الدوحة';
      logoBoxedText = 'ماركت';
    }

    String? assetPath;
    String? logoUrl;
    if (photo.startsWith('assets/')) {
      assetPath = photo;
    } else if (photo.startsWith('http')) {
      logoUrl = photo;
    } else if (photo.isNotEmpty && photo.toLowerCase() != 'null') {
      logoUrl = GlobalVar.getImageUrl(photo);
    }
    assetPath ??= _resolveAssetByName(title);

    final bool isUsd = (title.toLowerCase().contains('best') ||
        title.contains('بست') ||
        title.toLowerCase().contains('clover') ||
        title.contains('كلوفر'));

    int minOrder = 0;
    if (json['minimumOrder'] != null) {
      minOrder = (json['minimumOrder'] as num).toInt();
    } else if (json['minOrderAmount'] != null) {
      minOrder = (json['minOrderAmount'] as num).toInt();
    }

    double deliveryFee = 5000.0;
    if (json['shippingCost'] != null) {
      deliveryFee = (json['shippingCost'] as num).toDouble();
    } else if (json['deliveryFee'] != null) {
      deliveryFee = (json['deliveryFee'] as num).toDouble();
    }

    return MarketStoreModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      name: title,
      nameAr: nameAr,
      nameEn: nameEn,
      eta: eta,
      tagline: tagline,
      logoUrl: logoUrl,
      assetPath: assetPath,
      logoColor: logoColor,
      logoText: logoText,
      logoBoxedText: logoBoxedText,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      shippingCoverageInMeters: json['shippingCoverageInMeters'] is int
          ? json['shippingCoverageInMeters']
          : int.tryParse(
                  json['shippingCoverageInMeters']?.toString() ?? '25000') ??
              25000,
      minOrderAmount: minOrder,
      deliveryFeeAmount: deliveryFee,
      isUsd: isUsd,
      merchantKind: json['merchantKind'] is int
          ? json['merchantKind']
          : int.tryParse(json['merchantKind']?.toString() ?? '1') ?? 1,
    );
  }

  static String? _resolveAssetByName(String title) {
    final t = title.toLowerCase();
    if (t.contains('best') || t.contains('بست')) {
      return 'assets/images/markets/best_market.webp';
    }
    if (t.contains('clover') || t.contains('كلوفر')) {
      return 'assets/images/markets/clover_mall.webp';
    }
    if (t.contains('جيتك') || t.contains('jtak')) {
      return 'assets/images/markets/jtak_market.webp';
    }
    if (t.contains('شمسين')) {
      return 'assets/images/markets/abnaa_shamsin.webp';
    }
    if (t.contains('قاسيون')) {
      return 'assets/images/markets/qasioun_hypermarket.webp';
    }
    if (t.contains('الهدى') || t.contains('هدى')) {
      return 'assets/images/markets/al_huda.webp';
    }
    if (t.contains('البركة') || t.contains('بركة')) {
      return 'assets/images/markets/al_baraka.webp';
    }
    if (t.contains('الدوحة') || t.contains('دوحة')) {
      return 'assets/images/markets/al_dawha.webp';
    }
    return null;
  }

  MockRestaurantData toRestaurantData() {
    return MockRestaurantData(
      id: id,
      name: name,
      cuisine: 'سوبرماركت',
      categoryTag: 'مواد غذائية',
      rating: 4.9,
      ratingCount: 210,
      eta: eta,
      distance: '1.8 كم',
      deliveryFee:
          deliveryFeeAmount == 0 ? 'مجاني' : '${deliveryFeeAmount.toInt()} ل.س',
      minOrder: minOrderAmount,
      hasOffers: true,
      isFast: true,
      isMarket: true,
      coverUrl: assetPath ?? logoUrl ?? '',
      logoUrl: assetPath ?? logoUrl ?? '',
      categories: const ['كل الأقسام'],
      menuItems: const [],
    );
  }
}

class RestaurantStoreModel {
  final int id;
  final String name;
  final String nameAr;
  final String nameEn;
  final String cuisine;
  final String categoryTag;
  final double rating;
  final int ratingCount;
  final String eta;
  final String distance;
  final String deliveryFee;
  final double deliveryFeeAmount;
  final int minOrderAmount;
  final bool hasOffers;
  final bool isFast;
  final String coverUrl;
  final String logoUrl;
  final double? lat;
  final double? lng;
  final int shippingCoverageInMeters;

  const RestaurantStoreModel({
    required this.id,
    required this.name,
    this.nameAr = '',
    this.nameEn = '',
    required this.cuisine,
    required this.categoryTag,
    this.rating = 4.8,
    this.ratingCount = 120,
    required this.eta,
    this.distance = '2.5 كم',
    this.deliveryFee = '5,000 ل.س',
    this.deliveryFeeAmount = 5000.0,
    this.minOrderAmount = 35000,
    this.hasOffers = false,
    this.isFast = true,
    required this.coverUrl,
    required this.logoUrl,
    this.lat,
    this.lng,
    this.shippingCoverageInMeters = 25000,
  });

  static Map<String, String> _resolveRestaurantAssets(String title) {
    final t = title.toLowerCase();
    if (t.contains('أنس') || t.contains('شاورما')) {
      return {
        'cover': 'assets/images/restaurants/anas_cover.webp',
        'logo': 'assets/images/restaurants/anas_logo.webp',
      };
    } else if (t.contains('مشاوي') ||
        t.contains('كباب') ||
        t.contains('بوابة دمشق')) {
      return {
        'cover': 'assets/images/restaurants/damascus_cover.webp',
        'logo': 'assets/images/restaurants/damascus_logo.webp',
      };
    } else if (t.contains('بوز الجدي') ||
        t.contains('فول') ||
        t.contains('فتات')) {
      return {
        'cover': 'assets/images/restaurants/bouz_cover.webp',
        'logo': 'assets/images/restaurants/bouz_logo.webp',
      };
    } else if (t.contains('بكداش') || t.contains('بوظة')) {
      return {
        'cover': 'assets/images/restaurants/bakdash_cover.webp',
        'logo': 'assets/images/restaurants/bakdash_logo.webp',
      };
    } else if (t.contains('النوفرة') || t.contains('نوفرة')) {
      return {
        'cover': 'assets/images/restaurants/noufara_cover.webp',
        'logo': 'assets/images/restaurants/noufara_logo.webp',
      };
    } else if (t.contains('برغر') || t.contains('burger')) {
      return {
        'cover': 'assets/images/restaurants/burger_cover.webp',
        'logo': 'assets/images/restaurants/burger_logo.webp',
      };
    } else if (t.contains('داوود') || t.contains('مهنا')) {
      return {
        'cover': 'assets/images/restaurants/dawood_cover.webp',
        'logo': 'assets/images/restaurants/dawood_logo.webp',
      };
    } else if (t.contains('أرت') || t.contains('art')) {
      return {
        'cover': 'assets/images/restaurants/art_cover.webp',
        'logo': 'assets/images/restaurants/art_logo.webp',
      };
    }
    return {
      'cover': 'assets/images/restaurants/anas_cover.webp',
      'logo': 'assets/images/restaurants/anas_logo.webp',
    };
  }

  RestaurantItemData toRestaurantItemData() => RestaurantItemData(
        id: id,
        name: name,
        coverUrl: coverUrl,
        logoUrl: logoUrl,
        category: '$cuisine • $categoryTag',
        rating: rating,
        ratingCount: ratingCount,
        eta: eta,
        distance: distance,
        deliveryFee: deliveryFee,
        isVerified: true,
        isOpen: true,
      );

  MockRestaurantData toRestaurantData() {
    final mockFallback = MockCatalogData.getRestaurantByName(name);
    return MockRestaurantData(
      id: id,
      name: name,
      cuisine: cuisine,
      categoryTag: categoryTag,
      rating: rating,
      ratingCount: ratingCount,
      eta: eta,
      distance: distance,
      deliveryFee: deliveryFee,
      minOrder: minOrderAmount,
      hasOffers: hasOffers,
      isFast: isFast,
      coverUrl: coverUrl,
      logoUrl: logoUrl,
      categories: mockFallback.categories.isNotEmpty
          ? mockFallback.categories
          : ['وجبات مميزة', 'مشروبات', 'إضافات'],
      menuItems:
          mockFallback.menuItems.isNotEmpty ? mockFallback.menuItems : [],
    );
  }

  factory RestaurantStoreModel.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString().trim();
    final shortDesc = (json['shortDescription'] ?? '').toString().trim();
    final photo = (json['photo'] ?? '').toString().trim();
    final nameAr = MarketStoreModel.extractArabicName(title);
    final nameEn = MarketStoreModel.extractEnglishName(title);

    String cuisine = 'مطاعم وسريع';
    String eta = '20-30 دقيقة';
    if (shortDesc.contains('•')) {
      final parts = shortDesc.split('•');
      cuisine = parts[0].trim();
      eta = parts[1].trim();
    } else if (shortDesc.contains('دقيقة')) {
      eta = shortDesc;
    } else if (shortDesc.isNotEmpty) {
      cuisine = shortDesc;
    }

    String categoryTag = 'وجبات سريعة';
    final tLower = title.toLowerCase();
    int minOrder = 30000;

    if (tLower.contains('أنس') ||
        title.contains('أنس') ||
        title.contains('شاورما')) {
      categoryTag = 'شاورما';
      minOrder = 30000;
    } else if (title.contains('مشاوي') ||
        title.contains('كباب') ||
        title.contains('بوابة دمشق')) {
      categoryTag = 'مشاوي';
      minOrder = 45000;
    } else if (title.contains('بوز الجدي') ||
        title.contains('فلافل') ||
        title.contains('فول') ||
        title.contains('فتات')) {
      categoryTag = 'فطور شعبي';
      minOrder = 20000;
    } else if (title.contains('بكداش') ||
        title.contains('بوظة') ||
        title.contains('حلاوة الجبن')) {
      categoryTag = 'حلويات';
      minOrder = 25000;
    } else if (title.contains('النوفرة') ||
        title.contains('نوفرة') ||
        title.contains('مقهى')) {
      categoryTag = 'كافيه ومشروبات';
      minOrder = 20000;
    } else if (tLower.contains('burger') ||
        title.contains('برغر') ||
        title.contains('برجر')) {
      categoryTag = 'البرجر';
      minOrder = 35000;
    } else if (title.contains('داوود') ||
        title.contains('مهنا') ||
        title.contains('بقلاوة') ||
        title.contains('مبرومة') ||
        title.contains('معمول')) {
      categoryTag = 'حلويات';
      minOrder = 40000;
    } else if (title.contains('أرت') ||
        tLower.contains('art') ||
        title.contains('كافيه') ||
        title.contains('قهوة')) {
      categoryTag = 'كافيه ومشروبات';
      minOrder = 25000;
    }

    final resolvedAssets = _resolveRestaurantAssets(title);
    String coverUrl = resolvedAssets['cover']!;
    String logoUrl = resolvedAssets['logo']!;

    if (photo.contains(',')) {
      final parts = photo
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty && parts[0].isNotEmpty && parts[0] != 'null') {
        coverUrl = GlobalVar.getImageUrl(parts[0]);
      }
      if (parts.length > 1 && parts[1].isNotEmpty && parts[1] != 'null') {
        logoUrl = GlobalVar.getImageUrl(parts[1]);
      } else {
        logoUrl = coverUrl;
      }
    } else if (photo.startsWith('http')) {
      logoUrl = photo;
      coverUrl = photo;
    } else if (photo.isNotEmpty && photo.toLowerCase() != 'null') {
      coverUrl = GlobalVar.getImageUrl(photo);
      logoUrl = coverUrl;
    }

    double fee = 5000.0;
    if (json['shippingCost'] != null) {
      fee = (json['shippingCost'] as num).toDouble();
    } else if (json['deliveryFee'] != null) {
      fee = (json['deliveryFee'] as num).toDouble();
    }

    return RestaurantStoreModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      name: title,
      nameAr: nameAr,
      nameEn: nameEn,
      cuisine: cuisine,
      categoryTag: categoryTag,
      rating: 4.8,
      ratingCount: 140,
      eta: eta,
      distance: '2.5 كم',
      deliveryFee: '${fee.toInt()} ل.س',
      deliveryFeeAmount: fee,
      minOrderAmount: minOrder,
      hasOffers: true,
      isFast: true,
      coverUrl: coverUrl,
      logoUrl: logoUrl,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      shippingCoverageInMeters: json['shippingCoverageInMeters'] is int
          ? json['shippingCoverageInMeters']
          : int.tryParse(
                  json['shippingCoverageInMeters']?.toString() ?? '25000') ??
              25000,
    );
  }
}

class MarketsProvider extends BaseProvider {
  // Initialize immediately with verified live markets so the home screen renders in 0ms without skeleton delay
  List<MarketStoreModel> _markets = List.from(_defaultLiveSeededMarkets);
  List<MarketStoreModel> get markets => _markets;

  List<RestaurantStoreModel> _restaurants =
      List.from(_defaultLiveSeededRestaurants);
  List<RestaurantStoreModel> get restaurants => _restaurants;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // In-memory cache for market products and category merchants
  final Map<int, List<Map<String, dynamic>>> _marketProductsCache = {};
  final Map<int, List<MarketStoreModel>> _categoryMerchantsCache = {};

  // USD to SYP Exchange Rate (defaults to 15,000, dynamically updated from Admin Settings)
  double _exchangeRate = 15000.0;
  double get exchangeRate => _exchangeRate;

  MarketsProvider() {
    _loadAllAssetProducts();
    loadMarkets();
    fetchExchangeRate();
  }

  Future<void> _loadAllAssetProducts() async {
    await Future.wait([
      _loadAssetProducts(19),
      _loadAssetProducts(18),
    ]);
  }

  Future<List<Map<String, dynamic>>> _loadAssetProducts(int marketId) async {
    if (_marketProductsCache.containsKey(marketId) &&
        _marketProductsCache[marketId]!.isNotEmpty) {
      return _marketProductsCache[marketId]!;
    }
    try {
      String? assetPath;
      if (marketId == 19) {
        assetPath = 'assets/data/clover_mall_products.json';
      } else if (marketId == 18) {
        assetPath = 'assets/data/best_market_products.json';
      }
      if (assetPath != null) {
        final jsonString = await rootBundle.loadString(assetPath);
        final List decoded = jsonDecode(jsonString);
        final list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        if (list.isNotEmpty) {
          _marketProductsCache[marketId] = list;
          notifyListeners();
          return list;
        }
      }
    } catch (e) {
      debugPrint(
          'MarketsProvider: Error loading asset products for $marketId: $e');
    }
    return _marketProductsCache[marketId] ?? const [];
  }

  List<Map<String, dynamic>>? getCachedProducts(int marketId) {
    return _marketProductsCache[marketId];
  }

  List<MarketStoreModel> getCachedCategoryMerchants(int categoryId) {
    return List.unmodifiable(
      _categoryMerchantsCache[categoryId] ?? const <MarketStoreModel>[],
    );
  }

  Future<void> fetchExchangeRate() async {
    try {
      final userToken = locator<AuthenticationService>().getAccessToken;
      final url = Uri.parse('https://api.jtak.app/api/v1/Customer/Home/Settings');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (userToken.isNotEmpty) 'Authorization': 'Bearer $userToken',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data != null && data['usdToSypExchangeRate'] != null) {
          final rate = (data['usdToSypExchangeRate'] as num).toDouble();
          if (rate > 0 && rate != _exchangeRate) {
            _exchangeRate = rate;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('MarketsProvider: Error fetching exchange rate: $e');
    }
  }

  Future<void> loadMarkets() async {
    // Keep showing existing markets while refreshing in background
    if (_markets.isEmpty) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final userToken = locator<AuthenticationService>().getAccessToken;
      final url =
          Uri.parse('https://api.jtak.app/api/v1/Customer/Products/Merchants');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (userToken.isNotEmpty) 'Authorization': 'Bearer $userToken',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List items = decoded is List ? decoded : (decoded['items'] ?? []);

        final List<MarketStoreModel> fetchedMarkets = [];
        final List<RestaurantStoreModel> fetchedRestaurants = [];
        final Set<String> seenRestaurantTitles = {};

        for (var item in items) {
          final title = (item['title'] ?? '').toString();
          final shortDesc = (item['shortDescription'] ?? '').toString();
          final active = item['active'] == true;
          if (!active) continue;

          final titleLower = title.toLowerCase();
          final shortDescLower = shortDesc.toLowerCase();
          final hasExplicitKind = item is Map &&
              item.containsKey('merchantKind') &&
              item['merchantKind'] != null;
          final merchantKind = int.tryParse(
                (item['merchantKind'] ?? '').toString(),
              ) ??
              0;

          final legacyIsMarket = title.contains('ماركت') ||
              title.contains('سوبرماركت') ||
              title.contains('سوبر ماركت') ||
              title.contains('هايبر') ||
              title.contains('أسواق') ||
              title.contains('بقالة') ||
              title.contains('تموينات') ||
              title.contains('مول') ||
              titleLower.contains('market') ||
              titleLower.contains('mart') ||
              titleLower.contains('mall') ||
              titleLower.contains('grocery') ||
              shortDesc.contains('ماركت') ||
              shortDesc.contains('سوبرماركت') ||
              shortDesc.contains('سوبر ماركت') ||
              shortDesc.contains('أسواق') ||
              shortDesc.contains('بقالة') ||
              shortDescLower.contains('market') ||
              shortDescLower.contains('mart') ||
              shortDescLower.contains('grocery');
          final isMarket = hasExplicitKind ? merchantKind == 1 : legacyIsMarket;
          final isRestaurant =
              hasExplicitKind ? merchantKind == 0 : !legacyIsMarket;

          if (isMarket) {
            fetchedMarkets.add(MarketStoreModel.fromJson(item));
          } else if (isRestaurant) {
            final normTitle = title.split(' - ').first.trim().toLowerCase();
            if (!seenRestaurantTitles.contains(normTitle) &&
                normTitle.isNotEmpty &&
                normTitle != 'merchant01') {
              seenRestaurantTitles.add(normTitle);
              fetchedRestaurants.add(RestaurantStoreModel.fromJson(item));
            }
          }
        }

        if (fetchedMarkets.isNotEmpty) {
          _markets = fetchedMarkets;
        }
        if (fetchedRestaurants.isNotEmpty) {
          _restaurants = fetchedRestaurants;
        }
        _isLoading = false;
        notifyListeners();

        // Silently pre-fetch real live products from backend for all active markets & restaurants
        for (final store in fetchedMarkets) {
          fetchMarketProducts(store.id);
        }
        for (final store in fetchedRestaurants) {
          fetchMarketProducts(store.id);
        }
        return;
      }
    } catch (e) {
      debugPrint('MarketsProvider: Error fetching customer merchants: $e');
    }

    // Fallback: Use verified seeded live backend IDs for resilience
    if (_markets.isEmpty) {
      _markets = List.from(_defaultLiveSeededMarkets);
    }
    if (_restaurants.isEmpty) {
      _restaurants = List.from(_defaultLiveSeededRestaurants);
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Fetches products assigned to this market using the customer-facing endpoint
  /// with instant asset cache and resilient fallback
  Future<List<Map<String, dynamic>>> fetchMarketProducts(int marketId) async {
    // 1. Ensure seed products from asset are populated immediately into cache
    if (!_marketProductsCache.containsKey(marketId) ||
        _marketProductsCache[marketId]!.isEmpty) {
      await _loadAssetProducts(marketId);
    }

    // 2. Refresh live from customer backend endpoint
    try {
      final userToken = locator<AuthenticationService>().getAccessToken;
      final url = Uri.parse(
          'https://api.jtak.app/api/v1/Customer/Products/Merchants/$marketId/Products');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (userToken.isNotEmpty) 'Authorization': 'Bearer $userToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List prods = jsonDecode(res.body);
        final list = prods
            .where((p) => p['merchantId'] == marketId)
            .map((p) => Map<String, dynamic>.from(p))
            .toList();

        if (list.isNotEmpty) {
          _marketProductsCache[marketId] = list;
          notifyListeners();
          return list;
        }
      }
    } catch (e) {
      debugPrint('MarketsProvider: Error fetching customer market products: $e');
    }

    return _marketProductsCache[marketId] ?? getDefaultSeededProducts(marketId);
  }

  /// Loads explicitly typed merchants in one request. [categoryId] remains
  /// the cache key because each featured catalog owns a distinct result set.
  Future<List<MarketStoreModel>> fetchMerchantsForCategory(
    int categoryId,
    int merchantKind,
  ) async {
    try {
      final userToken = locator<AuthenticationService>().getAccessToken;
      final url = Uri.parse(
        'https://api.jtak.app/api/v1/Customer/Products/MerchantsByKind/$merchantKind',
      );
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (userToken.isNotEmpty) 'Authorization': 'Bearer $userToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final merchants = decoded
              .whereType<Map<String, dynamic>>()
              .map(MarketStoreModel.fromJson)
              .where((merchant) => merchant.id > 0)
              .toList();
          if (merchants.isNotEmpty) {
            _categoryMerchantsCache[categoryId] = merchants;
            return merchants;
          }
        }
      }
    } catch (error) {
      debugPrint(
        'MarketsProvider: Error fetching category $categoryId merchants: $error',
      );
    }

    // Resilient fallback when backend endpoint returns 404 or fails
    final cached = _categoryMerchantsCache[categoryId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final localFallback = _markets
        .where((m) => m.merchantKind == merchantKind || (merchantKind == 0 && m.merchantKind == 0))
        .toList();
    if (localFallback.isNotEmpty) {
      return localFallback;
    }

    return const [];
  }

  /// Returns cached or verified seed products for the given market
  List<Map<String, dynamic>> getDefaultSeededProducts(int marketId) {
    return _marketProductsCache[marketId] ?? const [];
  }

  /// Converts live backend products into MockRestaurantData with full item details
  MockRestaurantData toRestaurantDataFromProducts(
    RestaurantStoreModel store,
    List<Map<String, dynamic>> backendProducts,
  ) {
    if (backendProducts.isEmpty) {
      return store.toRestaurantData();
    }

    final List<MockMenuItemData> items = [];
    final Set<String> catSet = {};

    for (int i = 0; i < backendProducts.length; i++) {
      final p = backendProducts[i];
      final pid = (p['productId'] as num?)?.toInt() ?? (1000 + i);
      final title = (p['product'] ?? '').toString();
      final desc = (p['productDescription'] ?? '').toString();
      final photo = (p['productPhotos'] ?? '').toString();
      final numPrice =
          (p['finalPrice'] ?? p['merchantPrice'] ?? p['price'] ?? 0) as num;
      final intPrice = numPrice.toInt();

      String category = (p['productCat1'] ?? '').toString().trim();
      if (category.isEmpty ||
          category == 'Uncategorized' ||
          category == 'المطاعم') {
        category = 'وجبات وقائمة الطعام';
      }
      catSet.add(category);

      String imageUrl = '';
      if (photo.isNotEmpty && photo != 'null') {
        imageUrl = GlobalVar.getImageUrl(photo);
      }
      if (imageUrl.isEmpty) {
        imageUrl = store.coverUrl;
      }

      items.add(MockMenuItemData(
        id: pid,
        restaurantId: store.id,
        restaurantName: store.name,
        title: title,
        description: desc.isNotEmpty ? desc : title,
        price: '${_formatNumber(intPrice)} ل.س',
        basePriceValue: intPrice,
        imageUrl: imageUrl,
        category: category,
      ));
    }

    final categories = catSet.toList();
    if (categories.isEmpty) categories.add('وجبات وقائمة الطعام');

    return MockRestaurantData(
      id: store.id,
      name: store.name,
      cuisine: store.cuisine,
      categoryTag: store.categoryTag,
      rating: store.rating,
      ratingCount: store.ratingCount,
      eta: store.eta,
      distance: store.distance,
      deliveryFee: store.deliveryFee,
      minOrder: store.minOrderAmount,
      hasOffers: store.hasOffers,
      isFast: store.isFast,
      coverUrl: store.coverUrl,
      logoUrl: store.logoUrl,
      categories: categories,
      menuItems: items,
    );
  }

  static String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  static List<MarketStoreModel> get defaultLiveSeededMarkets =>
      _defaultLiveSeededMarkets;
  static List<RestaurantStoreModel> get defaultLiveSeededRestaurants =>
      _defaultLiveSeededRestaurants;

  // Verified seeded live backend markets
  static final List<MarketStoreModel> _defaultLiveSeededMarkets = [
    const MarketStoreModel(
      id: 18,
      name: 'Best Market - بست ماركت',
      eta: '20-30 دقيقة',
      tagline: 'سوبرماركت ومقاضي شاملة بالدولار',
      logoText: 'Best',
      logoBoxedText: 'Market',
      logoColor: Color(0xFF1D4ED8),
      assetPath: 'assets/images/markets/best_market.webp',
      logoUrl:
          'https://api.jtak.app/api/v1/services/Download/2026_9_9_3c20568108304ee98d972785ebbff021.webp',
    ),
    const MarketStoreModel(
      id: 19,
      name: 'Clover Mall - كلوفر مول',
      eta: '25-35 دقيقة',
      tagline: 'مركز تسوق ومستلزمات منزلية ومنظفات',
      logoText: 'Clover',
      logoBoxedText: 'Mall',
      logoColor: Color(0xFF047857),
      assetPath: 'assets/images/markets/clover_mall.webp',
      logoUrl:
          'https://api.jtak.app/api/v1/services/Download/2026_9_9_f1797b5194ce434c88fb8000d6832642.webp',
    ),
    const MarketStoreModel(
      id: 12,
      name: 'جيتك ماركت - JTAK Market',
      eta: '15-20 دقيقة',
      tagline: 'توصيل فوري فائق السرعة',
      logoText: 'جيتك',
      logoBoxedText: 'ماركت',
      logoColor: Color(0xFFFF5C00),
      assetPath: 'assets/images/markets/jtak_market.webp',
    ),
    const MarketStoreModel(
      id: 13,
      name: 'سوبرماركت أبناء شمسين',
      eta: '20-30 دقيقة',
      tagline: 'أكبر تشكيلة مونة ومقاضي',
      logoText: 'شمسين',
      logoBoxedText: 'سوبرماركت',
      logoColor: Color(0xFF0F766E),
      assetPath: 'assets/images/markets/abnaa_shamsin.webp',
    ),
    const MarketStoreModel(
      id: 14,
      name: 'هايبرماركت قاسيون مول',
      eta: '25-35 دقيقة',
      tagline: 'عروض وتخفيضات أسبوعية',
      logoText: 'قاسيون',
      logoBoxedText: 'هايبر',
      logoColor: Color(0xFF7C2D12),
      assetPath: 'assets/images/markets/qasioun_hypermarket.webp',
    ),
    const MarketStoreModel(
      id: 15,
      name: 'سوبرماركت الهدى',
      eta: '15-25 دقيقة',
      tagline: 'أجبان، ألبان ومقاضي طازجة',
      logoText: 'الهدى',
      logoBoxedText: 'ماركت',
      logoColor: Color(0xFF1E3A8A),
      assetPath: 'assets/images/markets/al_huda.webp',
    ),
    const MarketStoreModel(
      id: 16,
      name: 'سوبرماركت البركة',
      eta: '20-35 دقيقة',
      tagline: 'منتجات بلدية ومستوردة فاخرة',
      logoText: 'البركة',
      logoBoxedText: 'سوبرماركت',
      logoColor: Color(0xFF047857),
      assetPath: 'assets/images/markets/al_baraka.webp',
    ),
    const MarketStoreModel(
      id: 17,
      name: 'سوبرماركت الدوحة',
      eta: '20-30 دقيقة',
      tagline: 'كل ما تحتاجه العائلة يومياً',
      logoText: 'الدوحة',
      logoBoxedText: 'ماركت',
      logoColor: Color(0xFF4338CA),
      assetPath: 'assets/images/markets/al_dawha.webp',
    ),
  ];

  static final List<RestaurantStoreModel> _defaultLiveSeededRestaurants = [
    const RestaurantStoreModel(
      id: 8,
      name: 'شاورما أنس الدمشقية - Shawarma Anas',
      nameAr: 'شاورما أنس الدمشقية',
      nameEn: 'Shawarma Anas',
      cuisine: 'شاورما سورية على أصولها، وجبات عربي وسندويش صاج',
      categoryTag: 'شاورما',
      rating: 4.9,
      ratingCount: 1850,
      eta: '15-25 دقيقة',
      distance: '1.8 كم',
      deliveryFee: '3,500 ل.س',
      deliveryFeeAmount: 3500.0,
      minOrderAmount: 30000,
      hasOffers: true,
      isFast: true,
      logoUrl: 'assets/images/products/Arabic Chicken Shawarma Platter.webp',
      coverUrl: 'assets/images/products/Arabic Chicken Shawarma Platter.webp',
    ),
    const RestaurantStoreModel(
      id: 6,
      name: 'مشاوي وكباب بوابة دمشق',
      nameAr: 'مشاوي وكباب بوابة دمشق',
      nameEn: 'Damascus Gate Grills',
      cuisine: 'مشاوي على الفحم، كباب حلبي، شيش وكبة مشوية',
      categoryTag: 'مشاوي',
      rating: 4.9,
      ratingCount: 1420,
      eta: '25-40 دقيقة',
      distance: '2.5 كم',
      deliveryFee: '5,000 ل.س',
      deliveryFeeAmount: 5000.0,
      minOrderAmount: 45000,
      hasOffers: true,
      isFast: false,
      logoUrl: 'assets/images/categories/meat_poultry.png',
      coverUrl: 'assets/images/categories/meat_poultry.png',
    ),
    const RestaurantStoreModel(
      id: 10,
      name: 'فطاير وفول بوز الجدي',
      nameAr: 'فطاير وفول بوز الجدي',
      nameEn: 'Bouz El Jedi',
      cuisine: 'فتات شامية، فول ومسبحة، فلافل سخنة ومعجنات بالفرن',
      categoryTag: 'فطور شعبي',
      rating: 4.9,
      ratingCount: 2100,
      eta: '15-20 دقيقة',
      distance: '1.2 كم',
      deliveryFee: 'مجاني',
      deliveryFeeAmount: 0.0,
      minOrderAmount: 20000,
      hasOffers: true,
      isFast: true,
      logoUrl: 'assets/images/categories/dish_syrian.png',
      coverUrl: 'assets/images/categories/dish_syrian.png',
    ),
    const RestaurantStoreModel(
      id: 7,
      name: 'حلويات بكداش التراثية - Bakdash',
      nameAr: 'حلويات بكداش التراثية',
      nameEn: 'Bakdash Sweets',
      cuisine: 'بوظة شامية مدقوقة بالفستق، قشطة عربية وحلاوة الجبن',
      categoryTag: 'حلويات',
      rating: 4.9,
      ratingCount: 2450,
      eta: '20-30 دقيقة',
      distance: '2.1 كم',
      deliveryFee: '4,000 ل.س',
      deliveryFeeAmount: 4000.0,
      minOrderAmount: 25000,
      hasOffers: true,
      isFast: true,
      logoUrl:
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=300&q=80',
      coverUrl:
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=1200&q=80',
    ),
    const RestaurantStoreModel(
      id: 11,
      name: 'مقهى النوفرة التراثي',
      nameAr: 'مقهى النوفرة التراثي',
      nameEn: 'Al Noufara Heritage Cafe',
      cuisine: 'مقهى شامي عريق، شاي بالنعناع، قهوة بالمستكة وسحلب',
      categoryTag: 'كافيه ومشروبات',
      rating: 4.8,
      ratingCount: 1600,
      eta: '15-25 دقيقة',
      distance: '2.8 كم',
      deliveryFee: '3,500 ل.س',
      deliveryFeeAmount: 3500.0,
      minOrderAmount: 20000,
      hasOffers: true,
      isFast: true,
      logoUrl:
          'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=300&q=80',
      coverUrl:
          'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1200&q=80',
    ),
    const RestaurantStoreModel(
      id: 9,
      name: 'كلاسيك برغر الشام',
      nameAr: 'كلاسيك برغر الشام',
      nameEn: 'Classic Burger Sham',
      cuisine: 'برغر لحم بلدي طازج، كرسبي تشيكن وبطاطا لوديد',
      categoryTag: 'البرجر',
      rating: 4.8,
      ratingCount: 1350,
      eta: '20-30 دقيقة',
      distance: '2.3 كم',
      deliveryFee: '4,000 ل.س',
      deliveryFeeAmount: 4000.0,
      minOrderAmount: 35000,
      hasOffers: true,
      isFast: true,
      logoUrl: 'assets/images/products/Double Angus Smash Burger.webp',
      coverUrl: 'assets/images/products/Double Angus Smash Burger.webp',
    ),
    const RestaurantStoreModel(
      id: 5,
      name: 'حلويات داوود ومهنا',
      nameAr: 'حلويات داوود ومهنا',
      nameEn: 'Dawood & Muhanna',
      cuisine: 'حلويات دمشقية، مبرومة بالفستق، معمول ومدلوقة',
      categoryTag: 'حلويات',
      rating: 4.9,
      ratingCount: 1980,
      eta: '25-35 دقيقة',
      distance: '3.2 كم',
      deliveryFee: '4,500 ل.س',
      deliveryFeeAmount: 4500.0,
      minOrderAmount: 40000,
      hasOffers: true,
      isFast: false,
      logoUrl:
          'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=300&q=80',
      coverUrl:
          'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=1200&q=80',
    ),
    const RestaurantStoreModel(
      id: 4,
      name: 'أرت كافيه الشام - Art & Beans',
      nameAr: 'أرت كافيه الشام',
      nameEn: 'Art & Beans Cafe',
      cuisine: 'قهوة مختصة، سبانش لاتيه، تشيزكيك التوت الشامي',
      categoryTag: 'كافيه ومشروبات',
      rating: 4.8,
      ratingCount: 1250,
      eta: '15-25 دقيقة',
      distance: '2.2 كم',
      deliveryFee: '3,500 ل.س',
      deliveryFeeAmount: 3500.0,
      minOrderAmount: 25000,
      hasOffers: true,
      isFast: true,
      logoUrl:
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=300&q=80',
      coverUrl:
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=1200&q=80',
    ),
  ];
}

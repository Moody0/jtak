import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/categories_provider.dart';
import '../../../core/controllers/catalog/markets_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../../core/services/locator.dart';
import '../../../utils/utilities/global_var.dart';
import '../../widgets/catalog/replace_cart_bottom_sheet.dart';
import '../../widgets/header_circle_button.dart';
import '../cart/cart_page.dart';
import 'market_category_products_page.dart';
import 'market_product_detail_page.dart';
import 'market_search_page.dart';
import 'restaurant_menu_page.dart';
import '../../widgets/catalog/market_product_card.dart';
import '../../widgets/clean_shimmer_skeletons.dart';
import '../../../core/controllers/initial_data_provider.dart';
import '../../../core/models/banner_model.dart';
import '../../../utils/providers/sol_api.dart';
import 'package:url_launcher/url_launcher.dart';

class _MarketHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

/// ---------------------------------------------------------------------------
/// JTAK Market & Supermarket Page (تجربة تسوق السوبرماركت والمارت المتخصصة)
///
/// Features matching reference design:
/// 1. Top Header: Store Logo, Name, "التجهيز من فريق جيتك >", and Search field
/// 2. Hero Thematic Bundles: "جهّز مطبخك", "فطار البيت", "من الفريزر", "المونة", etc.
/// 3. "تسوق حسب الفئة": 4-Column Paginated Category Grid with progress slider
/// 4. Horizontal Product Aisles with quick (+) Add buttons:
///    - منتجات مبردة ومجمدة
///    - 🔥 الأكثر مبيعًا
///    - منتجات الزبدة والبيض 🥚🧀
///    - ☕ القهوة والشاي
/// 5. Persistent Bottom Minimum Order / Active Cart Bar
/// ---------------------------------------------------------------------------

class MarketCategoryItem {
  final int id;
  final String title;
  final String imageUrl;
  final IconData fallbackIcon;
  final int productCount;

  const MarketCategoryItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.fallbackIcon,
    this.productCount = 0,
  });
}

class MarketProductItem {
  final int id;
  final String title;
  final String price;
  final int priceValue;
  final String imageUrl;
  final String category;
  final String? _mainCategory;
  final String? _subCategory;
  final String? brand;
  final String? weight;
  final String? description;

  String get mainCategory {
    try {
      if (_mainCategory != null && _mainCategory!.trim().isNotEmpty) {
        return _mainCategory!;
      }
      if (category.trim().isNotEmpty) {
        return category;
      }
    } catch (_) {}
    return 'عام';
  }

  String get subCategory {
    try {
      if (_subCategory != null && _subCategory!.trim().isNotEmpty) {
        return _subCategory!;
      }
      if (category.trim().isNotEmpty) {
        return category;
      }
    } catch (_) {}
    return 'عام';
  }

  const MarketProductItem({
    required this.id,
    required this.title,
    required this.price,
    required this.priceValue,
    required this.imageUrl,
    required this.category,
    String? mainCategory,
    String? subCategory,
    this.brand,
    this.weight,
    this.description,
  })  : _mainCategory = mainCategory,
        _subCategory = subCategory;

  MockMenuItemData toMockMenuItemData(int marketId, String marketName) {
    return MockMenuItemData(
      id: id,
      restaurantId: marketId,
      restaurantName: marketName,
      category: category,
      title: title,
      description: description ?? title,
      price: price,
      basePriceValue: priceValue,
      imageUrl: imageUrl,
      calories: weight ?? '',
    );
  }
}

class MarketPage extends StatefulWidget {
  static const String routeName = '/MarketPage';

  final int? marketId;
  final String? marketName;
  final String? logoUrl;
  final String? coverUrl;

  const MarketPage({
    super.key,
    this.marketId,
    this.marketName,
    this.logoUrl,
    this.coverUrl,
  });

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();
  double _categoryScrollProgress = 0.0;
  double _headerScrollOffset = 0.0;
  static const double _kHeaderCollapseRange = 70.0;
  double _bottomBarOffset = 0.0;
  static const double _maxBottomBarHeight = 130.0;
  int get _minOrderTarget =>
      _storeModel != null && _storeModel!.minOrderAmount > 0
          ? _storeModel!.minOrderAmount
          : 50000;
  MarketStoreModel? _storeModel;

  String get _currentMarketName {
    String langCode = 'ar';
    try {
      langCode = Localizations.localeOf(context).languageCode;
    } catch (_) {}

    String name = '';
    if (_storeModel != null) {
      name = _storeModel!.localizedName(langCode);
    } else if (widget.marketName != null && widget.marketName!.trim().isNotEmpty) {
      name = MarketStoreModel.extractLocalizedName(
          widget.marketName!, langCode);
    } else {
      name = langCode == 'ar' ? 'جيتك ماركت' : 'JTAK Market';
    }
    return name.replaceAll('جتاك', 'جيتك');
  }

  int get _effectiveMarketId {
    if (widget.marketId != null && widget.marketId! > 0) {
      return widget.marketId!;
    }
    // Dynamic fallback: resolve from live markets list
    if (widget.marketName != null && widget.marketName!.trim().isNotEmpty) {
      final marketsProv = _getMarketsProvider();
      final nameLower = widget.marketName!.toLowerCase().trim();
      for (final m in marketsProv.markets) {
        if (m.name.toLowerCase().contains(nameLower) ||
            nameLower.contains(m.name.toLowerCase()) ||
            m.nameAr.toLowerCase().contains(nameLower) ||
            nameLower.contains(m.nameAr.toLowerCase()) ||
            (m.nameEn.isNotEmpty &&
                (m.nameEn.toLowerCase().contains(nameLower) ||
                    nameLower.contains(m.nameEn.toLowerCase())))) {
          return m.id;
        }
      }
    }
    final first = _getMarketsProvider().markets.firstOrNull;
    return first?.id ?? 12;
  }

  void _initStoreModel() {
    final int marketId = _effectiveMarketId;
    final marketsProv = _getMarketsProvider();
    try {
      _storeModel = marketsProv.markets.firstWhere(
        (m) => m.id == marketId,
        orElse: () => MarketStoreModel(
          id: marketId,
          name: widget.marketName ?? 'جيتك ماركت - JTAK Market',
          eta: '15-20 دقيقة',
          tagline: 'سوبرماركت ومقاضي شاملة • آلاف المنتجات',
          logoText: 'جيتك',
          logoBoxedText: 'ماركت',
          logoColor: const Color(0xFFFF5C00),
          assetPath: 'assets/images/markets/jtak_market.webp',
        ),
      );
    } catch (_) {
      _storeModel = null;
    }
  }

  // Dynamic Market State
  bool _isLoadingProducts = true;
  List<BannerModel> _marketBanners = [];
  List<MarketCategoryItem> _allCategories = [];
  List<MarketProductItem> _allMarketProducts = [];
  Map<String, List<MarketProductItem>> _shelves = {};

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }


  void _onPlusTapped(int productId) async {
    final marketId = _effectiveMarketId;
    final cart = locator<CartProvider>();
    if (cart.isDifferentMerchant(marketId)) {
      final marketName = _currentMarketName;
      final shouldReplace = await ReplaceCartBottomSheet.show(
        context,
        currentStoreName: cart.getConflictingMerchantName(marketId),
        newStoreName: marketName,
      );
      if (shouldReplace != true || !mounted) return;
      final product = _allMarketProducts.firstWhere(
        (p) => p.id == productId,
        orElse: () => MarketProductItem(
          id: productId,
          title: 'منتج',
          price: '0 ل.س',
          priceValue: 0,
          imageUrl: '',
          category: 'عام',
        ),
      );
      await cart.replaceCartWithItem(
        productId,
        marketId,
        product.priceValue.toDouble(),
        1,
        title: product.title,
        imageUrl: product.imageUrl,
      );
      return;
    }

    final currentQty = cart.getProductQuantity(productId);
    final newQty = currentQty + 1;
    final product = _allMarketProducts.firstWhere(
      (p) => p.id == productId,
      orElse: () => MarketProductItem(
        id: productId,
        title: 'منتج',
        price: '0 ل.س',
        priceValue: 0,
        imageUrl: '',
        category: 'عام',
      ),
    );
    cart.setToCart(
      productId,
      marketId,
      product.priceValue.toDouble(),
      newQty,
      title: product.title,
      imageUrl: product.imageUrl,
    );
  }

  void _onMinusTapped(int productId) {
    final marketId = _effectiveMarketId;
    final cart = locator<CartProvider>();
    final currentQty = cart.getProductQuantity(productId);
    if (currentQty <= 1) {
      cart.removeFromCart(productId, marketId);
    } else {
      final product = _allMarketProducts.firstWhere(
        (p) => p.id == productId,
        orElse: () => MarketProductItem(
          id: productId,
          title: 'منتج',
          price: '0 ل.س',
          priceValue: 0,
          imageUrl: '',
          category: 'عام',
        ),
      );
      cart.setToCart(
        productId,
        marketId,
        product.priceValue.toDouble(),
        currentQty - 1,
        title: product.title,
        imageUrl: product.imageUrl,
      );
    }
  }

  void _syncCartFromProvider() {
    // No-op: product cards and bottom cart bar are reactive via CartProvider!
  }

  MarketsProvider _getMarketsProvider() {
    if (locator.isRegistered<MarketsProvider>()) {
      return locator<MarketsProvider>();
    }
    try {
      return Provider.of<MarketsProvider>(context, listen: false);
    } catch (_) {
      return MarketsProvider();
    }
  }

  static String cleanCategoryText(String raw) {
    return raw.replaceAll(RegExp(r'[\uFFFD\u0000-\u001F]'), '').trim();
  }

  static String normalizeMainCategory(String rawMain) {
    var s = cleanCategoryText(rawMain);
    if (s == 'غذائية') return 'غذائيات';
    if (s == 'اجبان وألبان' || s == 'أجبان وألبان') return 'ألبان وأجبان';
    return s.isNotEmpty ? s : 'عام';
  }

  static String normalizeSubCategory(String rawSub) {
    var s = cleanCategoryText(rawSub);
    if (s.contains('بسكو')) return 'بسكويت';
    if (s.contains('شيبس')) return 'شيبسات';
    if (s.contains('صاب')) return 'صابون';
    if (s.contains('العناية بالشعر') || s.contains('عناية بالشعر')) {
      return 'عناية بالشعر والجسم';
    }
    if (s.contains('اجبان')) return 'أجبان';
    if (s.contains('ادوات تنظيف')) return 'أدوات تنظيف';
    return s.isNotEmpty ? s : 'عام';
  }

  void _updateCategoriesFromProducts(List<MarketProductItem> products) {
    if (products.isEmpty) {
      _allCategories = [];
      return;
    }

    final Map<String, int> counts = {};

    for (final p in products) {
      final main = p.mainCategory.trim();
      if (main.isEmpty || main == 'عام') continue;
      counts[main] = (counts[main] ?? 0) + 1;
    }

    final sortedKeys = counts.keys.toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));

    final List<MarketCategoryItem> items = [];
    int idCounter = 1;

    for (final main in sortedKeys) {
      final photoUrl = _getCategoryAssetOrNetworkUrl(main);
      items.add(MarketCategoryItem(
        id: idCounter++,
        title: main,
        imageUrl: photoUrl,
        fallbackIcon: _getCategoryFallbackIcon(main),
        productCount: counts[main] ?? 0,
      ));
    }

    _allCategories = items;
  }

  List<MarketProductItem> _convertRawProducts(
      List<Map<String, dynamic>> rawProducts) {
    final List<MarketProductItem> converted = [];
    final marketsProv = _getMarketsProvider();
    final double exchangeRate = marketsProv.exchangeRate;

    for (final raw in rawProducts) {
      final id = (raw['productId'] ?? raw['id'] ?? 0) as int;
      final title = (raw['product'] ?? raw['title'] ?? '').toString().trim();
      if (id == 0 || title.isEmpty) continue;

      final rawPrice =
          ((raw['finalPrice'] ?? raw['merchantPrice'] ?? raw['price'] ?? 0)
                  as num)
              .toDouble();
      final isUsd = (_storeModel?.isUsd ?? false) ||
          (raw['priceUsd'] != null && (raw['priceUsd'] as num) > 0);
      final int priceVal =
          isUsd ? (rawPrice * exchangeRate).round() : rawPrice.round();

      final cleanSub = cleanCategoryText((raw['productCat1'] ?? '').toString());
      final cleanMain =
          cleanCategoryText((raw['productCat2'] ?? '').toString());
      final mainCat = normalizeMainCategory(cleanMain.isNotEmpty
          ? cleanMain
          : (cleanSub.isNotEmpty ? cleanSub : 'عام'));
      final subCat =
          normalizeSubCategory(cleanSub.isNotEmpty ? cleanSub : mainCat);
      final brand = _nonEmpty(raw['productBrand']);
      final desc = _nonEmpty(raw['productDescription'] ?? raw['description']);
      final weight = _nonEmpty(raw['productUnit'] ?? raw['unit']);

      final imageUrl = _resolveProductImage(raw['productPhotos'] ?? raw['photos']);

      converted.add(MarketProductItem(
        id: id,
        title: title,
        price: '${_formatPrice(priceVal)} ل.س',
        priceValue: priceVal,
        imageUrl: imageUrl,
        category: subCat,
        mainCategory: mainCat,
        subCategory: subCat,
        brand: brand,
        weight: weight,
        description: desc,
      ));
    }
    return converted;
  }

  Map<String, List<MarketProductItem>> _buildShelvesFromProducts(
      List<MarketProductItem> products) {
    final Map<String, List<MarketProductItem>> shelves = {};
    if (products.isNotEmpty) {
      shelves['الأكثر مبيعًا'] = products.take(6).toList();

      for (final p in products) {
        final shelfName =
            p.mainCategory.isNotEmpty ? p.mainCategory : p.category;
        shelves.putIfAbsent(shelfName, () => []).add(p);
      }
    }
    return shelves;
  }

  void _prepopulateMarketProducts() {
    final int marketId = _effectiveMarketId;
    final marketsProv = _getMarketsProvider();
    final initialRaw = marketsProv.getCachedProducts(marketId);
    if (initialRaw != null && initialRaw.isNotEmpty) {
      final converted = _convertRawProducts(initialRaw);
      final shelves = _buildShelvesFromProducts(converted);
      _allMarketProducts = converted;
      _shelves = shelves;
      _isLoadingProducts = false;
      _updateCategoriesFromProducts(converted);
    } else {
      _allMarketProducts = [];
      _shelves = {};
      _allCategories = [];
      _isLoadingProducts = true;
    }
  }

  Future<void> _loadMarketData() async {
    if (_allMarketProducts.isEmpty) {
      setState(() {
        _isLoadingProducts = true;
      });
    }

    final int marketId = _effectiveMarketId;
    final rawProducts =
        await _getMarketsProvider().fetchMarketProducts(marketId);

    if (!mounted) return;

    if (rawProducts.isNotEmpty) {
      final converted = _convertRawProducts(rawProducts);
      final shelves = _buildShelvesFromProducts(converted);

      setState(() {
        _allMarketProducts = converted;
        _shelves = shelves;
        _isLoadingProducts = false;
        _updateCategoriesFromProducts(converted);
      });
      _syncCartFromProvider();
    } else {
      if (_allMarketProducts.isEmpty) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  static String? _nonEmpty(dynamic value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty || s == 'null' ? null : s;
  }

  /// Returns the product's own photo from the API, or '' so the card shows
  /// its neutral placeholder. AVIF is skipped because Flutter can't decode it.
  String _resolveProductImage(dynamic photos) {
    final pStr = (_nonEmpty(photos) ?? '').split(',').first.trim();
    if (pStr.isEmpty || pStr == 'null') return '';
    final lowerP = pStr.toLowerCase();
    if (lowerP.endsWith('.avif') || lowerP.contains('.avif?')) return '';
    if (pStr.startsWith('http') || pStr.startsWith('assets/')) return pStr;
    return GlobalVar.getImageUrl(pStr);
  }

  String _getCategoryAssetOrNetworkUrl(String title) {
    // 1. Check if category icon is uploaded in backend system categories
    try {
      if (locator.isRegistered<CategoriesProvider>()) {
        final uploadedIcon =
            locator<CategoriesProvider>().getIconForCategory(title);
        if (uploadedIcon != null &&
            uploadedIcon.isNotEmpty &&
            !uploadedIcon.startsWith('fas fa-')) {
          return GlobalVar.getImageUrl(uploadedIcon);
        }
      }
    } catch (_) {}

    final t = title.toLowerCase();
    if (t.contains('عروض') || t.contains('توفير')) {
      return 'assets/images/categories/offers.png';
    }
    if (t.contains('برغر') || t.contains('وجبات')) {
      return 'assets/images/categories/dish_burger.png';
    }
    if (t.contains('شاورما') || t.contains('مشويات')) {
      return 'assets/images/categories/dish_shawarma.png';
    }
    if (t.contains('فلافل') || t.contains('فطور')) {
      return 'assets/images/categories/dish_falafel.png';
    }
    if (t.contains('مونة') || t.contains('سوبرماركت') || t.contains('مقاضي')) {
      return 'assets/images/categories/mouneh.png';
    }
    if (t.contains('دجاج')) {
      return 'assets/images/categories/meat_poultry.png';
    }
    if (t.contains('لحوم') || t.contains('لحم')) {
      return 'assets/images/categories/meat_poultry.png';
    }
    if (t.contains('حلويات') || t.contains('حلو') || t.contains('سويت')) {
      return 'assets/images/categories/sweets_desserts.png';
    }
    if (t.contains('خضار') || t.contains('فواكه')) {
      return 'assets/images/categories/vegetables.png';
    }
    if (t.contains('مخبوز') || t.contains('خبز')) {
      return 'assets/images/categories/bakery.png';
    }
    if (t.contains('ألبان') ||
        t.contains('أجبان') ||
        t.contains('اجبان') ||
        t.contains('بيض') ||
        t.contains('حليب')) {
      return 'assets/images/categories/dairy_cheese.png';
    }
    if (t.contains('توابل') || t.contains('بقول')) {
      return 'assets/images/categories/legumes_grains.png';
    }
    if (t.contains('غذائ')) {
      return 'assets/images/categories/mouneh.png';
    }
    if (t.contains('مشروب') || t.contains('عصير') || t.contains('بيبسي')) {
      return 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=200&q=80';
    }
    if (t.contains('سناك') ||
        t.contains('نقرش') ||
        t.contains('شيبس') ||
        t.contains('بسكوت')) {
      return 'https://images.unsplash.com/photo-1582293041079-7814c2f12063?auto=format&fit=crop&w=200&q=80';
    }
    if (t.contains('قهوة') || t.contains('شاي')) {
      return 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=200&q=80';
    }
    if (t.contains('منظف') || t.contains('غسيل')) {
      return 'https://images.unsplash.com/photo-1583947215259-38e31be8751f?auto=format&fit=crop&w=200&q=80';
    }
    if (t.contains('عناية') || t.contains('شخصية')) {
      return 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?auto=format&fit=crop&w=200&q=80';
    }
    if (t.contains('مثلج') ||
        t.contains('مجمد') ||
        t.contains('فريزر') ||
        t.contains('آيس كريم') ||
        t.contains('ايس كريم')) {
      return 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=200&q=80';
    }
    return 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=200&q=80';
  }

  IconData _getCategoryFallbackIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('فواكه') ||
        t.contains('خضار') ||
        t.contains('خضروات') ||
        t.contains('طازج')) {
      return Icons.eco_rounded;
    }
    if (t.contains('خبز') || t.contains('مخبوز') || t.contains('معجنات')) {
      return Icons.bakery_dining_rounded;
    }
    if (t.contains('دجاج')) {
      return Icons.restaurant_rounded;
    }
    if (t.contains('لحم') || t.contains('لحوم') || t.contains('سمك')) {
      return Icons.set_meal_rounded;
    }
    if (t.contains('لبن') ||
        t.contains('ألبان') ||
        t.contains('جبن') ||
        t.contains('أجبان') ||
        t.contains('بيض')) {
      return Icons.egg_rounded;
    }
    if (t.contains('مشروب') ||
        t.contains('عصير') ||
        t.contains('ماء') ||
        t.contains('مياه')) {
      return Icons.local_drink_rounded;
    }
    if (t.contains('قهوة') || t.contains('شاي') || t.contains('كافيه')) {
      return Icons.coffee_rounded;
    }
    if (t.contains('سناك') ||
        t.contains('شيبس') ||
        t.contains('بسكوت') ||
        t.contains('حلويات')) {
      return Icons.cookie_rounded;
    }
    if (t.contains('مثلج') || t.contains('مجمد') || t.contains('آيس كريم')) {
      return Icons.ac_unit_rounded;
    }
    if (t.contains('توابل') ||
        t.contains('بهار') ||
        t.contains('صلصة') ||
        t.contains('زيت')) {
      return Icons.soup_kitchen_rounded;
    }
    if (t.contains('تنظيف') || t.contains('منظف') || t.contains('غسيل')) {
      return Icons.cleaning_services_rounded;
    }
    if (t.contains('عناية') || t.contains('صحة') || t.contains('جمال')) {
      return Icons.soap_rounded;
    }
    if (t.contains('أطفال') || t.contains('طفل')) {
      return Icons.child_care_rounded;
    }
    if (t.contains('مونة') || t.contains('معلب') || t.contains('بقول')) {
      return Icons.inventory_2_rounded;
    }
    if (t.contains('عروض') || t.contains('توفير')) {
      return Icons.local_offer_rounded;
    }
    return Icons.shopping_bag_outlined;
  }

  @override
  void initState() {
    super.initState();
    try {
      HttpOverrides.global = _MarketHttpOverrides();
    } catch (_) {}
    _categoryScrollController.addListener(_onCategoryScroll);
    _initStoreModel();
    _initBanners();
    // Instant Pre-population (0ms frame-0 rendering)
    _prepopulateMarketProducts();

    // Fetch dynamic categories and products from live backend
    _loadMarketData();
  }

  void _initBanners() {
    if (locator.isRegistered<InitialDataProvider>()) {
      final initialData = locator<InitialDataProvider>();
      final preloaded = initialData.marketBanners;
      if (preloaded.isNotEmpty) {
        _marketBanners = List.from(preloaded);
      }
    }
    unawaited(_fetchLiveMarketBanners());
  }

  Future<void> _fetchLiveMarketBanners() async {
    try {
      if (!locator.isRegistered<SolApi>()) return;
      final api = locator<SolApi>();
      final res = await api.getRequest('/Banner/3');
      List items = [];
      if (res is List) {
        items = res;
      } else if (res is Map && res['data'] is List) {
        items = res['data'];
      } else if (res is Map && res['items'] is List) {
        items = res['items'];
      }

      if (items.isNotEmpty) {
        final List<BannerModel> fetched = [];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            fetched.add(BannerModel.fromMap(item));
          } else if (item is Map) {
            fetched.add(BannerModel.fromMap(Map<String, dynamic>.from(item)));
          }
        }
        if (mounted && fetched.isNotEmpty) {
          setState(() {
            _marketBanners = fetched;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching live market banners: $e');
    }
  }

  void _handleBannerTap(BannerModel banner) async {
    final rawUrl = (banner.url ?? '').trim();
    if (rawUrl.isEmpty) return;

    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      final uri = Uri.tryParse(rawUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final cleanUrl = rawUrl.split('#').first.trim();
    if (cleanUrl.startsWith('restaurant:')) {
      final id = int.tryParse(cleanUrl.split(':').last);
      if (id != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantMenuPage(
              restaurantId: id,
              restaurantName: banner.title ?? 'المطعم',
            ),
          ),
        );
        return;
      }
    } else if (cleanUrl.startsWith('merchant:') ||
        cleanUrl.startsWith('market:')) {
      final id = int.tryParse(cleanUrl.split(':').last);
      if (id != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketPage(
              marketId: id,
              marketName: banner.title ?? 'المتجر',
            ),
          ),
        );
        return;
      }
    }
  }

  Widget _buildMarketBannersSection() {
    if (_marketBanners.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _marketBanners.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final banner = _marketBanners[index];
          final rawImg = (banner.featuredImage ?? '').trim();
          final fullUrl = rawImg.startsWith('http')
              ? rawImg
              : (rawImg.startsWith('assets')
                  ? rawImg
                  : GlobalVar.getImageUrl(rawImg,
                      width: 600, height: 600, crop: false));

          return GestureDetector(
            onTap: () => _handleBannerTap(banner),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: fullUrl.startsWith('assets')
                    ? Image.asset(
                        fullUrl,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        imageUrl: fullUrl,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFF1F5F9),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onCategoryScroll() {
    if (!_categoryScrollController.hasClients) return;
    final maxScroll = _categoryScrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      final progress =
          (_categoryScrollController.offset / maxScroll).clamp(0.0, 1.0);
      if (progress != _categoryScrollProgress) {
        setState(() {
          _categoryScrollProgress = progress;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.removeListener(_onCategoryScroll);
    _categoryScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketDisplayName = _currentMarketName;
    final double collapseProgress =
        (_headerScrollOffset / _kHeaderCollapseRange).clamp(0.0, 1.0);

    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(overscroll: false),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Header & Morphing Search Bar
              _buildTopHeader(marketDisplayName, collapseProgress),

              // 2. Main Scrollable Market Feed & Floating Interactive Bottom Delivery Bar
              Expanded(
                child: Stack(
                  children: [
                    // Main Feed with Scroll Notification Listener (Vertical Axis Only)
                    NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        if (notification.metrics.axis == Axis.vertical) {
                          final currentPixels = notification.metrics.pixels;
                          final newHeaderOffset =
                              currentPixels.clamp(0.0, _kHeaderCollapseRange);
                          if (newHeaderOffset != _headerScrollOffset) {
                            setState(() {
                              _headerScrollOffset = newHeaderOffset;
                            });
                          }
                          if (notification is ScrollUpdateNotification) {
                            final delta = notification.scrollDelta ?? 0.0;
                            if (delta != 0.0) {
                              final newOffset = (_bottomBarOffset + delta)
                                  .clamp(0.0, _maxBottomBarHeight);
                              if (newOffset != _bottomBarOffset) {
                                setState(() {
                                  _bottomBarOffset = newOffset;
                                });
                              }
                            }
                          }
                        }
                        return false;
                      },
                      child: ListView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(
                          bottom: _maxBottomBarHeight + 24,
                        ),
                        children: [
                          const SizedBox(height: 12),

                          // Keep skeleton effect on ALL elements until everything is fetched successfully
                          if (_isLoadingProducts)
                            _buildShelvesSkeleton()
                          else ...[
                            // Dynamic Market Banners (Controlled from Dashboard: Placement = Market Page)
                            if (_marketBanners.isNotEmpty) ...[
                              _buildMarketBannersSection(),
                              const SizedBox(height: 16),
                            ],

                            // "تسوق حسب الفئة" Continuous Horizontal Grid with Slider
                            if (_allCategories.isNotEmpty) ...[
                              _buildShopByCategorySection(),
                              const SizedBox(height: 20),
                            ],

                            // Dynamic Product Shelves or Empty State
                            if (_shelves.isNotEmpty) ...[
                              for (final entry in _shelves.entries) ...[
                                _buildProductShelf(
                                  title: entry.key,
                                  products: entry.value,
                                ),
                                const SizedBox(height: 24),
                              ],
                            ] else
                              _buildEmptyProductsState(),
                          ],

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),

                    // Floating Interactive Bottom Delivery / Cart Bar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Transform.translate(
                        offset: Offset(0, _bottomBarOffset),
                        child: _buildBottomDeliveryBar(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Top Header & Search (Morphing Scroll Animation & Real Market Logo)
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader(String marketName, double collapseProgress) {
    final double headerHeight = 114.0 - (56.0 * collapseProgress);
    final double titleOpacity = (1.0 - collapseProgress * 2.5).clamp(0.0, 1.0);
    final double titleShift = -25.0 * collapseProgress;

    // Search bar interpolation:
    // EaseOutQuart on start ensures searchbar clears back button width early before rising
    final double startCurve = Curves.easeOutQuart.transform(collapseProgress);
    final double topCurve = Curves.easeInOutCubic.transform(collapseProgress);

    // Target start 74.0 leaves a generous 16px margin from the back button (start 16 + width 42 + 16 = 74)
    final double searchStart = 16.0 + ((74.0 - 16.0) * startCurve);
    final double searchTop = 60.0 - (52.0 * topCurve);
    final double searchHeight = 46.0 - (4.0 * collapseProgress);

    return Container(
      height: headerHeight,
      width: double.infinity,
      color: Colors.white,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Circular Back Button (Fixed at Start: start 16, top 8, size 42x42)
            PositionedDirectional(
              start: 16,
              top: 8,
              width: 42,
              height: 42,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  child: const Center(
                    child: JtakBackIcon(size: 20),
                  ),
                ),
              ),
            ),

            // 2. Store Logo + Store Name (Fades out and shifts left smoothly as user scrolls)
            if (titleOpacity > 0.0)
              PositionedDirectional(
                start: 74,
                end: 16,
                top: 8,
                height: 42,
                child: IgnorePointer(
                  ignoring: titleOpacity < 0.5,
                  child: Opacity(
                    opacity: titleOpacity,
                    child: Transform.translate(
                      offset: Offset(titleShift, 0),
                      child: Row(
                        children: [
                          // Store Logo Squircle
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEEEE),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                  color: const Color(0xFFE2E8F0), width: 1.0),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildStoreLogoWidget(
                                  marketName, widget.logoUrl),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Store Name
                          Expanded(
                            child: Text(
                              marketName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: kCharcoalDark,
                                fontSize: 18.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Search Input Pill (Smoothly slides up beside the back button)
            PositionedDirectional(
              start: searchStart,
              end: 16,
              top: searchTop,
              height: searchHeight,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarketSearchPage(
                        marketId: _effectiveMarketId,
                        marketName: marketName,
                        logoUrl: widget.logoUrl,
                        products: _allMarketProducts,
                        initialCartQuantities: {
                          for (final p in _allMarketProducts)
                            if (locator<CartProvider>().getProductQuantity(p.id) > 0)
                              p.id: locator<CartProvider>().getProductQuantity(p.id)
                        },
                      ),
                    ),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: searchHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: const Color(0xFFE5E7EB), width: 1.1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const JtakSearchIcon(
                        color: Color(0xFF9CA3AF),
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ابحث عن منتجات...',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFF9CA3AF),
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreLogoWidget(String marketName, String? logoUrl) {
    // 1. Explicit network logo URL
    final candidateLogo = (logoUrl != null && logoUrl.trim().isNotEmpty)
        ? logoUrl.trim()
        : (_storeModel?.logoUrl ?? '');
    if (candidateLogo.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: candidateLogo,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, __, ___) => _buildStoreBrandedBadge(marketName),
      );
    }

    // 2. Local asset logo (e.g. JTAK Market, Shamsin)
    final assetPath =
        _storeModel?.assetPath ?? _resolveMarketAssetByName(marketName);
    if (assetPath != null && assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildStoreBrandedBadge(marketName),
      );
    }

    // 3. Branded identity badge (e.g. Clover Mall emerald green badge, Best Market blue badge)
    return _buildStoreBrandedBadge(marketName);
  }

  String? _resolveMarketAssetByName(String name) {
    final n = name.trim().toLowerCase();
    if (n.contains('best') || n.contains('بست')) {
      return 'assets/images/markets/best_market.webp';
    }
    if (n.contains('clover') || n.contains('كلوفر')) {
      return 'assets/images/markets/clover_mall.webp';
    }
    if (n.contains('جيتك') || n.contains('جتاك') || n.contains('jtak')) {
      return 'assets/images/markets/jtak_market.webp';
    }
    if (n.contains('شمسين')) {
      return 'assets/images/markets/abnaa_shamsin.webp';
    }
    if (n.contains('قاسيون')) {
      return 'assets/images/markets/qasioun_hypermarket.webp';
    }
    if (n.contains('الهدى') || n.contains('هدى')) {
      return 'assets/images/markets/al_huda.webp';
    }
    if (n.contains('البركة') || n.contains('بركة')) {
      return 'assets/images/markets/al_baraka.webp';
    }
    if (n.contains('الدوحة') || n.contains('دوحة')) {
      return 'assets/images/markets/al_dawha.webp';
    }
    return null;
  }

  Widget _buildStoreBrandedBadge(String marketName) {
    final color = _storeModel?.logoColor ?? const Color(0xFF047857);
    final text =
        _storeModel?.logoText ?? (marketName.isNotEmpty ? marketName[0] : 'J');
    final boxed = _storeModel?.logoBoxedText;

    return Container(
      color: color,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: GoogleFonts.ibmPlexSansArabic(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          if (boxed != null && boxed.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                boxed,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. "تسوق حسب الفئة" Continuous Horizontal Grid with Moving Slider Pill
  // ---------------------------------------------------------------------------
  Widget _buildShopByCategorySection() {
    if (_allCategories.isEmpty) return const SizedBox.shrink();

    final bool isSingleRow = _allCategories.length <= 6;
    final double gridHeight = isSingleRow ? 120.0 : 238.0;
    final int crossAxisCount = isSingleRow ? 1 : 2;
    final double childAspectRatio = isSingleRow ? 1.30 : 1.28;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'تسوق حسب الفئة',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Continuous Horizontal Grid of Main Categories (Single row if <= 6, 2-row grid if > 6)
        SizedBox(
          height: gridHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification.metrics.axis == Axis.horizontal &&
                  notification.metrics.maxScrollExtent > 0) {
                final p = (notification.metrics.pixels /
                        notification.metrics.maxScrollExtent)
                    .clamp(0.0, 1.0);
                if (p != _categoryScrollProgress) {
                  setState(() {
                    _categoryScrollProgress = p;
                  });
                }
              }
              return true; // Stop bubbling to outer vertical scroll listener
            },
            child: GridView.builder(
              controller: _categoryScrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 2,
                mainAxisSpacing: 4,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: _allCategories.length,
              itemBuilder: (context, index) {
                return _buildCategoryItem(_allCategories[index]);
              },
            ),
          ),
        ),

        if (_allCategories.length > 4) ...[
          const SizedBox(height: 8),

          // Moving Progress Bar Indicator (The 36px black pill smoothly glides across the 78px track)
          Center(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                width: 78,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: (1.0 - _categoryScrollProgress) * (78.0 - 36.0),
                      top: 0,
                      bottom: 0,
                      width: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kCharcoalDark,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryItem(MarketCategoryItem cat) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketCategoryProductsPage(
              marketId: _effectiveMarketId,
              marketName: _currentMarketName,
              selectedMainCategory: cat.title,
              allMarketProducts: _allMarketProducts,
              logoUrl: widget.logoUrl,
            ),
          ),
        ).then((_) {
          if (mounted) _syncCartFromProvider();
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Squircle Category Photo Container
          Container(
            width: 80,
            height: 80,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
            ),
            child: cat.imageUrl.startsWith('assets')
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      cat.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          cat.fallbackIcon,
                          color: kPrimaryOrange,
                          size: 28,
                        ),
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: cat.imageUrl,
                    fit: BoxFit.contain,
                    imageBuilder: (context, imageProvider) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image(
                        image: imageProvider,
                        fit: BoxFit.contain,
                      ),
                    ),
                    placeholder: (context, url) => const CleanShimmer(
                      child: SizedBox.expand(
                        child: ColoredBox(color: Colors.white),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Center(
                      child: Icon(
                        cat.fallbackIcon,
                        color: kPrimaryOrange,
                        size: 28,
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 3),

          // Category Title
          SizedBox(
            width: 92,
            height: 33,
            child: Text(
              cat.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: GoogleFonts.ibmPlexSansArabic(
                color: const Color(0xFF1F2937),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Product Shelf / Carousel (Screenshots 1, 3, 4)
  // ---------------------------------------------------------------------------
  Widget _buildProductShelf({
    required String title,
    required List<MarketProductItem> products,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shelf Header: Title & "عرض الكل <"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () {
                  final targetCat = title == 'الأكثر مبيعًا'
                      ? (_allCategories.isNotEmpty
                          ? _allCategories.first.title
                          : 'منتجات عامة')
                      : title;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarketCategoryProductsPage(
                        marketId: _effectiveMarketId,
                        marketName: _currentMarketName,
                        selectedMainCategory: targetCat,
                        allMarketProducts: _allMarketProducts,
                        logoUrl: widget.logoUrl,
                      ),
                    ),
                  ).then((_) {
                    if (mounted) _syncCartFromProvider();
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsRegular.caretLeft,
                        color: kPrimaryOrange,
                        size: 16,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'عرض الكل',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kPrimaryOrange,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Horizontal Product List (3 products per screen width)
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShelvesSkeleton() {
    return const MarketPageSkeleton();
  }

  Widget _buildEmptyProductsState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 64,
              color: Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحديث منتجات المتجر...',
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يقوم المتجر بإضافة تشكيلة جديدة من المنتجات والأسعار حالياً',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                color: const Color(0xFF6B7280),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadMarketData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'إعادة المحاولة',
                style:
                    GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openProductDetail(MarketProductItem product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketProductDetailPage(
          product: product,
          marketId: _effectiveMarketId,
          marketName: _currentMarketName,
          allMarketProducts: _allMarketProducts,
          initialQuantity:
              locator<CartProvider>().getProductQuantity(product.id),
          totalCartCount: locator<CartProvider>().totalQuantity,
        ),
      ),
    );
  }

  Widget _buildProductCard(MarketProductItem product) {
    return MarketProductCard(
      product: product,
      marketId: _effectiveMarketId,
      onProductTap: () => _openProductDetail(product),
      onPlusTap: () => _onPlusTapped(product.id),
      onMinusTap: () => _onMinusTapped(product.id),
      width: 124,
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Persistent Bottom Minimum Order / Active Cart Bar (Screenshots 1 - 4)
  // ---------------------------------------------------------------------------
  Widget _buildBottomDeliveryBar() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final count = cart.totalQuantity;
        if (count == 0) {
          return const SizedBox.shrink();
        }

        final int total = cart.subtotal.toInt();
        final storeSubtotal =
            cart.getSubtotalForMerchant(_effectiveMarketId).toInt();
        final storeMinOrder = cart.getMinOrderForMerchant(_effectiveMarketId);
        final target = storeMinOrder > 0 ? storeMinOrder : _minOrderTarget;
        final progress =
            target > 0 ? (storeSubtotal / target).clamp(0.0, 1.0) : 1.0;
        final remaining = (target - storeSubtotal).clamp(0, 999999999);
        final bool reachedMin = storeSubtotal >= target;

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
          ),
          padding: EdgeInsets.fromLTRB(16, reachedMin ? 12 : 10, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Minimum Order Notice & Progress Line (Collapses when threshold is reached)
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                child: !reachedMin
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Minimum Order Notice & Lock Icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'أضف منتجات بقيمة ${_formatPrice(remaining)} ل.س إلى طلبك!',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: const Color(0xFF111827),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.lock_rounded,
                                color: Color(0xFF1F2937),
                                size: 16,
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // 2. Minimum Order Progress Line (RTL Directional Active Bar)
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final totalWidth = constraints.maxWidth;
                                final fillWidth = totalWidth * progress;

                                return Stack(
                                  children: [
                                    // Background track
                                    Container(
                                      width: totalWidth,
                                      height: 3.5,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    // Active filled track (from right side in RTL)
                                    Positioned(
                                      right: 0,
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 350),
                                        curve: Curves.easeOutCubic,
                                        width: fillWidth,
                                        height: 3.5,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1F2937),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 10),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              // 3. Orange "عرض السلة" Pill Button (Clean modern button, zero orange glow)
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, CartPage.routeName);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: kPrimaryOrange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Right Side in RTL: Dark Quantity Badge + "عرض السلة"
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0x38000000),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: _AnimatedCounterText(
                                  count: count,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'عرض السلة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),

                        // Left Side in RTL: Total Price
                        Text(
                          '${_formatPrice(total)} ل.س',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// Animated Counter Text (Smooth Vertical Slide Up / Down Ticker)
/// ---------------------------------------------------------------------------
class _AnimatedCounterText extends StatefulWidget {
  final int count;
  final TextStyle style;

  const _AnimatedCounterText({
    required this.count,
    required this.style,
  });

  @override
  State<_AnimatedCounterText> createState() => _AnimatedCounterTextState();
}

class _AnimatedCounterTextState extends State<_AnimatedCounterText>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;
  int _currentCount = 0;
  int _prevCount = 0;
  bool _isIncreasing = true;

  void _ensureInitialized() {
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _animation ??= CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentCount = widget.count;
    _prevCount = widget.count;
    _ensureInitialized();
  }

  @override
  void didUpdateWidget(covariant _AnimatedCounterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureInitialized();
    if (oldWidget.count != widget.count) {
      _prevCount = oldWidget.count;
      _currentCount = widget.count;
      _isIncreasing = _currentCount >= _prevCount;
      _controller?.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialized();

    final double textHeight =
        (widget.style.fontSize ?? 15.0) * (widget.style.height ?? 1.25);
    final double slotHeight = textHeight.clamp(20.0, 32.0);

    return SizedBox(
      width: 32,
      height: slotHeight,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _animation!,
          builder: (context, child) {
            final controller = _controller!;
            // When not animating or idle
            if (!controller.isAnimating || _prevCount == _currentCount) {
              return Center(
                child: Text(
                  '$_currentCount',
                  style: widget.style,
                  textAlign: TextAlign.center,
                ),
              );
            }

            final t = _animation!.value;

            if (_isIncreasing) {
              // Increasing: continuous strip [Top: _prevCount, Bottom: _currentCount] scrolling UP
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Top Number (_prevCount) moving from 0 to -slotHeight
                  Positioned(
                    top: -t * slotHeight,
                    left: 0,
                    right: 0,
                    height: slotHeight,
                    child: Center(
                      child: Text(
                        '$_prevCount',
                        style: widget.style,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Bottom Number (_currentCount) moving from +slotHeight to 0
                  Positioned(
                    top: (1.0 - t) * slotHeight,
                    left: 0,
                    right: 0,
                    height: slotHeight,
                    child: Center(
                      child: Text(
                        '$_currentCount',
                        style: widget.style,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Decreasing: continuous strip [Top: _currentCount, Bottom: _prevCount] scrolling DOWN
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Top Number (_currentCount) moving from -slotHeight to 0
                  Positioned(
                    top: -(1.0 - t) * slotHeight,
                    left: 0,
                    right: 0,
                    height: slotHeight,
                    child: Center(
                      child: Text(
                        '$_currentCount',
                        style: widget.style,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Bottom Number (_prevCount) moving from 0 to +slotHeight
                  Positioned(
                    top: t * slotHeight,
                    left: 0,
                    right: 0,
                    height: slotHeight,
                    child: Center(
                      child: Text(
                        '$_prevCount',
                        style: widget.style,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

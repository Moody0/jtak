import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app_parameters_provider.dart';
import '../../../core/controllers/app/app_state_manager.dart';
import '../../../core/controllers/catalog/markets_provider.dart';
import '../../../core/controllers/initial_data_provider.dart';
import '../../../core/models/catalog/restaurant_category_model.dart';
import '../../../core/controllers/order/order_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../../core/models/banner_model.dart';
import '../../../core/models/user/address_model.dart';
import '../../../core/services/locator.dart';
import '../../../utils/providers/sol_api.dart';
import '../../widgets/catalog/restaurant_card_widget.dart';
import '../../widgets/clean_shimmer_skeletons.dart';
import '../../widgets/header_circle_button.dart';
import '../../widgets/top_app_bar_widget.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../../utils/utilities/global_var.dart';
import 'package:url_launcher/url_launcher.dart';
import 'catalog_scope.dart';
import 'favorite_page.dart';
import 'market_page.dart';
import 'restaurant_menu_page.dart';
import 'search_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Restaurants List Page (Exact Match to User's Specifications)
///
/// Features:
/// 1. Pinned Sticky Top Navigation Row: Back Button + 50% Width Address + Heart Button
/// 2. Floating / Snapping Search Bar (disappears on scroll down, appears from top on scroll up)
/// 3. Section 1: Square Promo Ads Carousel (انتعاش الصيف, حلاوة المولد, اكتشف الجديد 30% خصم)
/// 4. Section 2: "اطلب من جديد" (Order Again Clean Squircles without overlay badges)
/// 5. Section 3: "كل المطاعم" (All Restaurant Categories Circular Dish Avatars)
/// 6. Section 4: Filter Pills Row (↓↑ رتب حسب, عروض, تقييم 4.0+, 🚀 سريع, الأقرب لك, تصفية)
/// 7. Section 5: Vertical Feed of Restaurant Cards
/// ---------------------------------------------------------------------------

class RestaurantsListPage extends StatefulWidget {
  static const String routeName = '/RestaurantsListPage';

  final String? initialFilter;
  final CatalogScope? catalogScope;

  /// Restricts the list to merchants of one kind, matching the backend
  /// MerchantKind values. Supplied by a Home tile the admin pointed at a
  /// merchant type rather than at a product category.
  final int? merchantKind;

  /// Header wording for that case, so the page does not have to guess a name
  /// for the kind it is showing.
  final String? title;

  const RestaurantsListPage({
    super.key,
    this.initialFilter,
    this.catalogScope,
    this.merchantKind,
    this.title,
  });

  @override
  State<RestaurantsListPage> createState() => _RestaurantsListPageState();
}

class _RestaurantsListPageState extends State<RestaurantsListPage>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'الكل';
  String _selectedSort = 'رتب حسب';
  bool _filterOffers = false;
  bool _filterRating4 = false;
  bool _filterFast = false;
  bool _filterNearest = false;
  bool _filterFreeDelivery = false;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<_RestaurantListItem>? _scopedMerchants;
  final Map<int, Set<String>> _merchantProductCategories = {};
  final Map<String, String?> _scopeCategoryImages = {};
  bool _isLoadingScopedMerchants = false;
  List<BannerModel> _restaurantBanners = [];
  List<Map<String, dynamic>> _orderAgainList = [];
  RestaurantCategoriesConfigModel? _restaurantCategoriesConfig;

  late final AnimationController _searchAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1.0,
  );

  late final Animation<Offset> _searchSlideAnim = Tween<Offset>(
    begin: const Offset(0.0, -1.0),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _searchAnimController,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  ));

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null && widget.initialFilter!.isNotEmpty) {
      if (widget.initialFilter == 'عروض' ||
          widget.initialFilter == 'عروض خاصة') {
        _filterOffers = true;
        _selectedCategory = 'الكل';
      } else {
        _selectedCategory = widget.initialFilter!;
      }
    }
    if (widget.catalogScope != null) {
      unawaited(_loadScopedMerchants());
    }
    _initBanners();
    if (widget.catalogScope == null) {
      unawaited(_initRestaurantCategories());
    }
    unawaited(_initOrderAgain());
  }

  Future<void> _initRestaurantCategories() async {
    try {
      if (!locator.isRegistered<SolApi>()) return;
      final response =
          await locator<SolApi>().getRequest('/RestaurantCategories');
      Map<String, dynamic>? data;
      if (response is Map<String, dynamic>) {
        data = response;
      } else if (response is Map) {
        data = Map<String, dynamic>.from(response);
      }
      if (data == null) return;
      final config = RestaurantCategoriesConfigModel.fromMap(data);
      if (!mounted) return;
      setState(() => _restaurantCategoriesConfig = config);
    } catch (e) {
      // Keep the bundled defaults when the endpoint is unavailable/offline.
      debugPrint('Error fetching restaurant categories: $e');
    }
  }

  void _initBanners() {
    if (locator.isRegistered<InitialDataProvider>()) {
      final initialData = locator<InitialDataProvider>();
      final preloaded = initialData.restaurantBanners;
      if (preloaded.isNotEmpty) {
        _restaurantBanners = List.from(preloaded);
      }
    }
    unawaited(_fetchLiveRestaurantBanners());
  }

  Future<void> _fetchLiveRestaurantBanners() async {
    try {
      if (!locator.isRegistered<SolApi>()) return;
      final api = locator<SolApi>();
      final res = await api.getRequest('/Banner/2');
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
            _restaurantBanners = fetched;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching live restaurant banners: $e');
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

  Future<void> _initOrderAgain() async {
    _populateOrderAgain();
    try {
      final orderProv = locator.isRegistered<OrderProvider>()
          ? locator<OrderProvider>()
          : OrderProvider.instance;
      if (orderProv != null) {
        if (orderProv.dataList.isEmpty) {
          await orderProv.loadPagedData();
        }
        if (mounted) {
          _populateOrderAgain();
        }
      }
    } catch (e) {
      debugPrint('Error loading past orders for order again: $e');
    }
  }

  void _populateOrderAgain() {
    final orderProv = locator.isRegistered<OrderProvider>()
        ? locator<OrderProvider>()
        : OrderProvider.instance;
    if (orderProv == null) return;

    final orders = orderProv.dataList;
    if (orders.isEmpty) {
      if (_orderAgainList.isNotEmpty && mounted) {
        setState(() => _orderAgainList = []);
      }
      return;
    }

    final marketsProv = locator.isRegistered<MarketsProvider>()
        ? locator<MarketsProvider>()
        : null;

    final List<int> seenMerchantIds = [];
    final List<Map<String, dynamic>> resolvedList = [];

    for (final order in orders) {
      if (order.orderDetails == null) continue;
      for (final detail in order.orderDetails!) {
        final mId = detail.merchantId;
        if (mId == null || mId <= 0 || seenMerchantIds.contains(mId)) {
          continue;
        }

        // 1. Try finding in restaurants
        final rest =
            marketsProv?.restaurants.cast<RestaurantStoreModel?>().firstWhere(
                  (r) => r?.id == mId,
                  orElse: () => null,
                );

        if (rest != null) {
          seenMerchantIds.add(mId);
          resolvedList.add({
            'id': rest.id,
            'name': rest.name,
            'logoUrl': rest.logoUrl,
            'coverUrl': rest.coverUrl,
            'isProductMerchant': false,
          });
          continue;
        }

        // 2. Try finding in markets
        final market =
            marketsProv?.markets.cast<MarketStoreModel?>().firstWhere(
                  (m) => m?.id == mId,
                  orElse: () => null,
                );

        if (market != null) {
          seenMerchantIds.add(mId);
          resolvedList.add({
            'id': market.id,
            'name': market.name,
            'logoUrl': market.logoUrl ?? market.assetPath ?? '',
            'coverUrl': market.assetPath ?? market.logoUrl ?? '',
            'isProductMerchant': true,
          });
          continue;
        }

        // 3. Fallback to order detail info
        final merchantTitle = (detail.merchantTitle ?? '').trim();
        if (merchantTitle.isNotEmpty) {
          seenMerchantIds.add(mId);
          resolvedList.add({
            'id': mId,
            'name': merchantTitle,
            'logoUrl': detail.productImage ?? '',
            'coverUrl': detail.productImage ?? '',
            'isProductMerchant': false,
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _orderAgainList = resolvedList;
      });
    }
  }

  @override
  void dispose() {
    _searchAnimController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadScopedMerchants() async {
    final scope = widget.catalogScope;
    if (scope == null || !locator.isRegistered<MarketsProvider>()) return;

    setState(() => _isLoadingScopedMerchants = true);
    final provider = locator<MarketsProvider>();
    final categoryMerchants = await provider.fetchMerchantsForCategory(
      scope.categoryId,
      scope.merchantKind,
    );
    final candidates = categoryMerchants.isNotEmpty
        ? _buildMarketMerchants(categoryMerchants)
        : _buildProviderMerchants(provider, includeMarkets: true);
    final matched = <_RestaurantListItem>[];

    await Future.wait(candidates.map((merchant) async {
      final products = await provider.fetchMarketProducts(merchant.id);
      final categories = <String>{};
      var belongsToScope = false;

      for (final product in products) {
        final parentId = int.tryParse(
          (product['categoryParentId'] ?? '').toString(),
        );
        final parentTitle = (product['productCat2'] ?? '').toString().trim();
        final childTitle = (product['productCat1'] ?? '').toString().trim();
        final matchesParent = parentId == scope.categoryId ||
            _sameCategory(parentTitle, scope.title);

        if (!matchesParent) continue;
        belongsToScope = true;
        if (childTitle.isNotEmpty) {
          categories.add(childTitle);
          _scopeCategoryImages.putIfAbsent(
            childTitle,
            () => _firstProductImage(product),
          );
        }
      }

      if (belongsToScope) {
        matched.add(merchant);
        _merchantProductCategories[merchant.id] = categories;
      }
    }));

    // The bundled grocery merchants remain useful while the API is offline.
    if (matched.isEmpty && scope.kind == CatalogScopeKind.grocery) {
      matched
          .addAll(candidates.where((merchant) => merchant.isProductMerchant));
    }

    if (!mounted) return;
    matched.sort((a, b) => b.rating.compareTo(a.rating));
    setState(() {
      _scopedMerchants = matched;
      _isLoadingScopedMerchants = false;
    });
  }

  bool _sameCategory(String first, String second) {
    String normalize(String value) => value
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^ال'), '')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    final a = normalize(first);
    final b = normalize(second);
    return a.isNotEmpty &&
        b.isNotEmpty &&
        (a == b || a.contains(b) || b.contains(a));
  }

  String? _firstProductImage(Map<String, dynamic> product) {
    final icon = (product['categoryIcon'] ?? '').toString().trim();
    if (icon.isNotEmpty) return icon;
    final photos = (product['productPhotos'] ?? '').toString().trim();
    if (photos.isEmpty) return null;
    return photos.split(',').first.trim();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedSort != 'رتب حسب') count++;
    if (_filterOffers) count++;
    if (_filterRating4) count++;
    if (_filterFast) count++;
    if (_filterNearest) count++;
    if (_filterFreeDelivery) count++;
    return count;
  }

  bool _isCategorySelected(String catTitle) {
    if (_selectedCategory == catTitle) return true;
    if (_selectedCategory == 'الكل') return false;
    final a = _selectedCategory.replaceAll('ال', '').trim().toLowerCase();
    final b = catTitle.replaceAll('ال', '').trim().toLowerCase();
    return a == b;
  }

  String _categoryFilterTag(String title) {
    final configured = _restaurantCategoriesConfig;
    if (configured == null) return title;
    for (final item in configured.items) {
      if (_sameCategory(item.title, title) ||
          _sameCategory(item.titleEn ?? '', title)) {
        final tag = item.filterTag.trim();
        return tag.isEmpty ? title : tag;
      }
    }
    return title;
  }

  String _categoryDisplayTitle(RestaurantCategoryModel item) {
    final isArabic = !locator.isRegistered<AppStateManager>() ||
        locator<AppStateManager>().appLanguageIsArabic;
    if (!isArabic && (item.titleEn ?? '').trim().isNotEmpty) {
      return item.titleEn!.trim();
    }
    return item.title;
  }

  String _sectionDisplayTitle(RestaurantCategoriesConfigModel config) {
    final isArabic = !locator.isRegistered<AppStateManager>() ||
        locator<AppStateManager>().appLanguageIsArabic;
    if (!isArabic && config.sectionTitleEn.trim().isNotEmpty) {
      return config.sectionTitleEn.trim();
    }
    return config.sectionTitle;
  }

  bool _matchesCategory(_RestaurantListItem r, String category) {
    if (category == 'الكل' || category.trim().isEmpty) return true;

    final target = category.trim().toLowerCase();
    final tag = r.categoryTag.trim().toLowerCase();
    final cuisine = r.cuisine.trim().toLowerCase();
    final name = r.name.trim().toLowerCase();

    // Direct equality or substring match
    if (tag == target || cuisine == target || name == target) return true;
    if (tag.contains(target) || target.contains(tag)) return true;
    if (cuisine.contains(target) || target.contains(cuisine)) return true;
    if (name.contains(target)) return true;

    // 1. Burgers
    if (target.contains('برجر') ||
        target.contains('برغر') ||
        target.contains('burger')) {
      return tag.contains('برغر') ||
          tag.contains('برجر') ||
          cuisine.contains('برغر') ||
          cuisine.contains('برجر') ||
          name.contains('burger') ||
          name.contains('برغر') ||
          name.contains('برجر') ||
          name.contains('كلاسيك');
    }

    // 2. Shawarma
    if (target.contains('شاورما') || target.contains('shawarma')) {
      return tag.contains('شاورما') ||
          cuisine.contains('شاورما') ||
          name.contains('شاورما') ||
          name.contains('أنس') ||
          name.contains('anas');
    }

    // 3. Sweets & Desserts
    if (target.contains('حلويات') ||
        target.contains('حلى') ||
        target.contains('sweet') ||
        target.contains('dessert') ||
        target.contains('بوظة')) {
      return tag.contains('حلويات') ||
          tag.contains('حلى') ||
          cuisine.contains('حلويات') ||
          cuisine.contains('حلى') ||
          cuisine.contains('بوظة') ||
          name.contains('بكداش') ||
          name.contains('داوود') ||
          name.contains('مهنا');
    }

    // 4. Bakery & Pastries
    if (target.contains('مخبوزات') ||
        target.contains('مخبز') ||
        target.contains('فطاير') ||
        target.contains('معجنات')) {
      return tag.contains('مخبوزات') ||
          tag.contains('فطاير') ||
          cuisine.contains('معجنات') ||
          cuisine.contains('فطاير') ||
          name.contains('بوز الجدي');
    }

    // 5. Popular Breakfast / Falafel & Foul
    if (target.contains('فلافل') ||
        target.contains('فول') ||
        target.contains('فطور') ||
        target.contains('فتات')) {
      return tag.contains('فطور') ||
          tag.contains('فلافل') ||
          tag.contains('فول') ||
          cuisine.contains('فطور') ||
          cuisine.contains('تساقي') ||
          name.contains('بوز الجدي') ||
          name.contains('فلافل');
    }

    // 6. Drinks & Coffee
    if (target.contains('مشروبات') ||
        target.contains('كافيه') ||
        target.contains('قهوة') ||
        target.contains('cafe') ||
        target.contains('coffee')) {
      return tag.contains('كافيه') ||
          tag.contains('مشروبات') ||
          tag.contains('قهوة') ||
          cuisine.contains('كافيه') ||
          cuisine.contains('مشروبات') ||
          cuisine.contains('قهوة') ||
          name.contains('نوفرة') ||
          name.contains('النوفرة') ||
          name.contains('أرت') ||
          name.contains('art');
    }

    // 7. Grills & Barbecue
    if (target.contains('مشاوي') ||
        target.contains('مشويات') ||
        target.contains('كباب') ||
        target.contains('grill')) {
      return tag.contains('مشاوي') ||
          tag.contains('مشويات') ||
          cuisine.contains('مشاوي') ||
          cuisine.contains('مشويات') ||
          cuisine.contains('كباب') ||
          name.contains('بوابة دمشق') ||
          name.contains('مشاوي');
    }

    // 8. Syrian / Shami Cuisine
    if (target.contains('سوري') ||
        target.contains('شامي') ||
        target.contains('دمشقي')) {
      return tag.contains('شامي') ||
          tag.contains('سوري') ||
          cuisine.contains('شامي') ||
          cuisine.contains('سوري') ||
          cuisine.contains('شعبي') ||
          name.contains('شام') ||
          name.contains('دمشق');
    }

    return false;
  }

  List<_RestaurantListItem> get _filteredRestaurants {
    List<_RestaurantListItem> list = _allRestaurants.where((r) {
      if (widget.catalogScope != null) {
        if (_selectedCategory != 'الكل') {
          final merchantCategories =
              _merchantProductCategories[r.id] ?? const <String>{};
          if (!merchantCategories.any(
            (category) => _sameCategory(category, _selectedCategory),
          )) {
            return false;
          }
        }
      } else if (!_matchesCategory(r, _categoryFilterTag(_selectedCategory))) {
        return false;
      }
      if (_filterOffers && !r.hasOffers) {
        return false;
      }
      if (_filterRating4 && r.rating < 4.0) {
        return false;
      }
      if (_filterFast && !r.isFast) {
        return false;
      }
      if (_filterFreeDelivery) {
        final fee = r.deliveryFee.toLowerCase();
        final isFree = fee.contains('مجاني') ||
            fee.contains('free') ||
            fee == '0' ||
            fee.startsWith('0 ') ||
            fee.startsWith('0.0');
        if (!isFree) return false;
      }
      if (_searchController.text.trim().isNotEmpty) {
        final q = _searchController.text.trim().toLowerCase();
        final match = r.name.toLowerCase().contains(q) ||
            r.cuisine.toLowerCase().contains(q) ||
            r.categoryTag.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    if (_filterNearest) {
      list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } else if (_filterRating4) {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom: false,
        child: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            // ONLY respond to vertical scrolling of the main page, ignore horizontal carousels!
            if (notification.metrics.axis != Axis.vertical) {
              return false;
            }

            if (notification.direction == ScrollDirection.reverse) {
              // Scrolling down anywhere -> slide search bar up to hide
              if (_searchAnimController.value > 0 &&
                  _searchAnimController.status != AnimationStatus.reverse) {
                _searchAnimController.reverse();
              }
            } else if (notification.direction == ScrollDirection.forward) {
              // Scrolling up from anywhere -> slide search bar down to reveal
              if (_searchAnimController.value < 1 &&
                  _searchAnimController.status != AnimationStatus.forward) {
                _searchAnimController.forward();
              }
            }
            return true;
          },
          child: Column(
            children: [
              // 1. Fixed Top Nav Row (Never moves, sticks to the top)
              _buildStickyTopNavRow(context),

              // 2. Animated Search Bar (Slides top-to-bottom on scroll up, bottom-to-top on scroll down)
              ClipRect(
                child: SizeTransition(
                  sizeFactor: _searchAnimController,
                  alignment: Alignment.bottomCenter,
                  child: SlideTransition(
                    position: _searchSlideAnim,
                    child: FadeTransition(
                      opacity: _searchAnimController,
                      child: _buildFloatingSearchBar(),
                    ),
                  ),
                ),
              ),

              // 3. Scrollable Content Feed
              Expanded(
                child: ScrollConfiguration(
                  behavior: const ScrollBehavior().copyWith(overscroll: false),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      // Section 1: Square Promo Ads Section (Dynamically controlled from Admin Dashboard)
                      if (_restaurantBanners.isNotEmpty) ...[
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        SliverToBoxAdapter(
                          child: _buildSquarePromoAdsSection(),
                        ),
                      ],

                      // Section 2: "اطلب من جديد" (Order Again - Only past ordered restaurants)
                      if (_orderAgainList.isNotEmpty) ...[
                        const SliverToBoxAdapter(child: SizedBox(height: 22)),
                        SliverToBoxAdapter(
                          child: _buildOrderAgainSection(),
                        ),
                      ],

                      // Section 3: "كل المطاعم" (All Restaurant Categories Circular Chips)
                      if (widget.catalogScope != null ||
                          _restaurantCategoriesConfig?.enabled != false) ...[
                        const SliverToBoxAdapter(child: SizedBox(height: 22)),
                        SliverToBoxAdapter(
                          child: _buildCategoriesSection(),
                        ),
                      ],

                      // Section 4: Filter Pills Row
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverToBoxAdapter(
                        child: _buildFilterPillsRow(),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // Section 5: Vertical Feed of Restaurant Cards
                      _buildRestaurantsFeed(),

                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Pinned Sticky Top Navigation Row: Back Button + 50% Width Address + Heart
  // ---------------------------------------------------------------------------
  Widget _buildStickyTopNavRow(BuildContext context) {
    final mainAddressService =
        locator<AppParametersProvider>().mainAddressService;
    AddressModel currentAddress = mainAddressService.mainAddress;
    String addressTitle = currentAddress.title?.isNotEmpty == true
        ? currentAddress.title!
        : (currentAddress.fullAddress?.isNotEmpty == true
            ? currentAddress.fullAddress!
            : 'House');

    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Back Button (Facing rightward in opposite direction)
          HeaderCircleButton.back(
            onTap: () => Navigator.pop(context),
          ),

          const SizedBox(width: 10),

          // 2. Delivery Address: Sits right beside Back Button, takes 50% width without "التوصيل إلى"
          Container(
            constraints: BoxConstraints(maxWidth: screenWidth * 0.52),
            child: GestureDetector(
              onTap: () => showJtakAddressBottomSheet(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      addressTitle,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: kCharcoalDark,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    PhosphorIconsRegular.caretDown,
                    color: kCharcoalDark,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),

          // 3. 50% empty space from the favorite button side
          const Spacer(),

          // 4. Heart / Favorites Button
          HeaderCircleButton(
            iconData: PhosphorIconsRegular.heart,
            iconSize: 20,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoritePage()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Floating & Snapping Search Bar
  // ---------------------------------------------------------------------------
  Widget _buildFloatingSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchPage(
                catalogScope: widget.catalogScope,
                scopedMerchantIds:
                    _scopedMerchants?.map((merchant) => merchant.id).toList(),
              ),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEBEBEF), width: 0.8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.catalogScope?.searchHint ?? 'ابحث عن المطاعم والأطباق',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF6B7280),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const JtakSearchIcon(
                color: Color(0xFF4B5563),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Section 1: Square Promo Ads Section (Dynamically controlled from Admin Dashboard)
  // ---------------------------------------------------------------------------
  Widget _buildSquarePromoAdsSection() {
    if (_restaurantBanners.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _restaurantBanners.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final banner = _restaurantBanners[index];
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

  // ---------------------------------------------------------------------------
  // 4. Section 2: "اطلب من جديد" (Order Again - ONLY from user's past placed orders)
  // ---------------------------------------------------------------------------
  Widget _buildOrderAgainSection() {
    if (_orderAgainList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title: "اطلب من جديد"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'اطلب من جديد',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 20.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Horizontal Brand Logo Cards (Clean Squircles with full cover logos)
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _orderAgainList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = _orderAgainList[index];
              final logoUrl = (item['logoUrl'] ?? '').toString();
              return GestureDetector(
                onTap: () {
                  final isMarket = item['isProductMerchant'] == true;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => isMarket
                          ? MarketPage(
                              marketId: item['id'] as int,
                              marketName: item['name'] as String,
                              coverUrl: (item['coverUrl'] ?? '').toString(),
                              logoUrl: logoUrl,
                            )
                          : RestaurantMenuPage(
                              restaurantId: item['id'] as int,
                              restaurantName: item['name'] as String,
                              coverUrl: (item['coverUrl'] ?? '').toString(),
                              logoUrl: logoUrl,
                            ),
                    ),
                  );
                },
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: logoUrl.startsWith('assets')
                        ? Image.asset(
                            logoUrl,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          )
                        : (logoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: logoUrl.startsWith('http')
                                    ? logoUrl
                                    : GlobalVar.getImageUrl(logoUrl,
                                        width: 200, height: 200),
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFFF8FAFC),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFFF8FAFC),
                                  child: const Icon(
                                    Icons.storefront_outlined,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFFF8FAFC),
                                child: const Icon(
                                  Icons.storefront_outlined,
                                  color: Color(0xFF94A3B8),
                                ),
                              )),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Section 3: "كل المطاعم" (All Restaurant Categories Circular Chips)
  // ---------------------------------------------------------------------------
  Widget _buildCategoriesSection() {
    final configured = _restaurantCategoriesConfig;
    if (widget.catalogScope == null &&
        configured != null &&
        !configured.enabled) {
      return const SizedBox.shrink();
    }

    final List<Map<String, String>> categories;
    if (widget.catalogScope != null) {
      categories = _scopeCategoryImages.entries
          .map((entry) => <String, String>{
                'title': entry.key,
                'image': entry.value ?? widget.catalogScope!.fallbackImage,
              })
          .toList()
        ..sort((a, b) => a['title']!.compareTo(b['title']!));
    } else if (configured != null && configured.items.isNotEmpty) {
      final activeItems = configured.items
          .where((item) => item.active && item.title.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      categories = activeItems
          .map((item) => <String, String>{
                'title': _categoryDisplayTitle(item),
                'image': item.image,
              })
          .toList();
    } else {
      categories = [
        {
          'title': 'شاورما',
          'image':
              'assets/images/products/Arabic Chicken Shawarma Platter.webp',
        },
        {
          'title': 'مشاوي',
          'image': 'assets/images/categories/meat_poultry.png',
        },
        {
          'title': 'فطور شعبي',
          'image': 'assets/images/categories/dish_syrian.png',
        },
        {
          'title': 'حلويات',
          'image': 'assets/images/products/Classic Roll.webp',
        },
        {
          'title': 'البرجر',
          'image': 'assets/images/products/Double Angus Smash Burger.webp',
        },
        {
          'title': 'مشروبات',
          'image': 'assets/images/products/Iced Spanish Latte.webp',
        },
        {
          'title': 'مخبوزات',
          'image': 'assets/images/products/Minibon 9-Pack Box.webp',
        },
      ];
    }

    // When the admin intentionally deactivates every category, do not leave
    // an empty heading/list placeholder in the customer app.
    if (widget.catalogScope == null &&
        configured != null &&
        categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title: "كل المطاعم"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            widget.catalogScope?.allSectionTitle ??
                (configured == null
                    ? null
                    : _sectionDisplayTitle(configured)) ??
                'كل المطاعم',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 20.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Horizontal Circular Category Chips
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _isCategorySelected(cat['title']!);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = isSelected ? 'الكل' : cat['title']!;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circular Food Image Container (Full Cover with no inner padding)
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? kPrimaryOrange
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: ClipOval(
                        child: ImageView(
                          cat['image'],
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          showLoader: false,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Title Text Below Avatar
                    Text(
                      cat['title']!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isSelected
                            ? kPrimaryOrange
                            : const Color(0xFF374151),
                        fontSize: 13.0,
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w700,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Section 4: Filter Pills Row
  // ---------------------------------------------------------------------------
  Widget _buildFilterPillsRow() {
    final bool hasActiveFilters = _activeFiltersCount > 0;

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 1. التصفية Pill (Filter Modal Trigger)
          _buildDropdownPill(
            label: 'التصفية',
            icon: PhosphorIconsRegular.slidersHorizontal,
            badgeCount: hasActiveFilters ? _activeFiltersCount : null,
            isSelected: hasActiveFilters,
            onTap: _openFilterBottomSheet,
          ),

          const SizedBox(width: 8),

          // 2. المطابخ Pill (Cuisines Selector)
          _buildDropdownPill(
            label: _selectedCategory != 'الكل'
                ? _selectedCategory
                : widget.catalogScope?.categorySelectorTitle ?? 'المطابخ',
            icon: PhosphorIconsRegular.slidersHorizontal,
            isSelected: _selectedCategory != 'الكل',
            onTap: _openCuisinesBottomSheet,
          ),

          const SizedBox(width: 8),

          // 3. الأعلى تقييماً Pill
          _buildPill(
            label: 'الأعلى تقييماً',
            isSelected: _filterRating4,
            onTap: () {
              setState(() {
                _filterRating4 = !_filterRating4;
              });
            },
          ),

          const SizedBox(width: 8),

          // 4. توصيل مجاني Pill
          _buildPill(
            label: 'توصيل مجاني',
            isSelected: _filterFreeDelivery,
            onTap: () {
              setState(() {
                _filterFreeDelivery = !_filterFreeDelivery;
              });
            },
          ),

          const SizedBox(width: 8),

          // 5. الأقرب لك Pill
          _buildPill(
            label: 'الأقرب لك',
            isSelected: _filterNearest,
            onTap: () {
              setState(() {
                _filterNearest = !_filterNearest;
              });
            },
          ),

          const SizedBox(width: 8),

          // 6. عروض Pill
          _buildPill(
            label: 'عروض',
            isSelected: _filterOffers,
            onTap: () {
              setState(() {
                _filterOffers = !_filterOffers;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownPill({
    required String label,
    required IconData icon,
    int? badgeCount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF3EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kPrimaryOrange : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? kPrimaryOrange : kCharcoalDark,
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                width: 17,
                height: 17,
                decoration: const BoxDecoration(
                  color: kPrimaryOrange,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isSelected ? kPrimaryOrange : kCharcoalDark,
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              PhosphorIconsRegular.caretDown,
              size: 14,
              color: isSelected ? kPrimaryOrange : kCharcoalDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF3EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kPrimaryOrange : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isSelected ? kPrimaryOrange : kCharcoalDark,
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _openCuisinesBottomSheet() {
    final List<String> cuisineList = widget.catalogScope != null
        ? ['الكل', ..._scopeCategoryImages.keys]
        : [
            'الكل',
            'شاورما',
            'البرجر',
            'بيتزا',
            'حلويات',
            'مخبوزات',
            'فول و فلافل',
            'مشاوي',
            'مشروبات',
            'سوري',
            'كشري',
          ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.catalogScope != null ? 'اختر القسم' : 'اختر نوع المطبخ',
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: cuisineList.map((cat) {
                final isCurrent = _isCategorySelected(cat);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFFFFF3EB)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrent ? kPrimaryOrange : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isCurrent ? kPrimaryOrange : kCharcoalDark,
                        fontSize: 14,
                        fontWeight:
                            isCurrent ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'تصفية وفرز المطاعم',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: kCharcoalDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _buildModalFilterItem(
                  'الأعلى تقييماً (4.0+)',
                  _filterRating4,
                  (val) {
                    setModalState(() => _filterRating4 = val);
                    setState(() {});
                  },
                ),
                _buildModalFilterItem(
                  'عروض وخصومات نشطة',
                  _filterOffers,
                  (val) {
                    setModalState(() => _filterOffers = val);
                    setState(() {});
                  },
                ),
                _buildModalFilterItem(
                  'توصيل سريع (< 25 دقيقة)',
                  _filterFast,
                  (val) {
                    setModalState(() => _filterFast = val);
                    setState(() {});
                  },
                ),
                _buildModalFilterItem(
                  'توصيل مجاني فقط',
                  _filterFreeDelivery,
                  (val) {
                    setModalState(() => _filterFreeDelivery = val);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryOrange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      'تطبيق الفلتر',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalFilterItem(
      String title, bool isChecked, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => onChanged(!isChecked),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              isChecked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: isChecked ? kPrimaryOrange : kCharcoalMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Section 5: Vertical Feed of Restaurant Cards
  // ---------------------------------------------------------------------------
  Widget _buildRestaurantsFeed() {
    if (_isLoadingScopedMerchants) {
      return const SliverRestaurantsListSkeleton(count: 4);
    }

    final restaurants = _filteredRestaurants;

    if (restaurants.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 54, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 12),
              Text(
                widget.catalogScope?.emptyMerchantsMessage ??
                    'لا توجد مطاعم مطابقة للبحث أو الفلتر',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = 'الكل';
                    _selectedSort = 'رتب حسب';
                    _filterOffers = false;
                    _filterRating4 = false;
                    _filterFast = false;
                    _filterNearest = false;
                    _filterFreeDelivery = false;
                    _searchController.clear();
                  });
                },
                child: Text(
                  'إعادة ضبط الفلاتر',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: kPrimaryOrange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final r = restaurants[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: JtakRestaurantCard(
                data: RestaurantItemData(
                  id: r.id,
                  name: r.name,
                  coverUrl: r.coverUrl,
                  logoUrl: r.logoUrl,
                  category: r.cuisine,
                  rating: r.rating,
                  ratingCount: r.ratingCount,
                  eta: r.eta,
                  distance: r.distance,
                  deliveryFee: r.deliveryFee,
                  isVerified: true,
                  isOpen: true,
                ),
                width: double.infinity,
                onTap: () {
                  final nameLower = r.name.toLowerCase();
                  final catLower = r.categoryTag.toLowerCase();
                  final isMarket = catLower.contains('سوبرماركت') ||
                      catLower.contains('ماركت') ||
                      catLower.contains('market') ||
                      nameLower.contains('ماركت') ||
                      nameLower.contains('سوبر ماركت') ||
                      nameLower.contains('سوبرماركت') ||
                      nameLower.contains('مارت') ||
                      nameLower.contains('كلوفر') ||
                      nameLower.contains('clover') ||
                      nameLower.contains('مول') ||
                      nameLower.contains('mall') ||
                      nameLower.contains('market') ||
                      nameLower.contains('mart');
                  if (widget.catalogScope != null ||
                      r.isProductMerchant ||
                      isMarket) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MarketPage(
                          marketId: r.id,
                          marketName: r.name,
                          coverUrl: r.coverUrl,
                          logoUrl: r.logoUrl,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RestaurantMenuPage(
                          restaurantId: r.id,
                          restaurantName: r.name,
                          coverUrl: r.coverUrl,
                          logoUrl: r.logoUrl,
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
          childCount: restaurants.length,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Catalog Data from MarketsProvider (Live Backend) + Fallback
  // ---------------------------------------------------------------------------
  List<_RestaurantListItem> get _allRestaurants {
    if (widget.catalogScope != null) {
      return _scopedMerchants ?? const [];
    }

    // A tile pointing at a merchant kind lists exactly those merchants. The
    // provider already splits the backend feed by its merchantKind field, so
    // restaurants are kind 0 and every other kind lands in markets.
    if (widget.merchantKind != null && locator.isRegistered<MarketsProvider>()) {
      final marketsProv = locator<MarketsProvider>();
      final ofKind = widget.merchantKind == 0
          ? _buildProviderMerchants(marketsProv)
          : _buildMarketMerchants(marketsProv.markets
              .where((m) => m.merchantKind == widget.merchantKind));
      final seen = <int>{};
      return ofKind.where((m) => seen.add(m.id)).toList();
    }

    if (locator.isRegistered<MarketsProvider>()) {
      final marketsProv = locator<MarketsProvider>();
      return _buildProviderMerchants(marketsProv);
    }
    return const [];
  }

  List<_RestaurantListItem> _buildProviderMerchants(
    MarketsProvider provider, {
    bool includeMarkets = false,
  }) {
    final merchants = provider.restaurants.map((r) {
      return _RestaurantListItem(
        id: r.id,
        name: r.name,
        cuisine: r.cuisine,
        categoryTag: r.categoryTag,
        rating: r.rating,
        ratingCount: r.ratingCount,
        eta: r.eta,
        distance: r.distance,
        deliveryFee: r.deliveryFee,
        hasOffers: r.hasOffers,
        isFast: r.isFast,
        coverUrl: r.coverUrl,
        logoUrl: r.logoUrl,
        isProductMerchant: false,
      );
    }).toList();

    if (includeMarkets) {
      merchants.addAll(_buildMarketMerchants(provider.markets));
    }

    final seen = <int>{};
    return merchants.where((merchant) => seen.add(merchant.id)).toList();
  }

  List<_RestaurantListItem> _buildMarketMerchants(
    Iterable<MarketStoreModel> markets,
  ) {
    return markets.map((market) {
      final image = market.assetPath ?? market.logoUrl ?? '';
      return _RestaurantListItem(
        id: market.id,
        name: market.name,
        cuisine: market.tagline ?? 'منتجات ومتاجر',
        categoryTag: 'متجر',
        rating: 4.8,
        ratingCount: 0,
        eta: market.eta,
        distance: '2.5 كم',
        deliveryFee: market.deliveryFeeAmount == 0
            ? 'مجاني'
            : '${market.deliveryFeeAmount.toInt()} ل.س',
        hasOffers: true,
        isFast: true,
        coverUrl: image,
        logoUrl: image,
        isProductMerchant: true,
      );
    }).toList();
  }
}

class _RestaurantListItem {
  final int id;
  final String name;
  final String cuisine;
  final String categoryTag;
  final double rating;
  final int ratingCount;
  final String eta;
  final String distance;
  final String deliveryFee;
  final bool hasOffers;
  final bool isFast;
  final String coverUrl;
  final String logoUrl;
  final bool isProductMerchant;

  const _RestaurantListItem({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.categoryTag,
    required this.rating,
    required this.ratingCount,
    required this.eta,
    required this.distance,
    required this.deliveryFee,
    required this.hasOffers,
    required this.isFast,
    required this.coverUrl,
    required this.logoUrl,
    this.isProductMerchant = false,
  });

  double get distanceKm =>
      double.tryParse(distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 99.0;
}

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/products_provider.dart';
import '../../../core/controllers/catalog/markets_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../widgets/catalog/meal_card_widget.dart';
import '../../widgets/catalog/product_widgets.dart';
import '../../widgets/clean_shimmer_skeletons.dart';
import '../../widgets/header_circle_button.dart';
import '../../widgets/search_bar_widget.dart';
import 'market_page.dart';
import 'catalog_scope.dart';
import 'restaurant_menu_page.dart';

/// ---------------------------------------------------------------------------
/// Food Craving Visual Item
/// ---------------------------------------------------------------------------
class _FoodCravingItem {
  final String title;
  final String imageUrl;
  final String query;

  const _FoodCravingItem({
    required this.title,
    required this.imageUrl,
    required this.query,
  });
}

/// ---------------------------------------------------------------------------
/// JTAK Modern Interactive Search & Discovery Screen
/// ---------------------------------------------------------------------------
class SearchPage extends StatefulWidget {
  static const String routeName = '/SearchPage';
  final String? initialQuery;
  final CatalogScope? catalogScope;
  final List<int>? scopedMerchantIds;
  final int? productCategoryId;
  final String? categoryTitle;

  const SearchPage({
    super.key,
    this.initialQuery,
    this.catalogScope,
    this.scopedMerchantIds,
    this.productCategoryId,
    this.categoryTitle,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  String _currentQuery = '';

  bool get _isScopedSearch =>
      widget.catalogScope != null || widget.productCategoryId != null;

  int? get _effectiveCategoryId =>
      widget.catalogScope?.categoryId ?? widget.productCategoryId;

  String get _scopeTitle =>
      widget.catalogScope?.title ?? widget.categoryTitle ?? 'هذه الفئة';

  String get _scopeSearchHint =>
      widget.catalogScope?.searchHint ?? 'ابحث داخل $_scopeTitle';

  final List<_FoodCravingItem> _cravings = const [
    _FoodCravingItem(
      title: 'شاورما',
      imageUrl:
          'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&w=300&q=80',
      query: 'شاورما',
    ),
    _FoodCravingItem(
      title: 'برغر',
      imageUrl:
          'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=300&q=80',
      query: 'برغر',
    ),
    _FoodCravingItem(
      title: 'مشاوي وكباب',
      imageUrl:
          'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=300&q=80',
      query: 'مشاوي',
    ),
    _FoodCravingItem(
      title: 'بيتزا إيطالية',
      imageUrl:
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=300&q=80',
      query: 'بيتزا',
    ),
    _FoodCravingItem(
      title: 'حلويات وسينامون',
      imageUrl:
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=300&q=80',
      query: 'حلويات',
    ),
    _FoodCravingItem(
      title: 'دجاج مقرمش',
      imageUrl:
          'https://images.unsplash.com/photo-1625813506062-0aeb1d7a094b?auto=format&fit=crop&w=300&q=80',
      query: 'بروستد',
    ),
    _FoodCravingItem(
      title: 'فطور وفلافل',
      imageUrl:
          'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?auto=format&fit=crop&w=300&q=80',
      query: 'فطور',
    ),
    _FoodCravingItem(
      title: 'قهوة ومشروبات',
      imageUrl:
          'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=300&q=80',
      query: 'قهوة',
    ),
    _FoodCravingItem(
      title: 'باستا ولازانيا',
      imageUrl:
          'https://images.unsplash.com/photo-1645112411341-6c4fd023714a?auto=format&fit=crop&w=300&q=80',
      query: 'باستا',
    ),
    _FoodCravingItem(
      title: 'خضار ومونة',
      imageUrl:
          'https://images.unsplash.com/photo-1578916171728-46686eac8d58?auto=format&fit=crop&w=300&q=80',
      query: 'خضار',
    ),
  ];

  final List<String> _recentSearches = [
    'شاورما عربي سوبر',
    'دبل برغر كلاسيك',
    'بيتزا بيبروني',
    'سينابون رول',
    'فتة شاورما كرم الشام',
    'جيتك مارت',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _currentQuery = widget.initialQuery!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String val, ProductsProvider provider) {
    setState(() {
      _currentQuery = val.trim();
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      provider.search = _currentQuery.isNotEmpty ? _currentQuery : null;
      if (_currentQuery.isNotEmpty) {
        provider.loadNewData(
          productCategoryId: _effectiveCategoryId,
        );
      }
    });
  }

  void _applyQuery(String query, ProductsProvider provider) {
    HapticFeedback.selectionClick();
    _searchController.text = query;
    _searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: query.length));
    _onQueryChanged(query, provider);
  }

  void _clearQuery(ProductsProvider provider) {
    HapticFeedback.lightImpact();
    _searchController.clear();
    _onQueryChanged('', provider);
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<ProductsProvider>(
      modelProvider: ProductsProvider(),
      onModelReady: (provider) {
        if (_currentQuery.isNotEmpty) {
          provider.search = _currentQuery;
          provider.loadNewData(
            productCategoryId: _effectiveCategoryId,
          );
        }
      },
      builder: (context, provider) {
        return ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(overscroll: false),
          child: Scaffold(
            backgroundColor:
                !_isScopedSearch ? const Color(0xFFF8F9FA) : Colors.white,
            body: SafeArea(
              child: Column(
                children: [
                  // 1. Top Header with Back Button and Pill Search Field
                  _buildTopSearchHeader(provider),

                  // 2. Dynamic Content: Discovery View vs Live Search Results
                  Expanded(
                    child: _currentQuery.isEmpty
                        ? !_isScopedSearch
                            ? _buildDiscoveryView(provider)
                            : const SizedBox.expand()
                        : !_isScopedSearch
                            ? _buildLiveSuggestionsView(provider)
                            : _buildScopedSuggestionsView(provider),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Top Search Header
  // ---------------------------------------------------------------------------
  Widget _buildTopSearchHeader(ProductsProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          // Circular Back Button matching global design specification
          HeaderCircleButton.back(
            onTap: () => Navigator.pop(context),
          ),

          const SizedBox(width: 10),

          // Search Pill Input Field
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Standard Search Icon
                  const JtakSearchIcon(
                    color: Color(0xFF475569),
                    size: 20,
                  ),
                  const SizedBox(width: 10),

                  // Search Input & Animated Placeholder Ticker
                  Expanded(
                    child: Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [
                        if (_searchController.text.isEmpty)
                          IgnorePointer(
                            child: !_isScopedSearch
                                ? const DynamicRotatingSearchHint()
                                : Text(
                                    _scopeSearchHint,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: const Color(0xFF7C828C),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          autofocus: widget.initialQuery == null ||
                              widget.initialQuery!.isEmpty,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: kCharcoalDark,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) => _onQueryChanged(val, provider),
                        ),
                      ],
                    ),
                  ),

                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _clearQuery(provider),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Discovery View (Empty Query State)
  // ---------------------------------------------------------------------------
  Widget _buildDiscoveryView(ProductsProvider provider) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Section A: ماذا تشتهي اليوم؟ (Visual Food Cravings Grid)
        _buildSectionTitle('ماذا تشتهي اليوم؟'),
        const SizedBox(height: 14),
        _buildFoodCravingsRow(provider),

        const SizedBox(height: 26),

        // Section B: ما بحثت عنه مؤخرًا (Recent Searches)
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عمليات البحث الأخيرة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: kCharcoalDark,
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _recentSearches.clear();
                    });
                  },
                  child: Text(
                    'مسح السجل',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildRecentSearchesWrap(provider),
          const SizedBox(height: 26),
        ],

        // Section C: أطباق ووجبات مختارة (Popular Showcase Meals)
        _buildSectionTitle('أطباق مميزة مختارة لك'),
        const SizedBox(height: 14),
        _buildPopularMealsShowcase(provider),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(
          color: kCharcoalDark,
          fontSize: 18.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // Section A: Circular Cravings Row
  Widget _buildFoodCravingsRow(ProductsProvider provider) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _cravings.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = _cravings[index];
          return GestureDetector(
            onTap: () => _applyQuery(item.query, provider),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                          color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: ClipOval(
                      child: item.imageUrl.startsWith('assets')
                          ? Image.asset(
                              item.imageUrl,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(PhosphorIconsFill.forkKnife,
                                    color: Color(0xFF9CA3AF), size: 28),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(PhosphorIconsFill.forkKnife,
                                    color: Color(0xFF9CA3AF), size: 28),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF334155),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Section B: Recent Searches Wrap
  Widget _buildRecentSearchesWrap(ProductsProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _recentSearches.map((term) {
          return GestureDetector(
            onTap: () => _applyQuery(term, provider),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsRegular.clockCounterClockwise,
                    color: Color(0xFF94A3B8),
                    size: 14,
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    term,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF334155),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Section E: Popular Meals Showcase Carousel
  Widget _buildPopularMealsShowcase(ProductsProvider provider) {
    final meals = MockCatalogData.allDeliveryMeals;
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: meals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final meal = meals[index];
          return JTAKMealCard(
            data: meal,
            width: 165,
            height: 225,
            onTap: () {
              final parentRest = MockCatalogData.restaurants.firstWhere(
                (r) => r.menuItems.any((m) => m.id == meal.id),
                orElse: () => MockCatalogData.restaurants.first,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RestaurantMenuPage(
                    restaurantId: parentRest.id,
                    restaurantName: parentRest.name,
                    coverUrl: parentRest.coverUrl,
                    logoUrl: parentRest.logoUrl,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _normalizeArabic(String text) {
    var s = text.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[أإآ]'), 'ا');
    s = s.replaceAll('ة', 'ه');
    s = s.replaceAll('ى', 'ي');
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), ''); // Remove Tashkeel
    return s;
  }

  bool _matchesQuery(String source, String query) {
    if (query.trim().isEmpty) return false;
    final normSource = _normalizeArabic(source);
    final normQuery = _normalizeArabic(query);
    if (normSource.contains(normQuery)) return true;

    final queryNoAl =
        normQuery.startsWith('ال') ? normQuery.substring(2) : normQuery;
    final sourceNoAl =
        normSource.startsWith('ال') ? normSource.substring(2) : normSource;

    if (queryNoAl.isNotEmpty &&
        (normSource.contains(queryNoAl) || sourceNoAl.contains(queryNoAl))) {
      return true;
    }

    final tokens = normQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    for (final t in tokens) {
      final tNoAl = t.startsWith('ال') ? t.substring(2) : t;
      if (t.isNotEmpty && normSource.contains(t)) return true;
      if (tNoAl.isNotEmpty &&
          (normSource.contains(tNoAl) || sourceNoAl.contains(tNoAl)))
        return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // 4. Live Instant Search Results (Stores & Dishes Categorized)
  // ---------------------------------------------------------------------------
  Widget _buildScopedSuggestionsView(ProductsProvider provider) {
    final query = _currentQuery.trim();
    final allowedMerchantIds = widget.scopedMerchantIds?.toSet() ?? <int>{};
    final merchantResults = <Map<String, dynamic>>[];

    if (locator.isRegistered<MarketsProvider>() &&
        allowedMerchantIds.isNotEmpty) {
      final marketsProvider = locator<MarketsProvider>();
      final categoryMerchants = marketsProvider.getCachedCategoryMerchants(
        _effectiveCategoryId!,
      );

      for (final merchant in marketsProvider.restaurants) {
        if (allowedMerchantIds.contains(merchant.id) &&
            (_matchesQuery(merchant.name, query) ||
                _matchesQuery(merchant.cuisine, query))) {
          merchantResults.add({
            'id': merchant.id,
            'name': merchant.name,
            'image': merchant.logoUrl,
            'cover': merchant.coverUrl,
            'description': merchant.cuisine,
          });
        }
      }

      final productMerchants = <MarketStoreModel>[
        ...categoryMerchants,
        ...marketsProvider.markets,
      ];
      final seenMerchantIds = <int>{};
      for (final merchant in productMerchants) {
        if (!seenMerchantIds.add(merchant.id)) continue;
        if (allowedMerchantIds.contains(merchant.id) &&
            (_matchesQuery(merchant.name, query) ||
                _matchesQuery(merchant.tagline ?? '', query))) {
          merchantResults.add({
            'id': merchant.id,
            'name': merchant.name,
            'image': merchant.assetPath ?? merchant.logoUrl ?? '',
            'cover': merchant.assetPath ?? merchant.logoUrl ?? '',
            'description': merchant.tagline ?? widget.catalogScope!.title,
          });
        }
      }
    }

    final products = provider.dataList.where((product) {
      if (allowedMerchantIds.isEmpty) return true;
      return product.merchantId != null &&
          allowedMerchantIds.contains(product.merchantId);
    }).toList();

    if (provider.isBusy && products.isEmpty && merchantResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: RestaurantsListSkeleton(count: 3),
      );
    }

    if (products.isEmpty && merchantResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 54,
                color: Color(0xFF94A3AF),
              ),
              const SizedBox(height: 14),
              Text(
                'لا توجد نتائج داخل $_scopeTitle',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'جرّب اسم متجر أو منتج آخر',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (merchantResults.isNotEmpty) ...[
          Text(
            '${widget.catalogScope?.allSectionTitle ?? 'المتاجر'} (${merchantResults.length})',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...merchantResults.map((merchant) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarketPage(
                        marketId: merchant['id'] as int,
                        marketName: merchant['name'] as String,
                        coverUrl: merchant['cover'] as String,
                        logoUrl: merchant['image'] as String,
                      ),
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ImageView(
                      merchant['image'],
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      showLoader: false,
                    ),
                  ),
                  title: Text(
                    merchant['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: kCharcoalDark,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    merchant['description'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    PhosphorIconsRegular.caretLeft,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              )),
          const SizedBox(height: 12),
        ],
        if (products.isNotEmpty) ...[
          Text(
            'المنتجات (${products.length})',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...products.map((product) => ProductSingleItem(product)),
        ],
      ],
    );
  }

  Widget _buildLiveSuggestionsView(ProductsProvider provider) {
    final query = _currentQuery.trim();

    // 1. Matching Restaurants / Stores
    var matchingRestaurants = MockCatalogData.restaurants.where((r) {
      final matchesCategories =
          r.categories.any((c) => _matchesQuery(c, query));
      return _matchesQuery(r.name, query) ||
          _matchesQuery(r.cuisine, query) ||
          _matchesQuery(r.categoryTag, query) ||
          matchesCategories;
    }).toList();

    // 2. Matching Food Dishes / Products
    final allDishes = <MockMenuItemData>[];
    for (final r in MockCatalogData.restaurants) {
      allDishes.addAll(r.menuItems);
    }

    var matchingDishes = allDishes.where((item) {
      return _matchesQuery(item.title, query) ||
          _matchesQuery(item.description, query) ||
          _matchesQuery(item.restaurantName, query) ||
          _matchesQuery(item.category, query);
    }).toList();

    // Empty State
    if (matchingRestaurants.isEmpty && matchingDishes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.search_off_rounded,
                      size: 36, color: Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد نتائج مطابقة لـ "$_currentQuery"',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'جرب البحث بكلمات أخرى أو اختر من الكلمات الأكثر طلباً أدناه',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children:
                    ['شاورما', 'برغر', 'بيتزا', 'سينابون', 'ماركت'].map((chip) {
                  return GestureDetector(
                    onTap: () => _applyQuery(chip, provider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        chip,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kPrimaryOrange,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
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

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      children: [
        // 1. Matching Stores Section
        if (matchingRestaurants.isNotEmpty) ...[
          Text(
            'المتاجر والمطاعم (${matchingRestaurants.length})',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...matchingRestaurants.map((restaurant) {
            final nameLower = restaurant.name.toLowerCase();
            final catLower = restaurant.categoryTag.toLowerCase();
            final isMarket = restaurant.isMarket ||
                catLower.contains('سوبرماركت') ||
                catLower.contains('ماركت') ||
                catLower.contains('market') ||
                nameLower.contains('ماركت') ||
                nameLower.contains('سوبرماركت') ||
                nameLower.contains('سوبر ماركت') ||
                nameLower.contains('مارت') ||
                nameLower.contains('كلوفر') ||
                nameLower.contains('clover') ||
                nameLower.contains('مول') ||
                nameLower.contains('mall') ||
                nameLower.contains('market') ||
                nameLower.contains('mart');
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: ListTile(
                onTap: () {
                  if (isMarket) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MarketPage(
                          marketId: restaurant.id,
                          marketName: restaurant.name,
                          coverUrl: restaurant.coverUrl,
                          logoUrl: restaurant.logoUrl,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RestaurantMenuPage(
                          restaurantId: restaurant.id,
                          restaurantName: restaurant.name,
                          coverUrl: restaurant.coverUrl,
                          logoUrl: restaurant.logoUrl,
                        ),
                      ),
                    );
                  }
                },
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: restaurant.logoUrl.startsWith('assets')
                        ? Image.asset(
                            restaurant.logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.storefront,
                                color: Color(0xFF94A3B8)),
                          )
                        : CachedNetworkImage(
                            imageUrl: restaurant.logoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.storefront,
                                color: Color(0xFF94A3B8)),
                          ),
                  ),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kCharcoalDark,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (restaurant.rating >= 4.5 || restaurant.isFast) ...[
                      const SizedBox(width: 4),
                      Transform.flip(
                        flipX: true,
                        child: const Icon(
                          PhosphorIconsFill.sealCheck,
                          color: kPrimaryOrange,
                          size: 15,
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${restaurant.cuisine} • ${restaurant.eta}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(
                  PhosphorIconsRegular.caretLeft,
                  color: Color(0xFF94A3B8),
                  size: 16,
                  textDirection: TextDirection.ltr,
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
        ],

        // 2. Matching Food Items & Products Section
        if (matchingDishes.isNotEmpty) ...[
          Text(
            'الوجبات والأصناف المطابقة (${matchingDishes.length})',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...matchingDishes.map((dish) {
            final parentRest =
                MockCatalogData.getRestaurantById(dish.restaurantId);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestaurantMenuPage(
                        restaurantId: parentRest.id,
                        restaurantName: parentRest.name,
                        coverUrl: parentRest.coverUrl,
                        logoUrl: parentRest.logoUrl,
                      ),
                    ),
                  );
                },
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: dish.imageUrl.startsWith('assets')
                        ? Image.asset(
                            dish.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.fastfood,
                                color: Color(0xFF94A3B8)),
                          )
                        : CachedNetworkImage(
                            imageUrl: dish.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.fastfood,
                                color: Color(0xFF94A3B8)),
                          ),
                  ),
                ),
                title: Text(
                  dish.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: kCharcoalDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'من ${dish.restaurantName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dish.price,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: kPrimaryOrange,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(
                  PhosphorIconsRegular.caretLeft,
                  color: Color(0xFF94A3B8),
                  size: 16,
                  textDirection: TextDirection.ltr,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

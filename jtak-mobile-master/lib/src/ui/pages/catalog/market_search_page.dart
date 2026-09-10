import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/markets_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/services/locator.dart';
import '../../widgets/catalog/replace_cart_bottom_sheet.dart';
import '../../widgets/header_circle_button.dart';
import '../cart/cart_page.dart';
import 'market_page.dart';
import 'market_product_detail_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Market Dedicated Search Page
///
/// Features:
/// 1. Top Search Bar with back action, RTL search input with orange cursor,
///    and instant clear (✕) button.
/// 2. Initial state shows "المنتجات الأكثر بحثاً" as 4 horizontal boxes with
///    image and name underneath. Tapping any box fills search and searches instantly.
/// 3. Live search filters market items dynamically in clean horizontal rows
///    with product thumbnail, title, category, price, and interactive (+) Add counter.
/// 4. Synchronized bottom cart / delivery bar.
/// ---------------------------------------------------------------------------

class MostSearchedMarketItem {
  final int id;
  final String title;
  final String searchQuery;
  final String imageUrl;

  const MostSearchedMarketItem({
    required this.id,
    required this.title,
    required this.searchQuery,
    required this.imageUrl,
  });
}

class _PopularSearchConcept {
  final String label;
  final String query;
  final List<String> words;

  const _PopularSearchConcept({
    required this.label,
    required this.query,
    required this.words,
  });
}

class MarketSearchPage extends StatefulWidget {
  static const String routeName = '/MarketSearchPage';

  final int marketId;
  final String marketName;
  final String? logoUrl;
  final List<MarketProductItem> products;
  final Map<int, int>? initialCartQuantities;
  final void Function(int productId, int newQty)? onCartChanged;

  const MarketSearchPage({
    super.key,
    required this.marketId,
    required this.marketName,
    this.logoUrl,
    required this.products,
    this.initialCartQuantities,
    this.onCartChanged,
  });

  @override
  State<MarketSearchPage> createState() => _MarketSearchPageState();
}

class _MarketSearchPageState extends State<MarketSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';
  final Map<int, int> _cartQuantities = {};
  int get _minOrderTarget =>
      locator<CartProvider>().currentMerchantMinOrder > 0
          ? locator<CartProvider>().currentMerchantMinOrder
          : 50000;
  static const String _recentSearchesPrefKey = 'jtek_market_recent_searches';

  String get _displayMarketName {
    String langCode = 'ar';
    try {
      langCode = Localizations.localeOf(context).languageCode;
    } catch (_) {}
    return MarketStoreModel.extractLocalizedName(widget.marketName, langCode);
  }

  List<String> _recentSearches = [
    'حليب',
    'شيبس',
    'شوكولا',
    'عصير',
  ];

  static const List<_PopularSearchConcept> _popularConcepts = [
    _PopularSearchConcept(label: 'حليب', query: 'حليب', words: ['حليب', 'لبن', 'زبادي']),
    _PopularSearchConcept(label: 'شوكولاتة', query: 'شوكولا', words: ['شوكولاتة', 'شوكولا', 'ميلكا', 'كتكات', 'نوتيلا', 'كاسترد']),
    _PopularSearchConcept(label: 'شيبس', query: 'شيبس', words: ['شيبس', 'شيبسي', 'دوريتوس', 'بطاطا']),
    _PopularSearchConcept(label: 'عصير', query: 'عصير', words: ['عصير', 'بيبسي', 'كولا', 'مشروب', 'سفن']),
    _PopularSearchConcept(label: 'قهوة', query: 'قهوة', words: ['قهوة', 'نسكافيه', 'شاي', 'بن']),
    _PopularSearchConcept(label: 'بسكويت', query: 'بسكويت', words: ['بسكويت', 'بسكوت', 'كوكيز', 'ويفر']),
    _PopularSearchConcept(label: 'أجبان', query: 'جبن', words: ['جبنة', 'جبن', 'قشقوان', 'موزاريلا']),
    _PopularSearchConcept(label: 'برغر', query: 'برغر', words: ['برغر', 'برجر', 'ساندويش']),
    _PopularSearchConcept(label: 'شاورما', query: 'شاورما', words: ['شاورما', 'مشاوي', 'فروج', 'دجاج']),
    _PopularSearchConcept(label: 'منظفات', query: 'منظف', words: ['منظف', 'صابون', 'شامبو', 'غسيل']),
  ];

  late final List<MostSearchedMarketItem> _topSearchedBoxes;

  List<MostSearchedMarketItem> _buildTopSearchedItems(List<MarketProductItem> products) {
    if (products.isEmpty) return const [];

    final List<MostSearchedMarketItem> result = [];
    final Set<int> usedProductIds = {};

    final withImages = products.where((p) => p.imageUrl.trim().isNotEmpty).toList();
    final candidatePool = withImages.isNotEmpty ? withImages : products;

    for (final concept in _popularConcepts) {
      if (result.length >= 4) break;

      MarketProductItem? match;
      for (final p in candidatePool) {
        if (usedProductIds.contains(p.id)) continue;
        final title = p.title.toLowerCase();
        final cat = p.category.toLowerCase();
        final mainCat = p.mainCategory.toLowerCase();
        final matched = concept.words.any((w) =>
            title.contains(w) || cat.contains(w) || mainCat.contains(w));
        if (matched) {
          match = p;
          break;
        }
      }

      if (match != null) {
        usedProductIds.add(match.id);
        result.add(MostSearchedMarketItem(
          id: match.id,
          title: concept.label,
          searchQuery: concept.query,
          imageUrl: match.imageUrl,
        ));
      }
    }

    if (result.length < 4) {
      for (final p in candidatePool) {
        if (result.length >= 4) break;
        if (!usedProductIds.contains(p.id)) {
          usedProductIds.add(p.id);

          String cleanTitle = p.title.split(RegExp(r'[-–,،(]')).first.trim();
          final words = cleanTitle.split(RegExp(r'\s+'));
          if (words.length > 2) {
            cleanTitle = words.take(2).join(' ');
          }
          final displayTitle = cleanTitle.isNotEmpty ? cleanTitle : p.title;

          result.add(MostSearchedMarketItem(
            id: p.id,
            title: displayTitle,
            searchQuery: displayTitle,
            imageUrl: p.imageUrl,
          ));
        }
      }
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _topSearchedBoxes = _buildTopSearchedItems(widget.products);
    if (widget.initialCartQuantities != null) {
      _cartQuantities.addAll(widget.initialCartQuantities!);
    }
    final cart = locator<CartProvider>();
    for (final item in widget.products) {
      final qty = cart.getProductQuantity(item.id);
      if (qty > 0) {
        _cartQuantities[item.id] = qty;
      }
    }

    // Auto-focus search bar upon opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_recentSearchesPrefKey}_${widget.marketId}';
      if (prefs.containsKey(key)) {
        final saved = prefs.getStringList(key);
        if (saved != null && mounted) {
          setState(() {
            _recentSearches = saved;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_recentSearchesPrefKey}_${widget.marketId}';
      await prefs.setStringList(key, _recentSearches);
    } catch (e) {
      debugPrint('Error saving recent searches: $e');
    }
  }

  void _addRecentSearch(String term) {
    final clean = term.trim();
    if (clean.isEmpty) return;
    setState(() {
      _recentSearches.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
      _recentSearches.insert(0, clean);
      if (_recentSearches.length > 8) {
        _recentSearches = _recentSearches.sublist(0, 8);
      }
    });
    _saveRecentSearches();
  }

  void _removeRecentSearch(String term) {
    HapticFeedback.lightImpact();
    setState(() {
      _recentSearches.remove(term);
    });
    _saveRecentSearches();
  }

  void _clearRecentSearches() {
    HapticFeedback.lightImpact();
    setState(() {
      _recentSearches.clear();
    });
    _saveRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  int get _cartItemCount =>
      _cartQuantities.values.fold(0, (sum, qty) => sum + qty);

  int get _cartTotalPrice {
    int total = 0;
    _cartQuantities.forEach((id, qty) {
      for (final p in widget.products) {
        if (p.id == id) {
          total += p.priceValue * qty;
          break;
        }
      }
    });
    return total;
  }

  void _onPlusTapped(int productId) async {
    final cart = locator<CartProvider>();
    if (cart.isDifferentMerchant(widget.marketId)) {
      final shouldReplace = await ReplaceCartBottomSheet.show(
        context,
        currentStoreName: cart.currentMerchantName,
        newStoreName: widget.marketName,
      );
      if (shouldReplace != true || !mounted) return;
      final product = widget.products.firstWhere(
        (p) => p.id == productId,
        orElse: () => widget.products.first,
      );
      await cart.replaceCartWithItem(
        productId,
        widget.marketId,
        product.priceValue.toDouble(),
        1,
      );
      setState(() {
        _cartQuantities.clear();
        _cartQuantities[productId] = 1;
      });
      widget.onCartChanged?.call(productId, 1);
      return;
    }

    HapticFeedback.selectionClick();
    final currentQty = _cartQuantities[productId] ?? 0;
    final newQty = currentQty + 1;
    setState(() {
      _cartQuantities[productId] = newQty;
    });
    final product = widget.products.firstWhere(
      (p) => p.id == productId,
      orElse: () => widget.products.first,
    );
    cart.setToCart(
      productId,
      widget.marketId,
      product.priceValue.toDouble(),
      newQty,
    );
    widget.onCartChanged?.call(productId, newQty);
  }

  void _onMinusTapped(int productId) {
    HapticFeedback.selectionClick();
    final currentQty = _cartQuantities[productId] ?? 0;
    if (currentQty <= 0) return;
    final newQty = currentQty - 1;
    final product = widget.products.firstWhere(
      (p) => p.id == productId,
      orElse: () => widget.products.first,
    );
    setState(() {
      if (newQty <= 0) {
        _cartQuantities.remove(productId);
        locator<CartProvider>().removeFromCart(productId, widget.marketId);
      } else {
        _cartQuantities[productId] = newQty;
        locator<CartProvider>().setToCart(
          productId,
          widget.marketId,
          product.priceValue.toDouble(),
          newQty,
        );
      }
    });
    widget.onCartChanged?.call(productId, newQty);
  }

  List<MarketProductItem> get _filteredProducts {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return widget.products.where((p) {
      return p.title.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.mainCategory.toLowerCase().contains(q) ||
          p.subCategory.toLowerCase().contains(q);
    }).toList();
  }

  void _triggerSearch(String query) {
    HapticFeedback.lightImpact();
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      _addRecentSearch(trimmed);
    }
    setState(() {
      _searchController.text = query;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: query.length),
      );
      _searchQuery = trimmed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final bool isSearching = _searchQuery.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              // 1. Top Navigation & Search Bar
              _buildTopSearchBar(context),

              const Divider(color: Color(0xFFF3F4F6), height: 1, thickness: 1),

              // 2. Body: Either "المنتجات الأكثر بحثاً" OR Live Results / Empty State
              Expanded(
                child: Stack(
                  children: [
                    if (!isSearching)
                      _buildInitialStateView()
                    else if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      _buildLiveResultsList(filtered),

                    // Floating Interactive Bottom Delivery / Cart Bar
                    if (_cartItemCount > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildBottomDeliveryBar(),
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
  // Top App Bar & Search Pill
  // ---------------------------------------------------------------------------
  Widget _buildTopSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: const Center(
                child: JtakBackIcon(size: 20),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Search Field Pill
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const JtakSearchIcon(
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      cursorColor: kPrimaryOrange,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: kCharcoalDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث في $_displayMarketName...',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF9CA3AF),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      onSubmitted: (val) {
                        final trimmed = val.trim();
                        if (trimmed.isNotEmpty) {
                          _addRecentSearch(trimmed);
                        }
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.close_rounded,
                          color: Color(0xFF1F2937),
                          size: 20,
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
  // Initial View: 4-Boxes "المنتجات الأكثر بحثاً"
  // ---------------------------------------------------------------------------
  Widget _buildInitialStateView() {
    final hasRecent = _recentSearches.isNotEmpty;
    final hasTopSearched = _topSearchedBoxes.isNotEmpty;

    if (!hasRecent && !hasTopSearched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'ابحث عن أي منتج في $_displayMarketName',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        top: 18,
        bottom: _cartItemCount > 0 ? 120 : 30,
      ),
      children: [
        // 1. عمليات البحث الأخيرة (Above most searched products)
        if (hasRecent) ...[
          _buildRecentSearchesSection(),
          if (hasTopSearched) const SizedBox(height: 24),
        ],

        // 2. المنتجات الأكثر بحثاً (Without fire icon)
        if (hasTopSearched)
          _buildMostSearchedSection(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section: عمليات البحث الأخيرة
  // ---------------------------------------------------------------------------
  Widget _buildRecentSearchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عمليات البحث الأخيرة',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Text(
                    'مسح السجل',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((term) {
              return GestureDetector(
                onTap: () => _triggerSearch(term),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
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
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeRecentSearch(term),
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                          size: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section: المنتجات الأكثر بحثاً (4-Boxes without fire icon)
  // ---------------------------------------------------------------------------
  Widget _buildMostSearchedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title: "المنتجات الأكثر بحثاً" (No Fire Icon)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'المنتجات الأكثر بحثاً',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 18.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 4 Horizontal Boxes Next to Each Other (4 Columns Grid)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - (3 * 10)) / 4;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _topSearchedBoxes.map((box) {
                  return GestureDetector(
                    onTap: () => _triggerSearch(box.searchQuery),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: itemWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Box Container with Image (Full width & height)
                          Container(
                            width: itemWidth,
                            height: itemWidth,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4F6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: box.imageUrl.startsWith('assets')
                                  ? Image.asset(
                                      box.imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFFF4F4F6),
                                        child: const Center(
                                          child: Icon(
                                            Icons.shopping_bag_rounded,
                                            color: kPrimaryOrange,
                                            size: 26,
                                          ),
                                        ),
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: box.imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      placeholder: (_, __) => Container(color: const Color(0xFFF4F4F6)),
                                      errorWidget: (_, __, ___) => Container(
                                        color: const Color(0xFFF4F4F6),
                                        child: const Center(
                                          child: Icon(
                                            Icons.shopping_bag_rounded,
                                            color: kPrimaryOrange,
                                            size: 26,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Name under the box
                          Text(
                            box.title,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: kCharcoalDark,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Live Suggestions Results (Clean Horizontal Product Rows)
  // ---------------------------------------------------------------------------
  Widget _buildLiveResultsList(List<MarketProductItem> products) {
    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        top: 8,
        bottom: _cartItemCount > 0 ? 120 : 30,
      ),
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(
        color: Color(0xFFF3F4F6),
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        final qty = _cartQuantities[product.id] ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product Image & Info Column (Tappable to open MarketProductDetailPage)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MarketProductDetailPage(
                          product: product,
                          marketId: widget.marketId,
                          marketName: widget.marketName,
                          allMarketProducts: widget.products,
                          initialQuantity: _cartQuantities[product.id] ?? 0,
                          totalCartCount: _cartItemCount,
                          onCartChanged: (productId, newQty) {
                            setState(() {
                              if (newQty <= 0) {
                                _cartQuantities.remove(productId);
                              } else {
                                _cartQuantities[productId] = newQty;
                              }
                            });
                            widget.onCartChanged?.call(productId, newQty);
                          },
                        ),
                      ),
                    ).then((_) {
                      if (mounted) {
                        final cart = locator<CartProvider>();
                        setState(() {
                          for (final item in widget.products) {
                            final q = cart.getProductQuantity(item.id);
                            if (q > 0) {
                              _cartQuantities[item.id] = q;
                            } else {
                              _cartQuantities.remove(item.id);
                            }
                          }
                        });
                      }
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      // Product Image (72x72 rounded squircle, full bleed cover)
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: product.imageUrl.startsWith('assets')
                              ? Image.asset(
                                  product.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: Icon(
                                        Icons.shopping_bag_outlined,
                                        color: Color(0xFFCBD5E1),
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: product.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (_, __) => Container(color: const Color(0xFFF1F5F9)),
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: Icon(
                                        Icons.shopping_bag_outlined,
                                        color: Color(0xFFCBD5E1),
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Title, Category, and Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.title,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: kCharcoalDark,
                                fontSize: 15.0,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.category,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: const Color(0xFF6B7280),
                                fontSize: 12.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              product.price,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: kPrimaryOrange,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Interactive Add to Cart Button / Counter
              if (qty == 0)
                GestureDetector(
                  onTap: () => _onPlusTapped(product.id),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kPrimaryOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _onPlusTapped(product.id),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 32,
                          height: 36,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.add_rounded,
                            color: kPrimaryOrange,
                            size: 18,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '$qty',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: kCharcoalDark,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _onMinusTapped(product.id),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 32,
                          height: 36,
                          alignment: Alignment.center,
                          child: Icon(
                            qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                            color: qty == 1 ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State (When no products match search query)
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0E8),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  color: kPrimaryOrange,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'لم نعثر على ما طلبت',
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرّب البحث بكلمات أخرى أو اختر من المنتجات الأكثر بحثاً',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                color: const Color(0xFF9CA3AF),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Floating Bottom Delivery / Cart Bar
  // ---------------------------------------------------------------------------
  Widget _buildBottomDeliveryBar() {
    final int totalPrice = _cartTotalPrice;
    final bool meetsMinOrder = totalPrice >= _minOrderTarget;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Target Min Order Progress or Success
          Row(
            children: [
              Icon(
                meetsMinOrder
                    ? PhosphorIconsFill.checkCircle
                    : PhosphorIconsFill.info,
                color: meetsMinOrder ? const Color(0xFF10B981) : kPrimaryOrange,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  meetsMinOrder
                      ? 'تم الوصول إلى الحد الأدنى للطلب'
                      : 'أضف بقيمة ${_formatPrice(_minOrderTarget - totalPrice)} ل.س للوصول للحد الأدنى',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: meetsMinOrder
                        ? const Color(0xFF10B981)
                        : const Color(0xFF4B5563),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: View Cart Button with Price & Count
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, CartPage.routeName).then((_) {
                if (mounted) {
                  final cart = locator<CartProvider>();
                  setState(() {
                    for (final item in widget.products) {
                      final q = cart.getProductQuantity(item.id);
                      if (q > 0) {
                        _cartQuantities[item.id] = q;
                      } else {
                        _cartQuantities.remove(item.id);
                      }
                    }
                  });
                }
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: kPrimaryOrange,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_cartItemCount',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'عرض السلة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_formatPrice(totalPrice)} ل.س',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w900,
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
}

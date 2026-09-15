import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/services/locator.dart';
import '../../widgets/catalog/replace_cart_bottom_sheet.dart';
import '../../widgets/header_circle_button.dart';
import '../cart/cart_page.dart';
import 'market_page.dart';
import 'market_product_detail_page.dart';
import 'market_search_page.dart';
import '../../widgets/catalog/market_product_card.dart';

/// ---------------------------------------------------------------------------
/// JTAK Market Category Products Page (صفحة منتجات الفئة وتصفية التصنيفات الفرعية)
///
/// Features:
/// 1. Top Header: Back action, Main Category Title, Branded Store Badge, and Search action.
/// 2. Sub-categories Horizontal Circular Carousel:
///    - Circle 0: "الكل" (All) - Selected by default, displays all products of the main category.
///    - Circles 1..N: Sub-category circular avatars with real photo thumbnails and active highlight.
/// 3. Filtered 2-Column Responsive Product Grid:
///    - Dynamically filtered based on active sub-category circle.
///    - Morphing (+) stepper synchronized with CartProvider.
///    - Heart favorites toggle.
/// 4. Persistent Bottom Cart / Minimum Order Bar.
/// ---------------------------------------------------------------------------

class MarketCategoryProductsPage extends StatefulWidget {
  static const String routeName = '/MarketCategoryProductsPage';

  final int marketId;
  final String marketName;
  final String selectedMainCategory;
  final List<MarketProductItem> allMarketProducts;
  final String? initialSelectedSubCategory;
  final String? logoUrl;

  const MarketCategoryProductsPage({
    super.key,
    required this.marketId,
    required this.marketName,
    required this.selectedMainCategory,
    required this.allMarketProducts,
    this.initialSelectedSubCategory,
    this.logoUrl,
  });

  @override
  State<MarketCategoryProductsPage> createState() =>
      _MarketCategoryProductsPageState();
}

class _MarketCategoryProductsPageState
    extends State<MarketCategoryProductsPage> {
  late String _currentSubCategory;
  late List<String> _subCategories;
  final Map<String, String> _subCategoryThumbnails = {};
  final ScrollController _subCategoryScrollController = ScrollController();
  final ScrollController _productsScrollController = ScrollController();

  static const double _maxBottomBarHeight = 130.0;
  int get _minOrderTarget =>
      locator<CartProvider>().currentMerchantMinOrder > 0
          ? locator<CartProvider>().currentMerchantMinOrder
          : 50000;

  @override
  void initState() {
    super.initState();
    _initSubCategories();
    _currentSubCategory = widget.initialSelectedSubCategory != null &&
            widget.initialSelectedSubCategory!.trim().isNotEmpty &&
            _subCategories.contains(widget.initialSelectedSubCategory)
        ? widget.initialSelectedSubCategory!
        : 'الكل';
  }

  @override
  void dispose() {
    _subCategoryScrollController.dispose();
    _productsScrollController.dispose();
    super.dispose();
  }

  void _initSubCategories() {
    final selected = widget.selectedMainCategory.trim();
    // 1. Filter products belonging to this main category
    final mainCatProducts = widget.allMarketProducts.where((p) {
      final pMain = p.mainCategory.trim();
      final pCat = p.category.trim();
      return pMain == selected ||
          pCat == selected ||
          (selected.isNotEmpty && pMain.contains(selected)) ||
          (pMain.isNotEmpty && selected.contains(pMain));
    }).toList();

    // 2. Extract distinct subcategories and capture representative thumbnail photo
    final seen = <String>{};
    final List<String> subs = ['الكل'];

    for (final p in mainCatProducts) {
      final sub = p.subCategory.trim();
      if (sub.isNotEmpty && sub != 'عام' && !seen.contains(sub)) {
        seen.add(sub);
        subs.add(sub);
        if (p.imageUrl.isNotEmpty &&
            (p.imageUrl.startsWith('http') || p.imageUrl.startsWith('assets/'))) {
          _subCategoryThumbnails[sub] = p.imageUrl;
        }
      }
    }

    _subCategories = subs;
  }

  List<MarketProductItem> get _filteredProducts {
    final selected = widget.selectedMainCategory.trim();
    final mainCatProducts = widget.allMarketProducts.where((p) {
      final pMain = p.mainCategory.trim();
      final pCat = p.category.trim();
      return pMain == selected ||
          pCat == selected ||
          (selected.isNotEmpty && pMain.contains(selected)) ||
          (pMain.isNotEmpty && selected.contains(pMain));
    }).toList();

    if (_currentSubCategory == 'الكل') {
      return mainCatProducts;
    }

    final currentSub = _currentSubCategory.trim();
    final filtered = mainCatProducts.where((p) {
      final pSub = p.subCategory.trim();
      final pCat = p.category.trim();
      return pSub == currentSub || pCat == currentSub;
    }).toList();

    return filtered.isNotEmpty ? filtered : mainCatProducts;
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _onPlusTapped(MarketProductItem product) async {
    final cart = locator<CartProvider>();
    if (cart.isDifferentMerchant(widget.marketId)) {
      final shouldReplace = await ReplaceCartBottomSheet.show(
        context,
        currentStoreName: cart.getConflictingMerchantName(widget.marketId),
        newStoreName: widget.marketName,
      );
      if (shouldReplace != true || !mounted) return;
      await cart.replaceCartWithItem(
        product.id,
        widget.marketId,
        product.priceValue.toDouble(),
        1,
        title: product.title,
        imageUrl: product.imageUrl,
      );
      return;
    }

    final currentQty = cart.getProductQuantity(product.id);
    final newQty = currentQty + 1;
    cart.setToCart(
      product.id,
      widget.marketId,
      product.priceValue.toDouble(),
      newQty,
      title: product.title,
      imageUrl: product.imageUrl,
    );
  }

  void _onMinusTapped(MarketProductItem product) {
    final cart = locator<CartProvider>();
    final currentQty = cart.getProductQuantity(product.id);
    if (currentQty <= 1) {
      cart.removeFromCart(product.id, widget.marketId);
    } else {
      cart.setToCart(
        product.id,
        widget.marketId,
        product.priceValue.toDouble(),
        currentQty - 1,
        title: product.title,
        imageUrl: product.imageUrl,
      );
    }
  }

  void _openProductDetail(MarketProductItem product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketProductDetailPage(
          product: product,
          marketId: widget.marketId,
          marketName: widget.marketName,
          allMarketProducts: widget.allMarketProducts,
          initialQuantity: locator<CartProvider>().getProductQuantity(product.id),
          totalCartCount: locator<CartProvider>().totalQuantity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 1. Top Header
                  _buildHeader(),

                  // 2. Sub-categories Horizontal Circular Carousel
                  _buildSubCategoryCarousel(),

                  const Divider(height: 1, color: Color(0xFFE5E7EB)),

                  // 3. Filter info bar & Products Grid
                  Expanded(
                    child: products.isEmpty
                        ? _buildEmptyFilteredState()
                        : CustomScrollView(
                            controller: _productsScrollController,
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              // Filter Info Header
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _currentSubCategory == 'الكل'
                                            ? 'جميع منتجات ${widget.selectedMainCategory}'
                                            : _currentSubCategory,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          color: kCharcoalDark,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                              color: const Color(0xFFDBEAFE)),
                                        ),
                                        child: Text(
                                          '${products.length} منتج',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            color: const Color(0xFF1D4ED8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 2-Column Product Grid
                              SliverPadding(
                                padding: EdgeInsets.only(
                                  left: 14,
                                  right: 14,
                                  top: 4,
                                  bottom: _maxBottomBarHeight + 20,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 0.74,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final product = products[index];
                                      return _buildGridProductCard(product);
                                    },
                                    childCount: products.length,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),

              // 4. Persistent Bottom Cart / Delivery Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomCartBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Top Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    final isClover = widget.marketId == 19;
    final brandColor = isClover ? const Color(0xFF047857) : const Color(0xFF1D4ED8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 42,
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

          const SizedBox(width: 12),

          // Main Category Title & Store Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.selectedMainCategory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: kCharcoalDark,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: brandColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.marketName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: brandColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarketSearchPage(
                    marketId: widget.marketId,
                    marketName: widget.marketName,
                    logoUrl: widget.logoUrl,
                    products: _filteredProducts,
                    initialCartQuantities: {
                      for (final p in _filteredProducts)
                        if (locator<CartProvider>().getProductQuantity(p.id) > 0)
                          p.id: locator<CartProvider>().getProductQuantity(p.id)
                    },
                  ),
                ),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
              ),
              child: const Center(
                child: JtakSearchIcon(size: 19, color: Color(0xFF4B5563)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Sub-categories Horizontal Circular Carousel
  // ---------------------------------------------------------------------------
  Widget _buildSubCategoryCarousel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          controller: _subCategoryScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _subCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final subName = _subCategories[index];
            final isAll = subName == 'الكل';
            final isSelected = _currentSubCategory == subName;
            final photoUrl = _subCategoryThumbnails[subName];

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _currentSubCategory = subName;
                });
                if (_productsScrollController.hasClients) {
                  _productsScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circular Avatar Container
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? (isAll ? kPrimaryOrange : Colors.white)
                            : const Color(0xFFF9FAFB),
                        border: Border.all(
                          color: isSelected ? kPrimaryOrange : const Color(0xFFE5E7EB),
                          width: isSelected ? 2.6 : 1.2,
                        ),
                      ),
                      child: ClipOval(
                        child: isAll
                            ? Center(
                                child: Icon(
                                  PhosphorIconsFill.squaresFour,
                                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                                  size: 28,
                                ),
                              )
                            : (photoUrl != null && photoUrl.isNotEmpty
                                ? (photoUrl.startsWith('assets/')
                                    ? Image.asset(
                                        photoUrl,
                                        width: 66,
                                        height: 66,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _buildFallbackCircleIcon(subName),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: photoUrl,
                                        width: 66,
                                        height: 66,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            _buildFallbackCircleIcon(subName),
                                      ))
                                : _buildFallbackCircleIcon(subName)),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Label Underneath
                    Text(
                      subName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isSelected ? kPrimaryOrange : const Color(0xFF4B5563),
                        fontSize: 12.0,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallbackCircleIcon(String subName) {
    IconData icon = Icons.shopping_bag_outlined;
    final s = subName.toLowerCase();
    if (s.contains('خضار') || s.contains('فواكه') || s.contains('طازج')) {
      icon = Icons.eco_rounded;
    } else if (s.contains('حليب') || s.contains('ألبان') || s.contains('أجبان') || s.contains('اجبان')) {
      icon = Icons.egg_rounded;
    } else if (s.contains('شيبس') || s.contains('بسكوت') || s.contains('سناك') || s.contains('شوكولا')) {
      icon = Icons.cookie_rounded;
    } else if (s.contains('عصير') || s.contains('مشروب') || s.contains('مياه') || s.contains('غازية')) {
      icon = Icons.local_drink_rounded;
    } else if (s.contains('غسيل') || s.contains('صابون') || s.contains('تنظيف') || s.contains('محارم')) {
      icon = Icons.cleaning_services_rounded;
    } else if (s.contains('لحم') || s.contains('دجاج')) {
      icon = Icons.set_meal_rounded;
    } else if (s.contains('قهوة') || s.contains('شاي')) {
      icon = Icons.coffee_rounded;
    }

    return Center(
      child: Icon(
        icon,
        color: const Color(0xFF94A3B8),
        size: 26,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Grid Product Card
  // ---------------------------------------------------------------------------
  Widget _buildGridProductCard(MarketProductItem product) {
    return MarketProductCard(
      product: product,
      marketId: widget.marketId,
      onProductTap: () => _openProductDetail(product),
      onPlusTap: () => _onPlusTapped(product),
      onMinusTap: () => _onMinusTapped(product),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State for Filter
  // ---------------------------------------------------------------------------
  Widget _buildEmptyFilteredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد منتجات متوفرة في هذا القسم حالياً',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentSubCategory = 'الكل';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                'عرض جميع منتجات الفئة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Persistent Bottom Minimum Order / Active Cart Bar (Matches MarketPage)
  // ---------------------------------------------------------------------------
  Widget _buildBottomCartBar() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final count = cart.totalQuantity;
        if (count == 0) {
          return const SizedBox.shrink();
        }

        final total = cart.subtotal.toInt();
        final target = cart.currentMerchantMinOrder > 0
            ? cart.currentMerchantMinOrder
            : _minOrderTarget;
        final progress = (total / target).clamp(0.0, 1.0);
        final remaining = target - total;
        final bool reachedMin = total >= target;

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
                                        duration: const Duration(milliseconds: 350),
                                        curve: Curves.easeOutCubic,
                                        width: fillWidth,
                                        height: 3.5,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1F2937),
                                          borderRadius: BorderRadius.circular(2),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartPage()),
                  );
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
                                color: Color(0x38000000), // Dark translucent badge matching reference
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: AnimatedCounterText(
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

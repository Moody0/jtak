import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/favorite_product_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/services/locator.dart';
import '../../widgets/catalog/replace_cart_bottom_sheet.dart';
import '../../widgets/header_circle_button.dart';
import '../cart/cart_page.dart';
import 'market_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Market Dedicated Product Detail Page
///
/// Distinctive, high-craft mobile UI designed specifically for local supermarket
/// and grocery shopping in Syria/Damascus.
/// ---------------------------------------------------------------------------

class MarketProductDetailPage extends StatefulWidget {
  static const String routeName = '/MarketProductDetailPage';

  final MarketProductItem product;
  final int marketId;
  final String marketName;
  final List<MarketProductItem> allMarketProducts;
  final int initialQuantity;
  final int totalCartCount;
  final void Function(int productId, int newQty)? onCartChanged;

  const MarketProductDetailPage({
    super.key,
    required this.product,
    required this.marketId,
    required this.marketName,
    required this.allMarketProducts,
    this.initialQuantity = 0,
    this.totalCartCount = 0,
    this.onCartChanged,
  });

  @override
  State<MarketProductDetailPage> createState() =>
      _MarketProductDetailPageState();
}

class _MarketProductDetailPageState extends State<MarketProductDetailPage> {
  late int _quantity;

  int get _cartCount => locator<CartProvider>().totalQuantity;

  final Map<int, int> _companionQuantities = {};
  final Set<int> _expandedCompanionIds = {};

  void _syncCartFromProvider() {
    if (!mounted) return;
    final cart = locator<CartProvider>();
    setState(() {
      _quantity = cart.getProductQuantity(widget.product.id);
      _companionQuantities.clear();
      for (final companion in widget.allMarketProducts) {
        final q = cart.getProductQuantity(companion.id);
        if (q > 0) {
          _companionQuantities[companion.id] = q;
        } else {
          _expandedCompanionIds.remove(companion.id);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    locator<CartProvider>().addListener(_syncCartFromProvider);
    _syncCartFromProvider();
  }

  @override
  void dispose() {
    locator<CartProvider>().removeListener(_syncCartFromProvider);
    super.dispose();
  }

  void _onAddToCart() async {
    final cart = locator<CartProvider>();
    if (cart.isDifferentMerchant(widget.marketId)) {
      final shouldReplace = await ReplaceCartBottomSheet.show(
        context,
        currentStoreName: cart.currentMerchantName,
        newStoreName: widget.marketName,
      );
      if (shouldReplace != true || !mounted) return;
      await cart.replaceCartWithItem(
        widget.product.id,
        widget.marketId,
        widget.product.priceValue.toDouble(),
        1,
      );
      setState(() {
        _quantity = 1;
        _companionQuantities.clear();
        _expandedCompanionIds.clear();
      });
      widget.onCartChanged?.call(widget.product.id, _quantity);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _quantity = 1;
    });
    cart.setToCart(
      widget.product.id,
      widget.marketId,
      widget.product.priceValue.toDouble(),
      1,
    );
    widget.onCartChanged?.call(widget.product.id, _quantity);
  }

  void _onIncrement() {
    HapticFeedback.selectionClick();
    setState(() {
      _quantity += 1;
    });
    locator<CartProvider>().setToCart(
      widget.product.id,
      widget.marketId,
      widget.product.priceValue.toDouble(),
      _quantity,
    );
    widget.onCartChanged?.call(widget.product.id, _quantity);
  }

  void _onDecrement() {
    HapticFeedback.selectionClick();
    if (_quantity <= 0) return;
    setState(() {
      _quantity -= 1;
    });
    if (_quantity <= 0) {
      locator<CartProvider>().removeFromCart(widget.product.id, widget.marketId);
    } else {
      locator<CartProvider>().setToCart(
        widget.product.id,
        widget.marketId,
        widget.product.priceValue.toDouble(),
        _quantity,
      );
    }
    widget.onCartChanged?.call(widget.product.id, _quantity);
  }

  void _onCompanionPlusTapped(int productId) async {
    final cart = locator<CartProvider>();
    if (cart.isDifferentMerchant(widget.marketId)) {
      final shouldReplace = await ReplaceCartBottomSheet.show(
        context,
        currentStoreName: cart.currentMerchantName,
        newStoreName: widget.marketName,
      );
      if (shouldReplace != true || !mounted) return;
      final companionProduct = widget.allMarketProducts.firstWhere(
        (p) => p.id == productId,
        orElse: () => widget.product,
      );
      await cart.replaceCartWithItem(
        productId,
        widget.marketId,
        companionProduct.priceValue.toDouble(),
        1,
      );
      setState(() {
        _quantity = 0;
        _companionQuantities.clear();
        _companionQuantities[productId] = 1;
        _expandedCompanionIds.clear();
        _expandedCompanionIds.add(productId);
      });
      widget.onCartChanged?.call(productId, 1);
      return;
    }

    HapticFeedback.selectionClick();
    final current = _companionQuantities[productId] ?? 0;
    final newQty = current + 1;
    setState(() {
      _companionQuantities[productId] = newQty;
      _expandedCompanionIds.add(productId);
    });
    final companionProduct = widget.allMarketProducts.firstWhere(
      (p) => p.id == productId,
      orElse: () => widget.product,
    );
    cart.setToCart(
      productId,
      widget.marketId,
      companionProduct.priceValue.toDouble(),
      newQty,
    );
    widget.onCartChanged?.call(productId, newQty);
  }

  void _onCompanionMinusTapped(int productId) {
    HapticFeedback.selectionClick();
    final current = _companionQuantities[productId] ?? 0;
    if (current <= 0) return;
    final companionProduct = widget.allMarketProducts.firstWhere(
      (p) => p.id == productId,
      orElse: () => widget.product,
    );

    setState(() {
      if (current == 1) {
        _companionQuantities.remove(productId);
        _expandedCompanionIds.remove(productId);
        locator<CartProvider>().removeFromCart(productId, widget.marketId);
      } else {
        final newQty = current - 1;
        _companionQuantities[productId] = newQty;
        locator<CartProvider>().setToCart(
          productId,
          widget.marketId,
          companionProduct.priceValue.toDouble(),
          newQty,
        );
      }
    });
    widget.onCartChanged?.call(productId, _companionQuantities[productId] ?? 0);
  }

  void _onCompanionCollapsedBadgeTapped(int productId) {
    HapticFeedback.selectionClick();
    setState(() {
      _expandedCompanionIds.add(productId);
    });
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  /// Intelligently select companion items based on category context
  List<MarketProductItem> get _frequentlyBoughtTogether {
    final current = widget.product;
    final otherProducts = widget.allMarketProducts.where((p) => p.id != current.id).toList();

    // Prioritize products from same or complementary categories
    final sameCategory = otherProducts.where((p) => p.category == current.category).toList();
    final otherCategory = otherProducts.where((p) => p.category != current.category).toList();

    final combined = [...sameCategory, ...otherCategory];
    return combined.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final brandName = product.brand ?? widget.marketName;
    final weightLabel = product.weight ?? 'حجم قياسي';
    final relatedProducts = _frequentlyBoughtTogether;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Main Scrollable Product Story
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 124),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Hero Showcase Canvas
                    _buildHeroShowcase(product),

                    // B. Product Identity & Metadata
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brand Name
                          Text(
                            brandName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: kPrimaryOrange,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Product Title
                          Text(
                            product.title,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: const Color(0xFF111827),
                              fontSize: 22.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              height: 1.3,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Weight Spec Capsule
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  PhosphorIconsRegular.scales,
                                  color: Color(0xFF4B5563),
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  weightLabel,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: const Color(0xFF374151),
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (product.description != null &&
                              product.description!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              product.description!,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: const Color(0xFF4B5563),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // C. Divider
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        color: Color(0xFFF3F4F6),
                        thickness: 1.0,
                        height: 20,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // D. "يتم شراؤها معاً عادةً" Horizontal Carousel
                    _buildFrequentlyBoughtSection(relatedProducts),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 2. Floating Top Overlay Navigation (Back on Right, Cart on Left)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button (Top Right in RTL)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0x1F000000),
                              width: 1.0,
                            ),
                          ),
                          child: const Center(
                            child: JtakBackIcon(size: 20),
                          ),
                        ),
                      ),

                      // Top Left Actions (Heart & Cart in RTL)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Favorite Heart Button
                          Consumer<FavoriteProductProvider>(
                            builder: (context, favProvider, _) {
                              final isFav = favProvider.isMealFavorite(widget.product.id);
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  favProvider.toggleMealFavorite(widget.product.id);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0x1F000000),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isFav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                                      color: isFav ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(width: 10),

                          // Cart Button
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, CartPage.routeName).then((_) {
                                if (mounted) {
                                  final cart = locator<CartProvider>();
                                  setState(() {
                                    _quantity = cart.getProductQuantity(widget.product.id);
                                    for (final companion in widget.allMarketProducts) {
                                      final q = cart.getProductQuantity(companion.id);
                                      if (q > 0) {
                                        _companionQuantities[companion.id] = q;
                                      } else {
                                        _companionQuantities.remove(companion.id);
                                      }
                                    }
                                  });
                                  widget.onCartChanged?.call(widget.product.id, _quantity);
                                }
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0x1F000000),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      PhosphorIconsBold.shoppingBag,
                                      color: Color(0xFF111827),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                if (_cartCount > 0)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kPrimaryOrange,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                        minHeight: 20,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$_cartCount',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Sticky Bottom Div with Price & Smooth Up/Down Animated Stepper
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStickyBottomBar(product),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // A. Hero Showcase Canvas (Straight flush bottom edge, not rounded)
  // ---------------------------------------------------------------------------
  Widget _buildHeroShowcase(MarketProductItem product) {
    return Container(
      width: double.infinity,
      height: 340,
      color: const Color(0xFFF9FAFB),
      child: Stack(
        children: [
          // Full-Bleed Product Image (straight bottom edge)
          Positioned.fill(
            child: product.imageUrl.startsWith('assets')
                ? Image.asset(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 340,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: Color(0xFFCBD5E1),
                          size: 54,
                        ),
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 340,
                    placeholder: (_, __) => Container(color: const Color(0xFFF1F5F9)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: Color(0xFFCBD5E1),
                          size: 54,
                        ),
                      ),
                    ),
                  ),
          ),

          // Subtle Top Gradient for Button Contrast
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 90,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // D. "يتم شراؤها معاً عادةً" Horizontal Carousel
  // ---------------------------------------------------------------------------
  Widget _buildFrequentlyBoughtSection(List<MarketProductItem> relatedItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'يتم شراؤها معاً عادةً',
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFF111827),
              fontSize: 18.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),

        const SizedBox(height: 14),

        SizedBox(
          height: 246,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: relatedItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = relatedItems[index];
              return _buildRelatedProductCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedProductCard(MarketProductItem product) {
    final quantityInCart = _companionQuantities[product.id] ?? 0;
    final isExpanded =
        _expandedCompanionIds.contains(product.id) && quantityInCart > 0;

    final double btnWidth = isExpanded ? 124 : 36;
    final double btnHeight = isExpanded ? 38 : 36;
    final double btnRight = isExpanded ? 7 : 9;
    final double btnBottom = isExpanded ? 7 : 9;

    final BoxDecoration btnDecoration = isExpanded
        ? BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
          )
        : (quantityInCart > 0
            ? BoxDecoration(
                color: kPrimaryOrange,
                borderRadius: BorderRadius.circular(18),
              )
            : BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
              ));

    return SizedBox(
      width: 142,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // White Squircle Card with Image & Animated Morphing Stepper / Button
          Container(
            width: 142,
            height: 142,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEBEBEF), width: 1.1),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Product Image (Takes full width and height with BoxFit.fill)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MarketProductDetailPage(
                            product: product,
                            marketId: widget.marketId,
                            marketName: widget.marketName,
                            allMarketProducts: widget.allMarketProducts,
                            initialQuantity: _companionQuantities[product.id] ?? 0,
                            totalCartCount: _cartCount,
                            onCartChanged: widget.onCartChanged,
                          ),
                        ),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: product.imageUrl.startsWith('assets')
                          ? Image.asset(
                              product.imageUrl,
                              width: 142,
                              height: 142,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Color(0xFFCBD5E1),
                                  size: 38,
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: product.imageUrl,
                              width: 142,
                              height: 142,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Color(0xFFCBD5E1),
                                  size: 38,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

                // Smoothly Morphing Button
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                  right: btnRight,
                  bottom: btnBottom,
                  width: btnWidth,
                  height: btnHeight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    decoration: btnDecoration,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        child: isExpanded
                            ? OverflowBox(
                                key: const ValueKey('expanded_stepper'),
                                minWidth: 124,
                                maxWidth: 124,
                                minHeight: 38,
                                maxHeight: 38,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: 124,
                                  height: 38,
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Minus Button (Left)
                                        GestureDetector(
                                          onTap: () =>
                                              _onCompanionMinusTapped(product.id),
                                          behavior: HitTestBehavior.opaque,
                                          child: const SizedBox(
                                            width: 36,
                                            height: 38,
                                            child: Center(
                                              child: Icon(
                                                Icons.remove_rounded,
                                                color: kPrimaryOrange,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Animated Sliding Number (Center)
                                        _AnimatedCounterText(
                                          count: quantityInCart,
                                          style:
                                              GoogleFonts.ibmPlexSansArabic(
                                            color: const Color(0xFF111827),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),

                                        // Plus Button (Right)
                                        GestureDetector(
                                          onTap: () =>
                                              _onCompanionPlusTapped(product.id),
                                          behavior: HitTestBehavior.opaque,
                                          child: const SizedBox(
                                            width: 36,
                                            height: 38,
                                            child: Center(
                                              child: Icon(
                                                Icons.add_rounded,
                                                color: kPrimaryOrange,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : (quantityInCart > 0
                                ? GestureDetector(
                                    key: const ValueKey('collapsed_badge'),
                                    onTap: () =>
                                        _onCompanionCollapsedBadgeTapped(
                                            product.id),
                                    behavior: HitTestBehavior.opaque,
                                    child: Center(
                                      child: _AnimatedCounterText(
                                        count: quantityInCart,
                                        style:
                                            GoogleFonts.ibmPlexSansArabic(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  )
                                : GestureDetector(
                                    key: const ValueKey('default_add_btn'),
                                    onTap: () =>
                                        _onCompanionPlusTapped(product.id),
                                    behavior: HitTestBehavior.opaque,
                                    child: const Center(
                                      child: Icon(
                                        Icons.add_rounded,
                                        color: kPrimaryOrange,
                                        size: 21,
                                      ),
                                    ),
                                  )),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 7),

          // Product Title & Price
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MarketProductDetailPage(
                    product: product,
                    marketId: widget.marketId,
                    marketName: widget.marketName,
                    allMarketProducts: widget.allMarketProducts,
                    initialQuantity: _companionQuantities[product.id] ?? 0,
                    totalCartCount: _cartCount,
                    onCartChanged: widget.onCartChanged,
                  ),
                ),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF111827),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Sticky Bottom Div (Price + Add to Cart Stepper with Vertical Number Ticker)
  // ---------------------------------------------------------------------------
  Widget _buildStickyBottomBar(MarketProductItem product) {
    final int itemTotal =
        _quantity > 0 ? (product.priceValue * _quantity) : product.priceValue;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Price Column (Right side in RTL)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'السعر الإجمالي',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatPrice(itemTotal)} ل.س',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF111827),
                    fontSize: 20.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 20),

            // Action Button: Either "أضف إلى السلة" OR Stepper "[-]  qty  [+]"
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _quantity == 0
                    ? GestureDetector(
                        key: const ValueKey('add_to_cart_btn'),
                        onTap: _onAddToCart,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: kPrimaryOrange,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                PhosphorIconsBold.shoppingBagOpen,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'أضف إلى السلة',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: Colors.white,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        key: const ValueKey('quantity_stepper'),
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1.2,
                          ),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Minus Button (Left)
                              GestureDetector(
                                onTap: _onDecrement,
                                behavior: HitTestBehavior.opaque,
                                child: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Center(
                                    child: Icon(
                                      Icons.remove_rounded,
                                      color: kPrimaryOrange,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),

                              // Animated Vertical Ticker for Counter Number
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ClipRect(
                                    child: Center(
                                      child: _AnimatedCounterText(
                                        count: _quantity,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          color: const Color(0xFF111827),
                                          fontSize: 18.0,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Plus Button (Right)
                              GestureDetector(
                                onTap: _onIncrement,
                                behavior: HitTestBehavior.opaque,
                                child: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Center(
                                    child: Icon(
                                      Icons.add_rounded,
                                      color: kPrimaryOrange,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Animated Counter Text (Continuous Rolling Tape / Wheel Animation)
///
/// Top and bottom numbers are attached on a continuous vertical strip:
/// - When increasing: the strip scrolls UP (old exits top, new enters bottom).
/// - When decreasing: the strip scrolls DOWN (old exits bottom, new enters top).
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
        (widget.style.fontSize ?? 16.0) * (widget.style.height ?? 1.25);
    final double slotHeight = textHeight.clamp(24.0, 36.0);

    return SizedBox(
      width: 36,
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

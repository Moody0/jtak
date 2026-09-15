import 'dart:async';
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
import '../../pages/catalog/market_page.dart';
import '../clean_shimmer_skeletons.dart';

/// ---------------------------------------------------------------------------
/// Shared Market Product Card Component
///
/// Matches the high-polish card design from MarketPage:
/// - Rounded white squircle image container with subtle outline border
/// - Floating top-left circular favorite heart button
/// - Smooth animated morphing Quick-Add (+) / Stepper button at bottom-right
/// - Clean title (max 2 lines) and bold orange price underneath
/// - Supports both fixed width (horizontal carousels) and flexible width (2-col grid)
/// - Self-contained reactive counter that updates instantly without reloading the parent page!
/// ---------------------------------------------------------------------------
class MarketProductCard extends StatefulWidget {
  final MarketProductItem product;
  final int? quantityInCart;
  final bool? isExpanded;
  final VoidCallback onProductTap;
  final VoidCallback? onPlusTap;
  final VoidCallback? onMinusTap;
  final VoidCallback? onCollapsedBadgeTap;
  final double? width;
  final int? marketId;

  const MarketProductCard({
    super.key,
    required this.product,
    this.quantityInCart,
    this.isExpanded,
    required this.onProductTap,
    this.onPlusTap,
    this.onMinusTap,
    this.onCollapsedBadgeTap,
    this.width,
    this.marketId,
  });

  @override
  State<MarketProductCard> createState() => _MarketProductCardState();
}

class _MarketProductCardState extends State<MarketProductCard> {
  bool _localExpanded = false;
  Timer? _collapseTimer;

  void _resetCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _localExpanded = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _handlePlus() {
    HapticFeedback.selectionClick();
    setState(() {
      _localExpanded = true;
    });
    _resetCollapseTimer();
    if (widget.onPlusTap != null) {
      widget.onPlusTap!();
    } else {
      final cart = locator<CartProvider>();
      final newQty = cart.getProductQuantity(widget.product.id) + 1;
      cart.setToCart(
        widget.product.id,
        widget.marketId ?? 0,
        widget.product.priceValue.toDouble(),
        newQty,
        title: widget.product.title,
        imageUrl: widget.product.imageUrl,
      );
    }
  }

  void _handleMinus() {
    HapticFeedback.selectionClick();
    _resetCollapseTimer();
    if (widget.onMinusTap != null) {
      widget.onMinusTap!();
    } else {
      final cart = locator<CartProvider>();
      final current = cart.getProductQuantity(widget.product.id);
      if (current <= 1) {
        cart.removeFromCart(widget.product.id, widget.marketId ?? 0);
        setState(() {
          _localExpanded = false;
        });
      } else {
        cart.setToCart(
          widget.product.id,
          widget.marketId ?? 0,
          widget.product.priceValue.toDouble(),
          current - 1,
          title: widget.product.title,
          imageUrl: widget.product.imageUrl,
        );
      }
    }
  }

  void _handleCollapsedBadgeTap() {
    HapticFeedback.selectionClick();
    setState(() {
      _localExpanded = true;
    });
    _resetCollapseTimer();
    if (widget.onCollapsedBadgeTap != null) {
      widget.onCollapsedBadgeTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<CartProvider, int>(
      selector: (_, cart) => cart.getProductQuantity(widget.product.id),
      builder: (context, cartQty, _) {
        final product = widget.product;
        final width = widget.width;
        final onProductTap = widget.onProductTap;
        final quantityInCart = widget.quantityInCart ?? cartQty;
        final bool expanded = (widget.isExpanded ?? _localExpanded) && quantityInCart > 0;

        final double btnWidth = expanded ? 112 : 34;
        final double btnHeight = expanded ? 36 : 34;
        final double btnRight = expanded ? 6 : 8;
        final double btnBottom = expanded ? 6 : 8;

        final BoxDecoration btnDecoration = expanded
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              )
            : (quantityInCart > 0
                ? BoxDecoration(
                    color: kPrimaryOrange,
                    borderRadius: BorderRadius.circular(17),
                  )
                : BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  ));

    Widget imageBox = Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEBEBEF), width: 1.1),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Product Image (Fills container completely with cover fit)
          Positioned.fill(
            child: GestureDetector(
              onTap: onProductTap,
              behavior: HitTestBehavior.opaque,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: product.imageUrl.startsWith('assets')
                    ? Image.asset(
                        product.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF8FAFC),
                          child: const Center(
                            child: Icon(
                              Icons.shopping_basket_rounded,
                              color: Color(0xFFCBD5E1),
                              size: 36,
                            ),
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
                        fadeOutDuration: const Duration(milliseconds: 150),
                        placeholder: (_, __) => const CleanShimmer(
                          child: SizedBox.expand(
                            child: ColoredBox(color: Colors.white),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFF8FAFC),
                          child: const Center(
                            child: Icon(
                              Icons.shopping_basket_rounded,
                              color: Color(0xFFCBD5E1),
                              size: 36,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // Top-Left Favorite Button (Heart)
          Positioned(
            top: 8,
            left: 8,
            child: Consumer<FavoriteProductProvider>(
              builder: (context, favProvider, _) {
                final isFav = favProvider.isMealFavorite(product.id);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    favProvider.toggleMealFavorite(product.id, product);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFE2E8F0), width: 1.0),
                    ),
                    child: Center(
                      child: Icon(
                        isFav
                            ? PhosphorIconsFill.heart
                            : PhosphorIconsRegular.heart,
                        color: isFav
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF6B7280),
                        size: 16,
                      ),
                    ),
                  ),
                );
              },
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
                borderRadius: BorderRadius.circular(18),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: expanded
                      ? OverflowBox(
                          key: const ValueKey('expanded_stepper'),
                          minWidth: 112,
                          maxWidth: 112,
                          minHeight: 36,
                          maxHeight: 36,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 112,
                            height: 36,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                   // Minus Button (Left)
                                   GestureDetector(
                                     onTap: _handleMinus,
                                     behavior: HitTestBehavior.opaque,
                                     child: const SizedBox(
                                       width: 32,
                                       height: 36,
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
                                   AnimatedCounterText(
                                     count: quantityInCart,
                                     style: GoogleFonts.ibmPlexSansArabic(
                                       color: kCharcoalDark,
                                       fontSize: 15,
                                       fontWeight: FontWeight.w900,
                                     ),
                                   ),

                                   // Plus Button (Right)
                                   GestureDetector(
                                     onTap: _handlePlus,
                                     behavior: HitTestBehavior.opaque,
                                     child: const SizedBox(
                                       width: 32,
                                       height: 36,
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
                               onTap: _handleCollapsedBadgeTap,
                               behavior: HitTestBehavior.opaque,
                               child: Center(
                                 child: AnimatedCounterText(
                                   count: quantityInCart,
                                   style: GoogleFonts.ibmPlexSansArabic(
                                     color: Colors.white,
                                     fontSize: 15,
                                     fontWeight: FontWeight.w900,
                                   ),
                                 ),
                               ),
                             )
                           : GestureDetector(
                               key: const ValueKey('default_add_btn'),
                               onTap: _handlePlus,
                               behavior: HitTestBehavior.opaque,
                               child: const Center(
                                 child: Icon(
                                   Icons.add_rounded,
                                   color: kPrimaryOrange,
                                   size: 20,
                                 ),
                               ),
                             )),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (width == null) {
      imageBox = AspectRatio(
        aspectRatio: 1.0,
        child: imageBox,
      );
    }

    final priceStr = product.price.trim().isNotEmpty
        ? product.price
        : '${product.priceValue} ل.س';

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Grid tiles have a finite height. Let the image yield a few pixels
        // when a two-line title and price need more room, instead of letting
        // the card's column overflow.
        width == null
            ? Flexible(
                fit: FlexFit.loose,
                child: imageBox,
              )
            : imageBox,
        const SizedBox(height: 5),
        // Product Title & Price
        GestureDetector(
          onTap: onProductTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                priceStr,
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
    );

    if (width != null) {
      return SizedBox(width: width, child: cardContent);
    }

    return cardContent;
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// Smooth Continuous Strip Sliding Counter
/// ---------------------------------------------------------------------------
class AnimatedCounterText extends StatefulWidget {
  final int count;
  final TextStyle style;

  const AnimatedCounterText({
    super.key,
    required this.count,
    required this.style,
  });

  @override
  State<AnimatedCounterText> createState() => _AnimatedCounterTextState();
}

class _AnimatedCounterTextState extends State<AnimatedCounterText>
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
  void didUpdateWidget(covariant AnimatedCounterText oldWidget) {
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
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
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
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
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

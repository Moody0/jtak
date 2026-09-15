import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/favorite_product_provider.dart';
import '../clean_shimmer_skeletons.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

/// ---------------------------------------------------------------------------
/// JTAK Meal / Dish Quick-Add Card Component (Card Design #3)
///
/// Features:
/// - 18px rounded compact card with unified outline border (kCardBorderColor)
/// - Height: 225px with ETA/Distance anchored firmly to the very bottom
/// - Food Cover image (110px) with:
///   * Floating Merchant Logo at the BOTTOM-RIGHT (42x42 with 11px radius)
///   * Floating Quick-Add (+) Button at the BOTTOM-LEFT (36x36 circular peach button)
/// - Bold meal title, bold red price, and pinned bottom metadata row
/// ---------------------------------------------------------------------------

class MealItemData {
  final int id;
  final String title;
  final String price;
  final String coverUrl;
  final String merchantLogoUrl;
  final String merchantName;
  final String eta;
  final String distance;
  final int merchantId;
  final double numericPrice;
  final bool isMarket;

  const MealItemData({
    required this.id,
    required this.title,
    required this.price,
    required this.coverUrl,
    required this.merchantLogoUrl,
    required this.merchantName,
    required this.eta,
    required this.distance,
    this.merchantId = 0,
    this.numericPrice = 0.0,
    this.isMarket = false,
  });
}

class JTAKMealCard extends StatelessWidget {
  final MealItemData data;
  final VoidCallback? onTap;
  final VoidCallback? onQuickAdd;
  final VoidCallback? onQuickRemove;
  final ValueChanged<int>? onQuantityChanged;
  final double? width;
  final double? height;
  final bool showMerchantLogo;
  final bool showMetadata;
  final int quantity;

  const JTAKMealCard({
    super.key,
    required this.data,
    this.onTap,
    this.onQuickAdd,
    this.onQuickRemove,
    this.onQuantityChanged,
    this.width = 205,
    this.height = 235,
    this.showMerchantLogo = true,
    this.showMetadata = true,
    this.quantity = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kCardBorderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Food Cover Image with Floating Badges (115px height)
            _buildCoverWithBadges(context),

            // 2. Meal Info Body
            if (showMetadata)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meal / Dish Title (14.5px 2-line wrapped)
                      Text(
                        data.title,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF1F2937),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.22,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Price in Vibrant Brand Orange (Full Width - No Truncation)
                      Text(
                        data.price,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kPrimaryOrange,
                          fontSize: 17.5,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const Spacer(),

                      // Metadata Row (ETA | Distance)
                      Row(
                        children: [
                          Text(
                            data.eta,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: const Color(0xFF6B7280),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '|',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12.0,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            data.distance,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: const Color(0xFF6B7280),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF1F2937),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.price,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: kPrimaryOrange,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _resolveProductCover() {
    if (data.coverUrl.isNotEmpty && !data.coverUrl.contains('_logo.')) {
      return data.coverUrl;
    }
    final title = data.title.toLowerCase();
    final name = data.merchantName.toLowerCase();
    if (title.contains('شاورما') || name.contains('أنس')) {
      return 'assets/images/restaurants/anas_dish.webp';
    } else if (title.contains('كباب') ||
        title.contains('مشاوي') ||
        name.contains('بوابة دمشق')) {
      return 'assets/images/restaurants/damascus_dish.webp';
    } else if (title.contains('فتة') ||
        title.contains('فول') ||
        name.contains('بوز الجدي')) {
      return 'assets/images/restaurants/bouz_dish.webp';
    } else if (title.contains('بوظة') || name.contains('بكداش')) {
      return 'assets/images/restaurants/bakdash_dish.webp';
    } else if (title.contains('سحلب') || name.contains('النوفرة')) {
      return 'assets/images/restaurants/noufara_dish.webp';
    } else if (title.contains('برغر') || name.contains('برغر')) {
      return 'assets/images/restaurants/burger_dish.webp';
    } else if (title.contains('مبرومة') ||
        title.contains('حلويات') ||
        name.contains('داوود')) {
      return 'assets/images/restaurants/dawood_dish.webp';
    } else if (title.contains('لاتيه') ||
        title.contains('قهوة') ||
        name.contains('أرت')) {
      return 'assets/images/restaurants/art_dish.webp';
    }
    return data.coverUrl;
  }

  String _resolveMerchantLogo() {
    if (data.merchantLogoUrl.isNotEmpty &&
        data.merchantLogoUrl != data.coverUrl &&
        !data.merchantLogoUrl.contains('_dish.')) {
      return data.merchantLogoUrl;
    }
    final name = data.merchantName.toLowerCase();
    if (name.contains('أنس') || name.contains('شاورما')) {
      return 'assets/images/restaurants/anas_logo.webp';
    } else if (name.contains('مشاوي') ||
        name.contains('كباب') ||
        name.contains('بوابة دمشق')) {
      return 'assets/images/restaurants/damascus_logo.webp';
    } else if (name.contains('بوز الجدي') ||
        name.contains('فول') ||
        name.contains('فتات')) {
      return 'assets/images/restaurants/bouz_logo.webp';
    } else if (name.contains('بكداش') || name.contains('بوظة')) {
      return 'assets/images/restaurants/bakdash_logo.webp';
    } else if (name.contains('النوفرة') || name.contains('نوفرة')) {
      return 'assets/images/restaurants/noufara_logo.webp';
    } else if (name.contains('برغر') || name.contains('burger')) {
      return 'assets/images/restaurants/burger_logo.webp';
    } else if (name.contains('داوود') || name.contains('مهنا')) {
      return 'assets/images/restaurants/dawood_logo.webp';
    } else if (name.contains('أرت') || name.contains('art')) {
      return 'assets/images/restaurants/art_logo.webp';
    }
    return data.merchantLogoUrl;
  }

  Widget _buildCoverWithBadges(BuildContext context) {
    final productCover = _resolveProductCover();
    final restaurantLogo = _resolveMerchantLogo();

    return SizedBox(
      height: 115,
      width: double.infinity,
      child: Stack(
        children: [
          // 1. Food Cover Image with 17px Rounded Corners (Product Banner)
          ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: productCover.isNotEmpty
                ? (productCover.startsWith('assets')
                    ? Image.asset(
                        productCover,
                        width: double.infinity,
                        height: 115,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackCover(),
                      )
                    : CachedNetworkImage(
                        imageUrl: productCover,
                        width: double.infinity,
                        height: 115,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 220),
                        fadeOutDuration: const Duration(milliseconds: 150),
                        placeholder: (_, __) => const CleanShimmer(
                          child: SizedBox.expand(
                            child: ColoredBox(color: Colors.white),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _buildFallbackCover(),
                      ))
                : _buildFallbackCover(),
          ),

          // 2. Top-Left Favorite Button (Heart)
          Positioned(
            top: 8,
            left: 8,
            child: Consumer<FavoriteProductProvider>(
              builder: (context, favProvider, _) {
                final isFav = favProvider.isMealFavorite(data.id);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    favProvider.toggleMealFavorite(data.id, data);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                    ),
                    child: Center(
                      child: Icon(
                        isFav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                        color: isFav ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                        size: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Floating Restaurant Logo (Small Square at Bottom-Right in RTL - 42x42)
          if (showMerchantLogo)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11.0),
                  child: restaurantLogo.isNotEmpty
                      ? (restaurantLogo.startsWith('assets')
                          ? Image.asset(
                              restaurantLogo,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                            )
                          : CachedNetworkImage(
                              imageUrl: restaurantLogo,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _buildFallbackLogo(),
                            ))
                      : _buildFallbackLogo(),
                ),
              ),
            ),

          // 4. Floating Interactive Add-To-Cart Stepper (Bottom-Left in RTL)
          Positioned(
            bottom: 8,
            left: 8,
            child: JtakAddToCartButton(
              height: 34,
              initialCount: quantity,
              onIncrement: onQuickAdd,
              onDecrement: onQuickRemove,
              onQuantityChanged: onQuantityChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: const Center(
        child: Icon(Icons.fastfood_rounded, color: Color(0xFFCBD5E1), size: 36),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      color: kSurfaceWarm,
      child: Center(
        child: Text(
          data.merchantName.isNotEmpty ? data.merchantName[0] : 'J',
          style: GoogleFonts.ibmPlexSansArabic(
            color: kPrimaryOrange,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Interactive Add-To-Cart Stepper Button (Exact Market & Restaurant Design)
/// ---------------------------------------------------------------------------
/// ---------------------------------------------------------------------------
/// Interactive Add-To-Cart Stepper Button (Exact Market & Restaurant Design)
/// ---------------------------------------------------------------------------
class JtakAddToCartButton extends StatefulWidget {
  final double height;
  final ValueChanged<int>? onQuantityChanged;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final int initialCount;

  const JtakAddToCartButton({
    super.key,
    this.height = 34,
    this.onQuantityChanged,
    this.onIncrement,
    this.onDecrement,
    this.initialCount = 0,
  });

  @override
  State<JtakAddToCartButton> createState() => _JtakAddToCartButtonState();
}

class _JtakAddToCartButtonState extends State<JtakAddToCartButton> {
  bool _isExpanded = false;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialCount > 0;
    if (_isExpanded) {
      _resetCollapseTimer();
    }
  }

  @override
  void didUpdateWidget(covariant JtakAddToCartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCount != widget.initialCount) {
      if (widget.initialCount <= 0) {
        _collapseTimer?.cancel();
        setState(() {
          _isExpanded = false;
        });
      } else {
        setState(() {
          _isExpanded = true;
        });
        _resetCollapseTimer();
      }
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _resetCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  void _increment() {
    HapticFeedback.lightImpact();
    _resetCollapseTimer();
    widget.onIncrement?.call();
  }

  void _decrement() {
    HapticFeedback.lightImpact();
    if (widget.initialCount <= 1) {
      _collapseTimer?.cancel();
      setState(() {
        _isExpanded = false;
      });
    } else {
      _resetCollapseTimer();
    }
    widget.onDecrement?.call();
  }

  void _onCollapsedTapped() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = true;
    });
    _resetCollapseTimer();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.initialCount;
    final showExpanded = _isExpanded && count > 0;
    const double btnWidth = 104.0;
    const double btnHeight = 34.0;

    final BoxDecoration btnDecoration = showExpanded
        ? BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          )
        : (count > 0
            ? BoxDecoration(
                color: kPrimaryOrange,
                borderRadius: BorderRadius.circular(17),
              )
            : BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ));

    return GestureDetector(
      onTap: () {}, // Absorb taps to prevent outer card navigation
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        width: showExpanded ? btnWidth : 34.0,
        height: btnHeight,
        decoration: btnDecoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: showExpanded
                ? OverflowBox(
                    key: const ValueKey('expanded_stepper'),
                    minWidth: btnWidth,
                    maxWidth: btnWidth,
                    minHeight: btnHeight,
                    maxHeight: btnHeight,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: btnWidth,
                      height: btnHeight,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Minus Button (Left)
                            GestureDetector(
                              onTap: _decrement,
                              behavior: HitTestBehavior.opaque,
                              child: const SizedBox(
                                width: 30,
                                height: btnHeight,
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
                              count: count,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: kCharcoalDark,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),

                            // Plus Button (Right)
                            GestureDetector(
                              onTap: _increment,
                              behavior: HitTestBehavior.opaque,
                              child: const SizedBox(
                                width: 30,
                                height: btnHeight,
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
                : (count > 0
                    ? GestureDetector(
                        key: const ValueKey('collapsed_badge'),
                        onTap: _onCollapsedTapped,
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: _AnimatedCounterText(
                            count: count,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('default_add_btn'),
                        onTap: _increment,
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

// Backward-compatible alias
typedef JtakMealCard = JTAKMealCard;


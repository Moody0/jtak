import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/favorite_product_provider.dart';
import '../../../core/controllers/catalog/markets_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../widgets/catalog/item_customization_sheet.dart';
import '../../widgets/catalog/replace_cart_bottom_sheet.dart';
import '../../widgets/header_circle_button.dart';
import '../cart/cart_page.dart';
import 'restaurant_menu_search_page.dart';
import 'restaurant_reviews_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Restaurant Menu & Profile Page (Exact Match to Reference Mockup)
///
/// Sections:
/// 1. Banner Cover Image with floating Back & Search actions and Status Pill (⚡ مفتوح)
/// 2. Restaurant Overview Card (Logo, Name, Verified Badge, 3-Way Mode Switcher, Fee Metrics)
/// 3. Reviews Card (Rating, Feedback snippet, "عرض الكل" action)
/// 4. Sticky Menu Category Tabs Bar & 2-Column Food Grid with Morphing (+) Add Stepper
/// 5. Persistent Floating Bottom Delivery & Cart Bar (RTL Swapped with Animated Counter)
/// ---------------------------------------------------------------------------

class RestaurantMenuPage extends StatefulWidget {
  static const String routeName = '/RestaurantMenuPage';

  final int? restaurantId;
  final String? restaurantName;
  final String? coverUrl;
  final String? logoUrl;
  final MockMenuItemData? initialSelectedItem;
  final int? initialSelectedItemId;

  const RestaurantMenuPage({
    super.key,
    this.restaurantId,
    this.restaurantName,
    this.coverUrl,
    this.logoUrl,
    this.initialSelectedItem,
    this.initialSelectedItemId,
  });

  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MockRestaurantData _restaurantData;
  late List<String> _categories;
  int _selectedCategoryIndex = 0;
  final ScrollController _scrollController = ScrollController();
  int? _highlightedProductId;

  int get _minOrderTarget =>
      _restaurantData.minOrder > 0 ? _restaurantData.minOrder : 15000;

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _onPlusTapped(MockMenuItemData product) async {
    final cart = locator<CartProvider>();
    if (cart.isDifferentMerchant(product.restaurantId)) {
      final shouldReplace = await ReplaceCartBottomSheet.show(
        context,
        currentStoreName: cart.getConflictingMerchantName(product.restaurantId),
        newStoreName: _restaurantData.name.split(' - ').first,
      );
      if (shouldReplace != true || !mounted) return;

      // If item has options, open customization bottom sheet with pre-confirmed replacement
      if (product.optionGroups.isNotEmpty) {
        ItemCustomizationBottomSheet.show(
          context,
          item: product,
          isPreConfirmedReplace: true,
        );
        return;
      }

      await cart.replaceCartWithItem(
        product.id,
        product.restaurantId,
        product.basePriceValue.toDouble(),
        1,
        title: product.title,
        imageUrl: product.imageUrl,
      );
      return;
    }

    HapticFeedback.lightImpact();
    final currentQty = cart.getProductQuantity(product.id);

    // If item has customization groups and not yet added, open bottom sheet
    if (currentQty == 0 && product.optionGroups.isNotEmpty) {
      ItemCustomizationBottomSheet.show(
        context,
        item: product,
      );
      return;
    }

    cart.addToCart(
      product.id,
      product.restaurantId,
      product.basePriceValue.toDouble(),
      quantity: 1,
      title: product.title,
      imageUrl: product.imageUrl,
      merchantTitle: product.restaurantName,
    );
  }

  void _onMinusTapped(MockMenuItemData product) {
    HapticFeedback.lightImpact();
    final cart = locator<CartProvider>();
    final currentQty = cart.getProductQuantity(product.id);
    if (currentQty <= 1) {
      cart.removeFromCart(product.id, product.restaurantId);
    } else {
      cart.setToCart(
        product.id,
        product.restaurantId,
        product.basePriceValue.toDouble(),
        currentQty - 1,
        title: product.title,
        imageUrl: product.imageUrl,
        merchantTitle: product.restaurantName,
      );
    }
  }

  void _syncCartFromProvider() {
    // No-op: Product cards and bottom cart bar are reactive via CartProvider!
  }

  @override
  void initState() {
    super.initState();
    if (widget.restaurantId != null) {
      if (locator.isRegistered<MarketsProvider>()) {
        final prov = locator<MarketsProvider>();
        final store = prov.restaurants
            .where((r) => r.id == widget.restaurantId)
            .firstOrNull;
        if (store != null) {
          final cachedProds = prov.getCachedProducts(store.id);
          if (cachedProds != null && cachedProds.isNotEmpty) {
            _restaurantData =
                prov.toRestaurantDataFromProducts(store, cachedProds);
          } else {
            _restaurantData = store.toRestaurantData();
          }
        } else {
          _restaurantData =
              MockCatalogData.getRestaurantById(widget.restaurantId);
        }
      } else {
        _restaurantData = MockCatalogData.getRestaurantById(widget.restaurantId);
      }
    } else if (widget.restaurantName != null && widget.restaurantName!.isNotEmpty) {
      if (locator.isRegistered<MarketsProvider>()) {
        final prov = locator<MarketsProvider>();
        final nameLower = widget.restaurantName!.toLowerCase().trim();
        final store = prov.restaurants
            .where((r) =>
                r.name.toLowerCase().contains(nameLower) ||
                nameLower.contains(r.name.toLowerCase()))
            .firstOrNull;
        if (store != null) {
          final cachedProds = prov.getCachedProducts(store.id);
          if (cachedProds != null && cachedProds.isNotEmpty) {
            _restaurantData =
                prov.toRestaurantDataFromProducts(store, cachedProds);
          } else {
            _restaurantData = store.toRestaurantData();
          }
        } else {
          _restaurantData =
              MockCatalogData.getRestaurantByName(widget.restaurantName!);
        }
      } else {
        _restaurantData =
            MockCatalogData.getRestaurantByName(widget.restaurantName!);
      }
    } else {
      _restaurantData = MockCatalogData.restaurants.first;
    }

    _categories = _restaurantData.categories;

    final targetId = widget.initialSelectedItemId ?? widget.initialSelectedItem?.id;
    if (targetId != null) {
      _highlightedProductId = targetId;
      final matchedItem = _restaurantData.menuItems
          .where((m) => m.id == targetId)
          .firstOrNull ?? widget.initialSelectedItem;
      if (matchedItem != null) {
        final catIndex = _categories.indexOf(matchedItem.category);
        if (catIndex != -1) {
          _selectedCategoryIndex = catIndex;
        }
      }
    }

    _tabController = TabController(
      length: _categories.length,
      vsync: this,
      initialIndex: _selectedCategoryIndex,
    );

    // Dynamically fetch and sync real products live from the backend API
    _loadLiveBackendMenu();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Scroll smoothly down to the menu section past the banner and overview card
      if (targetId != null && _scrollController.hasClients) {
        _scrollController.animateTo(
          340.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }

      final itemToShow = widget.initialSelectedItem ??
          _restaurantData.menuItems
              .where((m) => m.id == widget.initialSelectedItemId)
              .firstOrNull;

      if (itemToShow != null) {
        ItemCustomizationBottomSheet.show(
          context,
          item: itemToShow,
        );
      }

      // Automatically clear highlight after 4 seconds
      if (_highlightedProductId != null) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _highlightedProductId != null) {
            setState(() {
              _highlightedProductId = null;
            });
          }
        });
      }
    });
  }

  void _loadLiveBackendMenu() async {
    final rid = widget.restaurantId ?? _restaurantData.id;
    if (rid <= 0 || !locator.isRegistered<MarketsProvider>()) return;
    final prov = locator<MarketsProvider>();
    final backendProds = await prov.fetchMarketProducts(rid);
    if (!mounted || backendProds.isEmpty) return;
    final store = prov.restaurants.where((r) => r.id == rid).firstOrNull;
    if (store != null) {
      final liveData = prov.toRestaurantDataFromProducts(store, backendProds);
      setState(() {
        _restaurantData = liveData;
        _categories = liveData.categories;

        final targetId = widget.initialSelectedItemId ?? widget.initialSelectedItem?.id;
        if (targetId != null) {
          final matched = liveData.menuItems.where((m) => m.id == targetId).firstOrNull;
          if (matched != null) {
            final catIdx = _categories.indexOf(matched.category);
            if (catIdx != -1) {
              _selectedCategoryIndex = catIdx;
            }
          }
        } else if (_selectedCategoryIndex >= _categories.length) {
          _selectedCategoryIndex = 0;
        }

        _tabController.dispose();
        _tabController = TabController(
          length: _categories.length,
          vsync: this,
          initialIndex: _selectedCategoryIndex,
        );
      });
      _syncCartFromProvider();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<MockMenuItemData> get _displayMenuItems {
    if (_categories.isEmpty) return [];
    final selectedCat = _categories[_selectedCategoryIndex];
    final categoryItems = _restaurantData.menuItems
        .where((item) => item.category == selectedCat)
        .toList();

    return categoryItems.isNotEmpty
        ? categoryItems
        : _restaurantData.menuItems;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _displayMenuItems;

    return Scaffold(
      backgroundColor: kPageBackground,
      body: SafeArea(
        top: false, // Allows full-bleed banner to reach the very top
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(overscroll: false),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    // 1. Unified Banner Header & Overview Card (Overview Card has higher Z-Index over Banner)
                    _buildUnifiedBannerAndOverviewSection(context),

                    // 2. Sticky Menu Category Tabs Bar
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _MenuCategoryTabsHeaderDelegate(
                        categories: _categories,
                        selectedIndex: _selectedCategoryIndex,
                        topPadding: 0,
                        onTabSelected: (index) {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        },
                      ),
                    ),

                    // Category Section Heading
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _categories[_selectedCategoryIndex],
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: kCharcoalDark,
                                fontSize: 20.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 4. 2-Column Menu Food Grid with Morphing Stepper
                    if (filteredItems.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF9CA3AF)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد وجبات في هذا القسم حالياً',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: kCharcoalDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'يرجى اختيار قسم آخر من القائمة في الأعلى',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.72,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = filteredItems[index];
                              return _buildProductCard(item);
                            },
                            childCount: filteredItems.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Persistent Floating Bottom Delivery Bar
            _buildBottomDeliveryBar(),
          ],
        ),
      ),
    );
  }

  /// 2-Column Interactive Food Card with Morphing Stepper
  Widget _buildProductCard(MockMenuItemData product) {
    return _RestaurantMenuItemCard(
      product: product,
      isHighlighted: _highlightedProductId == product.id,
      onProductTap: () {
        ItemCustomizationBottomSheet.show(
          context,
          item: product,
        );
      },
      onPlusTap: () => _onPlusTapped(product),
      onMinusTap: () => _onMinusTapped(product),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Persistent Bottom Minimum Order / Active Cart Bar (Exact Market Page Match)
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
            cart.getSubtotalForMerchant(_restaurantData.id).toInt();
        final storeMinOrder = cart.getMinOrderForMerchant(_restaurantData.id);
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
                                'أضف أصناف بقيمة ${_formatPrice(remaining)} ل.س إلى طلبك!',
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
                                color: Color(0x38000000), // Dark translucent badge matching reference
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

  // ---------------------------------------------------------------------------
  // Unified Banner & Overview Section (Overview Card paints ON TOP of Banner)
  // ---------------------------------------------------------------------------
  Widget _buildUnifiedBannerAndOverviewSection(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final double bannerHeight = 220.0 + topPadding;
    const cardOverlap = 24.0;

    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Banner Cover Image Layer (Full bleed to the very top)
          Container(
            height: bannerHeight,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFE5E7EB),
            ),
            child: (widget.coverUrl?.isNotEmpty == true || _restaurantData.coverUrl.isNotEmpty)
                ? () {
                    final imgUrl = widget.coverUrl?.isNotEmpty == true
                        ? widget.coverUrl!
                        : _restaurantData.coverUrl;
                    if (imgUrl.startsWith('assets')) {
                      return Image.asset(imgUrl, fit: BoxFit.cover);
                    }
                    return CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                    );
                  }()
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFDBA74), Color(0xFFEA580C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.restaurant_rounded, color: Colors.white, size: 48),
                    ),
                  ),
          ),

          // 2. Overview Card Layer (Layered ON TOP of Banner with higher Z-Index!)
          Padding(
            padding: EdgeInsets.only(
              top: bannerHeight - cardOverlap,
              left: 16,
              right: 16,
            ),
            child: _buildRestaurantOverviewCard(),
          ),

          // 3. Status Chip ("⚡ مفتوح حتى 3 ص" - Left Aligned on top of Banner with generous padding)
          Positioned(
            top: bannerHeight - cardOverlap - 52,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFFF5400),
                    size: 20,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'مفتوح',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: kCharcoalDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _restaurantData.workingHours.isNotEmpty ? _restaurantData.workingHours : 'حتى 3 ص',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF6B7280),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Top Floating Actions (Positioned at the very top of the phone under the status bar)
          Positioned(
            top: topPadding > 0 ? topPadding + 6 : 14,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // In RTL: 1st child is on the RIGHT side (Back Button with arrow facing RIGHT to go back)
                _buildCircularActionButton(
                  iconWidget: const JtakBackIcon(size: 20),
                  onTap: () => Navigator.pop(context),
                ),

                // In RTL: 2nd child is on the LEFT side (Favorite Button & Search Button)
                Consumer<FavoriteProductProvider>(
                  builder: (context, favProvider, _) {
                    final isFav = favProvider.isRestaurantFavorite(_restaurantData.id);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCircularActionButton(
                          icon: isFav
                              ? PhosphorIconsFill.heart
                              : PhosphorIconsRegular.heart,
                          iconColor: isFav
                              ? const Color(0xFFEF4444)
                              : kCharcoalDark,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            favProvider.toggleRestaurantFavorite(
                                _restaurantData.id, _restaurantData);
                            SnackBarWidget.showCustomSnackBar(
                              context,
                              isFav
                                  ? 'تمت الإزالة من المفضلة'
                                  : 'تمت إضافة ${_restaurantData.name} إلى المفضلة ❤️',
                              backgroundColor: const Color(0xFF1E293B),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildCircularActionButton(
                          iconWidget: const JtakSearchIcon(size: 20, color: kCharcoalDark),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RestaurantMenuSearchPage(
                                  restaurantData: _restaurantData,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularActionButton({
    Widget? iconWidget,
    IconData? icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: Center(
          child: iconWidget ??
              Icon(icon ?? PhosphorIconsRegular.caretRight, color: iconColor ?? kCharcoalDark, size: 20),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Restaurant Overview Card (Logo, Name, Verified Badge, 3-Way Mode Switcher)
  // ---------------------------------------------------------------------------
  Widget _buildRestaurantOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kCardBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: Brand Logo (Right in RTL) + Info Column (Title + Prime row, Description row)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo Box (Right in RTL) - Bigger 72x72
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kCardBorderColor, width: 1.2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: (widget.logoUrl?.isNotEmpty == true || _restaurantData.logoUrl.isNotEmpty)
                      ? () {
                          final logo = widget.logoUrl?.isNotEmpty == true
                              ? widget.logoUrl!
                              : _restaurantData.logoUrl;
                          if (logo.startsWith('assets')) {
                            return Image.asset(
                              logo,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  _restaurantData.name[0],
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: kPrimaryOrange,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: logo,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Center(
                              child: Text(
                                _restaurantData.name[0],
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: kPrimaryOrange,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        }()
                      : Center(
                          child: Text(
                            _restaurantData.name[0],
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: kPrimaryOrange,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 14),

              // Title, Cuisines, and Interactive Rating Chip
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: Restaurant Name + Verified Badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.restaurantName ?? _restaurantData.name,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: kCharcoalDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Transform.flip(
                          flipX: true,
                          child: const Icon(
                            PhosphorIconsFill.sealCheck,
                            color: kPrimaryOrange,
                            size: 20,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Line 2: Cuisines / Description
                    Text(
                      _restaurantData.cuisine,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF6B7280),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Line 3: Rating Pill Chip (Navigates to Reviews Page)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RestaurantReviewsPage(
                              restaurantData: _restaurantData,
                            ),
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '(${_restaurantData.ratingCount > 999 ? "+1k" : "+${_restaurantData.ratingCount}"})',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: const Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_restaurantData.rating}'.replaceAll('.', ','),
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: kCharcoalDark,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB800),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Delivery Metadata 3-Column Grid (مدة التوصيل • رسوم التوصيل • الحد الأدنى للطلب)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildMetadataColumn('مدة التوصيل', _restaurantData.eta),
              _buildMetadataDivider(),
              _buildMetadataColumn('رسوم التوصيل', _restaurantData.deliveryFee),
              _buildMetadataDivider(),
              _buildMetadataColumn(
                'الحد الأدنى للطلب',
                '${_formatPrice(_restaurantData.minOrder)} ل.س',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataColumn(String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFF6B7280),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataDivider() {
    return Container(
      width: 4.0,
      height: 4.0,
      decoration: const BoxDecoration(
        color: Color(0xFFCBD5E1),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Sticky Menu Category Tabs Bar Delegate with Auto-Scroll to Leading Edge
/// ---------------------------------------------------------------------------
class _MenuCategoryTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final int selectedIndex;
  final double topPadding;
  final ValueChanged<int> onTabSelected;

  const _MenuCategoryTabsHeaderDelegate({
    required this.categories,
    required this.selectedIndex,
    required this.topPadding,
    required this.onTabSelected,
  });

  @override
  double get minExtent => 48 + topPadding;

  @override
  double get maxExtent => 48 + topPadding;

  @override
  bool shouldRebuild(covariant _MenuCategoryTabsHeaderDelegate oldDelegate) {
    return selectedIndex != oldDelegate.selectedIndex ||
        categories != oldDelegate.categories ||
        topPadding != oldDelegate.topPadding;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: topPadding),
      child: _StickyCategoryTabsBar(
        categories: categories,
        selectedIndex: selectedIndex,
        onTabSelected: onTabSelected,
      ),
    );
  }
}

class _StickyCategoryTabsBar extends StatefulWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const _StickyCategoryTabsBar({
    required this.categories,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  State<_StickyCategoryTabsBar> createState() => _StickyCategoryTabsBarState();
}

class _StickyCategoryTabsBarState extends State<_StickyCategoryTabsBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.selectedIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTab(widget.selectedIndex);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _StickyCategoryTabsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToTab(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _calculateTargetOffset(int targetIndex) {
    if (targetIndex <= 0) return 0.0;
    double cumulativeOffset = 0.0;

    for (int i = 0; i < targetIndex && i < widget.categories.length; i++) {
      final textSpan = TextSpan(
        text: widget.categories[i],
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.rtl,
      )..layout();

      // Tab width = text width + 20px separator width
      cumulativeOffset += textPainter.width + 20.0;
    }

    if (_scrollController.hasClients) {
      return cumulativeOffset.clamp(0.0, _scrollController.position.maxScrollExtent);
    }
    return cumulativeOffset;
  }

  void _scrollToTab(int index) {
    if (_scrollController.hasClients) {
      final target = _calculateTargetOffset(index);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final isSelected = index == widget.selectedIndex;
          return GestureDetector(
            onTap: () {
              widget.onTabSelected(index);
              _scrollToTab(index);
            },
            behavior: HitTestBehavior.opaque,
            child: IntrinsicWidth(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    widget.categories[index],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: isSelected ? kPrimaryOrange : const Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isSelected ? kPrimaryOrange : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
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

class _AnimatedCounterTextState extends State<_AnimatedCounterText> {
  int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _prevCount = widget.count;
  }

  @override
  void didUpdateWidget(covariant _AnimatedCounterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _prevCount = oldWidget.count;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncrement = widget.count >= _prevCount;

    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isIncoming = (child.key is ValueKey<int>) &&
              (child.key as ValueKey<int>).value == widget.count;

          final inOffset = isIncrement
              ? const Offset(0.0, -1.0)
              : const Offset(0.0, 1.0);
          final outOffset = isIncrement
              ? const Offset(0.0, 1.0)
              : const Offset(0.0, -1.0);

          final offsetTween = isIncoming
              ? Tween<Offset>(begin: inOffset, end: Offset.zero)
              : Tween<Offset>(begin: outOffset, end: Offset.zero);

          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );

          return SlideTransition(
            position: offsetTween.animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: child,
            ),
          );
        },
        child: Text(
          '${widget.count}',
          key: ValueKey<int>(widget.count),
          style: widget.style,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Dedicated Reactive Restaurant Food Card
/// ---------------------------------------------------------------------------
class _RestaurantMenuItemCard extends StatefulWidget {
  final MockMenuItemData product;
  final bool isHighlighted;
  final VoidCallback onProductTap;
  final VoidCallback onPlusTap;
  final VoidCallback onMinusTap;

  const _RestaurantMenuItemCard({
    required this.product,
    required this.isHighlighted,
    required this.onProductTap,
    required this.onPlusTap,
    required this.onMinusTap,
  });

  @override
  State<_RestaurantMenuItemCard> createState() =>
      _RestaurantMenuItemCardState();
}

class _RestaurantMenuItemCardState extends State<_RestaurantMenuItemCard> {
  bool _isExpanded = false;
  Timer? _collapseTimer;

  void _resetCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isExpanded = false;
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
      _isExpanded = true;
    });
    _resetCollapseTimer();
    widget.onPlusTap();
  }

  void _handleMinus() {
    HapticFeedback.selectionClick();
    _resetCollapseTimer();
    widget.onMinusTap();
  }

  void _handleCollapsedBadgeTap() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = true;
    });
    _resetCollapseTimer();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Selector<CartProvider, int>(
      selector: (_, cart) => cart.getProductQuantity(product.id),
      builder: (context, quantityInCart, _) {
        final isExpanded = _isExpanded && quantityInCart > 0;

        final double btnWidth = isExpanded ? 112 : 34;
        final double btnHeight = isExpanded ? 36 : 34;
        final double btnRight = isExpanded ? 6 : 8;
        final double btnBottom = isExpanded ? 6 : 8;

        final BoxDecoration btnDecoration = isExpanded
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
                    border:
                        Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  ));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // White Squircle Card with Image & Animated Morphing Stepper / Button
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.isHighlighted
                        ? kPrimaryOrange
                        : const Color(0xFFEBEBEF),
                    width: widget.isHighlighted ? 2.5 : 1.1,
                  ),
                  boxShadow: widget.isHighlighted
                      ? [
                          const BoxShadow(
                            color: Color(0x59FF5400),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Product Image (Takes full cover with BoxFit.cover)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: widget.onProductTap,
                        behavior: HitTestBehavior.opaque,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: product.imageUrl.startsWith('assets')
                              ? Image.asset(
                                  product.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.fastfood_rounded,
                                        color: Color(0xFFCBD5E1), size: 36),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: product.imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Center(
                                    child: Icon(Icons.fastfood_rounded,
                                        color: Color(0xFFCBD5E1), size: 36),
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
                            child: isExpanded
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
                                            _AnimatedCounterText(
                                              count: quantityInCart,
                                              style:
                                                  GoogleFonts.ibmPlexSansArabic(
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
              ),
            ),

            const SizedBox(height: 6),

            // Product Title & Price (Underneath Card)
            GestureDetector(
              onTap: widget.onProductTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: kCharcoalDark,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.price,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: kPrimaryOrange,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}


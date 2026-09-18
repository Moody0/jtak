import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/markets_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../../core/services/locator.dart';
import '../../widgets/catalog/item_customization_sheet.dart';
import '../../widgets/catalog/meal_card_widget.dart';
import '../../widgets/catalog/replace_cart_bottom_sheet.dart';
import '../../widgets/clean_shimmer_skeletons.dart';
import '../../widgets/header_circle_button.dart';
import '../cart/cart_page.dart';
import 'favorite_page.dart';
import 'market_page.dart';
import 'restaurant_menu_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Most Ordered Products Page (صفحة الأصناف الأكثر طلباً)
///
/// Opened from Home Page "الأكثر طلباً" -> "عرض الكل"
/// Features:
/// 1. Top Bar: Back button, "الأكثر طلباً" title, and Favorites heart shortcut.
/// 2. Authoritative Data Source: MarketsProvider.popularMeals backed by
///    /Customer/Products/Popular with multi-tier live resilience.
/// 3. Product Cards Grid: 2-column responsive layout with JtakMealCard.
/// 4. Add/Remove Stepper: 100% reactive to CartProvider with single-merchant isolation.
/// 5. Favorites: Synchronized with FavoriteProductProvider.
/// 6. Floating Bottom Cart Bar: Appears when cart has items.
/// ---------------------------------------------------------------------------

class MostOrderedProductsPage extends StatefulWidget {
  static const String routeName = '/MostOrderedProductsPage';

  const MostOrderedProductsPage({super.key});

  @override
  State<MostOrderedProductsPage> createState() =>
      _MostOrderedProductsPageState();
}

class _MostOrderedProductsPageState extends State<MostOrderedProductsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (locator.isRegistered<MarketsProvider>()) {
        final prov = locator<MarketsProvider>();
        if (!prov.hasLoadedPopularMeals && !prov.isLoadingPopularMeals) {
          unawaited(prov.loadPopularMeals(take: 50));
        }
      }
    });
  }

  void _handleMealTap(BuildContext context, MealItemData meal) {
    final mockItem = MockCatalogData.getMenuItemById(meal.id);
    int resId = meal.merchantId;
    if (resId <= 0 && mockItem != null) {
      resId = mockItem.restaurantId;
    }

    RestaurantStoreModel? storeModel;
    if (locator.isRegistered<MarketsProvider>()) {
      final prov = locator<MarketsProvider>();
      if (resId > 0) {
        storeModel =
            prov.restaurants.where((r) => r.id == resId).firstOrNull;
      }
      if (storeModel == null) {
        final nameLower = meal.merchantName.toLowerCase().trim();
        storeModel = prov.restaurants.where((r) =>
            r.name.toLowerCase().contains(nameLower) ||
            nameLower.contains(r.name.toLowerCase())).firstOrNull;
      }
    }

    final mockRes = resId > 0
        ? MockCatalogData.getRestaurantById(resId)
        : MockCatalogData.getRestaurantByName(meal.merchantName);

    final targetResId = storeModel?.id ?? (resId > 0 ? resId : mockRes.id);
    final targetResName = storeModel?.name ??
        (meal.merchantName.isNotEmpty ? meal.merchantName : mockRes.name);
    final targetCover = storeModel?.coverUrl ?? mockRes.coverUrl;
    final targetLogo = storeModel?.logoUrl ?? mockRes.logoUrl;

    if (meal.isMarket || (storeModel == null && mockRes.isMarket)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MarketPage(
            marketId: targetResId,
            marketName: targetResName,
            coverUrl: targetCover,
            logoUrl: targetLogo,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantMenuPage(
          restaurantId: targetResId,
          restaurantName: targetResName,
          coverUrl: targetCover,
          logoUrl: targetLogo,
          initialSelectedItemId: meal.id,
          initialSelectedItem: mockItem,
        ),
      ),
    );
  }

  void _handleQuickAdd(BuildContext context, MealItemData meal) async {
    final cart = locator<CartProvider>();
    final mockItem = MockCatalogData.getMenuItemById(meal.id);
    final int merchantId = meal.merchantId > 0
        ? meal.merchantId
        : (mockItem?.restaurantId ?? 12);

    if (cart.isDifferentMerchant(merchantId)) {
      final shouldReplace = await ReplaceCartBottomSheet.show(
        context,
        currentStoreName: cart.getConflictingMerchantName(merchantId),
        newStoreName: meal.merchantName.isNotEmpty
            ? meal.merchantName.split(' - ').first
            : (mockItem?.restaurantName.split(' - ').first ?? 'المتجر الجديد'),
      );
      if (shouldReplace != true || !context.mounted) return;
      final double price = meal.numericPrice > 0
          ? meal.numericPrice
          : (mockItem?.basePriceValue.toDouble() ?? 0.0);
      await cart.replaceCartWithItem(
        meal.id,
        merchantId,
        price,
        1,
        title: meal.title,
        imageUrl: meal.coverUrl,
        merchantTitle: meal.merchantName,
      );
      return;
    }

    if (mockItem != null &&
        mockItem.optionGroups.isNotEmpty &&
        cart.getProductQuantity(meal.id) == 0) {
      ItemCustomizationBottomSheet.show(
        context,
        item: mockItem,
        onAddToCart: (_) {},
      );
      return;
    }

    HapticFeedback.lightImpact();
    final double price = meal.numericPrice > 0
        ? meal.numericPrice
        : (mockItem?.basePriceValue.toDouble() ?? 0.0);

    await cart.addToCart(
      meal.id,
      merchantId,
      price,
      quantity: 1,
      title: meal.title,
      imageUrl: meal.coverUrl,
      merchantTitle: meal.merchantName,
    );
  }

  void _handleQuickRemove(MealItemData meal) {
    HapticFeedback.lightImpact();
    final cart = locator<CartProvider>();
    final mockItem = MockCatalogData.getMenuItemById(meal.id);
    final currentQty = cart.getProductQuantity(meal.id);
    final newQty = currentQty <= 1 ? 0 : currentQty - 1;
    final int merchantId = meal.merchantId > 0
        ? meal.merchantId
        : (mockItem?.restaurantId ?? 0);
    final double price = meal.numericPrice > 0
        ? meal.numericPrice
        : (mockItem?.basePriceValue.toDouble() ?? 0.0);

    if (newQty <= 0) {
      cart.removeFromCart(meal.id, merchantId);
    } else {
      cart.setToCart(
        meal.id,
        merchantId,
        price,
        newQty,
        title: meal.title,
        imageUrl: meal.coverUrl,
        merchantTitle: meal.merchantName,
      );
    }
  }

  String _formatPrice(num value) {
    return value.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // 1. Sticky Top Navigation Row
            _buildStickyHeader(context),

            // 2. Refreshable Products Grid
            Expanded(
              child: Consumer2<MarketsProvider, CartProvider>(
                builder: (context, marketsProv, cartProvider, _) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      await marketsProv.loadPopularMeals(take: 50);
                    },
                    color: kPrimaryOrange,
                    child: _buildBody(context, marketsProv, cartProvider),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Consumer<CartProvider>(
        builder: (context, cartProvider, _) {
          if (cartProvider.totalUnits <= 0) {
            return const SizedBox.shrink();
          }
          return _buildFloatingCartBar(context, cartProvider);
        },
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Back Button
          HeaderCircleButton.back(
            onTap: () => Navigator.pop(context),
          ),

          // 2. Centered Page Title: الأكثر طلباً
          Text(
            'الأكثر طلباً',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
            ),
          ),

          // 3. Heart / Favorites Shortcut
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

  Widget _buildBody(
    BuildContext context,
    MarketsProvider marketsProv,
    CartProvider cartProvider,
  ) {
    if (marketsProv.isLoadingPopularMeals && marketsProv.popularMeals.isEmpty) {
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const CleanShimmer(
          child: SkeletonBox(
            width: double.infinity,
            height: 235,
            borderRadius: 18,
          ),
        ),
      );
    }

    final allMeals = marketsProv.popularMeals;
    final meals = allMeals.where((m) => !m.isMarket).toList();

    if (meals.isEmpty) {
      if (marketsProv.popularMealsError != null) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.70,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          PhosphorIconsFill.warningCircle,
                          size: 38,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'تعذر تحميل الأصناف الأكثر طلباً',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: kCharcoalDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF6B7280),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => marketsProv.loadPopularMeals(take: 50),
                      icon: const Icon(PhosphorIconsBold.arrowClockwise,
                          size: 16, color: Colors.white),
                      label: Text(
                        'إعادة المحاولة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.70,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        PhosphorIconsFill.forkKnife,
                        size: 38,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد أصناف أكثر طلباً متاحة حالياً',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: kCharcoalDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تابعنا لاحقاً لتصفح أشهى الأطباق والوجبات الأكثر طلباً ومبيعاً.',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF6B7280),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final meal = meals[index];
        final qty = cartProvider.getProductQuantity(meal.id);

        return JtakMealCard(
          data: meal,
          quantity: qty,
          onTap: () => _handleMealTap(context, meal),
          onQuickAdd: () => _handleQuickAdd(context, meal),
          onQuickRemove: () => _handleQuickRemove(meal),
        );
      },
    );
  }

  Widget _buildFloatingCartBar(BuildContext context, CartProvider cartProvider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: GestureDetector(
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
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0x38000000),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${cartProvider.totalUnits}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontSize: 14,
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
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_formatPrice(cartProvider.subtotal)} ل.س',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

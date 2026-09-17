import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/catalog/markets_provider.dart';
import '../../core/controllers/order/cart_provider.dart';
import '../../core/data/mock_catalog_data.dart';
import '../../core/services/locator.dart';
import 'catalog/item_customization_sheet.dart';
import 'catalog/meal_card_widget.dart';
import 'catalog/replace_cart_bottom_sheet.dart';
import 'clean_shimmer_skeletons.dart';

/// ---------------------------------------------------------------------------
/// JTAK Most Popular Dishes Section (الأكثر طلباً)
///
/// Section 5 on Home Page:
/// - Header Row: "الأكثر طلباً" with "عرض الكل >" action link
/// - Horizontal scrolling list of Meal / Dish Cards with in-image quick (+) add
/// - Driven by CartProvider so quantity states stay 100% synchronized everywhere
/// ---------------------------------------------------------------------------

class JtakDeliveryOffersSection extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAllTap;
  final ValueChanged<MealItemData>? onMealTap;
  final ValueChanged<MealItemData>? onQuickAdd;

  const JtakDeliveryOffersSection({
    super.key,
    this.title = 'الأكثر طلباً',
    this.onViewAllTap,
    this.onMealTap,
    this.onQuickAdd,
  });

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
      onQuickAdd?.call(meal);
      return;
    }

    // If item has options and not yet customized, open bottom sheet directly on home page
    if (mockItem != null && mockItem.optionGroups.isNotEmpty && cart.getProductQuantity(meal.id) == 0) {
      ItemCustomizationBottomSheet.show(
        context,
        item: mockItem,
        onAddToCart: (data) {
          onQuickAdd?.call(meal);
        },
      );
      return;
    }

    // Otherwise increment directly
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
    onQuickAdd?.call(meal);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Row (21px Bold Title & "عرض الكل <")
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
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
                onTap: onViewAllTap,
                behavior: HitTestBehavior.opaque,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        PhosphorIconsRegular.caretLeft,
                        color: kPrimaryOrange,
                        size: 18,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'عرض الكل',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kPrimaryOrange,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Horizontal Scrollable List of Meal Cards
        SizedBox(
          height: 240,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(overscroll: false),
            child: Consumer2<MarketsProvider, CartProvider>(
              builder: (context, marketsProv, cartProvider, _) {
                if (marketsProv.isLoadingPopularMeals &&
                    marketsProv.popularMeals.isEmpty) {
                  return ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, __) => const CleanShimmer(
                      child: SkeletonBox(
                        width: 205,
                        height: 235,
                        borderRadius: 18,
                      ),
                    ),
                  );
                }

                final allMeals = marketsProv.popularMeals;
                final meals = allMeals.where((m) => !m.isMarket).toList();
                if (meals.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'لا توجد وجبات متاحة حالياً',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: meals.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    final qty = cartProvider.getProductQuantity(meal.id);

                    return JtakMealCard(
                      data: meal,
                      quantity: qty,
                      onTap: () {
                        if (onMealTap != null) {
                          onMealTap!(meal);
                        }
                      },
                      onQuickAdd: () => _handleQuickAdd(context, meal),
                      onQuickRemove: () => _handleQuickRemove(meal),
                    );
                  },
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Sliver wrapper for JtakDeliveryOffersSection (Used in HomePage CustomScrollView)
/// ---------------------------------------------------------------------------
class SliverJtakDeliveryOffersSection extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAllTap;
  final ValueChanged<MealItemData>? onMealTap;
  final ValueChanged<MealItemData>? onQuickAdd;

  const SliverJtakDeliveryOffersSection({
    super.key,
    this.title = 'الأكثر طلباً',
    this.onViewAllTap,
    this.onMealTap,
    this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: JtakDeliveryOffersSection(
        title: title,
        onViewAllTap: onViewAllTap,
        onMealTap: onMealTap,
        onQuickAdd: onQuickAdd,
      ),
    );
  }
}


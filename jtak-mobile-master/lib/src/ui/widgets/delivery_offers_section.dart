import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/order/cart_provider.dart';
import '../../core/data/mock_catalog_data.dart';
import '../../core/services/locator.dart';
import 'catalog/item_customization_sheet.dart';
import 'catalog/meal_card_widget.dart';
import 'catalog/replace_cart_bottom_sheet.dart';

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
    final mockItem = MockCatalogData.getMenuItemById(meal.id);
    if (mockItem == null) return;
    final cart = locator<CartProvider>();

    if (cart.isDifferentMerchant(mockItem.restaurantId)) {
      final shouldReplace = await ReplaceCartBottomSheet.show(
        context,
        currentStoreName: cart.currentMerchantName,
        newStoreName: mockItem.restaurantName.split(' - ').first,
      );
      if (shouldReplace != true || !context.mounted) return;

      if (mockItem.optionGroups.isNotEmpty) {
        ItemCustomizationBottomSheet.show(
          context,
          item: mockItem,
          isPreConfirmedReplace: true,
          onAddToCart: (data) {
            onQuickAdd?.call(meal);
          },
        );
        return;
      }

      await cart.replaceCartWithItem(
        mockItem.id,
        mockItem.restaurantId,
        mockItem.basePriceValue.toDouble(),
        1,
      );
      onQuickAdd?.call(meal);
      return;
    }

    final currentQty = cart.getProductQuantity(meal.id);

    // If item has options and not yet customized, open bottom sheet directly on home page
    if (mockItem.optionGroups.isNotEmpty && currentQty == 0) {
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
    cart.addToCart(
      mockItem.id,
      mockItem.restaurantId,
      mockItem.basePriceValue.toDouble(),
      quantity: 1,
    );
    onQuickAdd?.call(meal);
  }

  void _handleQuickRemove(MealItemData meal) {
    HapticFeedback.lightImpact();
    final mockItem = MockCatalogData.getMenuItemById(meal.id);
    final currentQty = locator<CartProvider>().getProductQuantity(meal.id);
    final newQty = currentQty <= 1 ? 0 : currentQty - 1;

    if (mockItem != null) {
      if (newQty <= 0) {
        locator<CartProvider>().removeFromCart(mockItem.id, mockItem.restaurantId);
      } else {
        locator<CartProvider>().setToCart(
          mockItem.id,
          mockItem.restaurantId,
          mockItem.basePriceValue.toDouble(),
          newQty,
        );
      }
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
            child: Consumer<CartProvider>(
              builder: (context, cartProvider, _) {
                final meals = MockCatalogData.allDeliveryMeals;
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


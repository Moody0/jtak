import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/favorite_product_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../../core/services/locator.dart';
import 'item_customization_sheet.dart';
import 'replace_cart_bottom_sheet.dart';
import '../../pages/catalog/market_page.dart';
import '../../pages/catalog/restaurant_menu_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Favorite Restaurant Card (Flat Aesthetic - Zero Shadows)
/// ---------------------------------------------------------------------------
class FavoriteRestaurantCard extends StatelessWidget {
  final MockRestaurantData restaurant;
  const FavoriteRestaurantCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
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

        if (isMarket) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MarketPage(
                marketId: restaurant.id,
                marketName: restaurant.name,
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cover Image with Overlays (Height: 140px)
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: restaurant.coverUrl.startsWith('assets')
                        ? Image.asset(
                            restaurant.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Center(
                                child: Icon(Icons.restaurant_rounded, color: Color(0xFF9CA3AF), size: 36),
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: restaurant.coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Center(
                                child: Icon(Icons.restaurant_rounded, color: Color(0xFF9CA3AF), size: 36),
                              ),
                            ),
                          ),
                  ),
                ),

                // Gradient Overlay for readability
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x55000000),
                          Colors.transparent,
                          Color(0x33000000),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Right: Rating Chip
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
                        const SizedBox(width: 3),
                        Text(
                          '${restaurant.rating}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: kCharcoalDark,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Left: Favorite Heart Button
                Positioned(
                  top: 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Provider.of<FavoriteProductProvider>(context, listen: false)
                          .toggleRestaurantFavorite(restaurant.id);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
                      ),
                      child: const Center(
                        child: Icon(
                          PhosphorIconsFill.heart,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Right Logo (Overlapping)
                Positioned(
                  bottom: -18,
                  right: 16,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: restaurant.logoUrl.startsWith('assets')
                          ? Image.asset(
                              restaurant.logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.storefront_rounded, color: kPrimaryOrange, size: 22),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: restaurant.logoUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.storefront_rounded, color: kPrimaryOrange, size: 22),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // 2. Info Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          restaurant.name,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: kCharcoalDark,
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Transform.flip(
                        flipX: true,
                        child: const Icon(
                          PhosphorIconsFill.sealCheck,
                          color: kPrimaryOrange,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.categories.join(' • '),
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF6B7280),
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(PhosphorIconsRegular.clock, size: 15, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.eta,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF4B5563),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(width: 8),
                      const Icon(PhosphorIconsFill.motorcycle, size: 15, color: kPrimaryOrange),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.deliveryFee,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kCharcoalDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// JTAK Modern Favorite Meal / Dish Card (Flat Aesthetic - Zero Shadows)
/// ---------------------------------------------------------------------------
class FavoriteMealCard extends StatelessWidget {
  final MockMenuItemData item;
  const FavoriteMealCard({super.key, required this.item});

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final currentQty = cartProvider.getProductQuantity(item.id);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.1),
          ),
          child: Row(
            children: [
              // 1. Food Thumbnail Image (76x76)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 76,
                  height: 76,
                  color: const Color(0xFFF3F4F6),
                  child: item.imageUrl.startsWith('assets')
                      ? Image.asset(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.fastfood_rounded, color: Color(0xFF9CA3AF), size: 30),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.fastfood_rounded, color: Color(0xFF9CA3AF), size: 30),
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // 2. Info Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: kCharcoalDark,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(PhosphorIconsFill.storefront, size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.restaurantName.isNotEmpty
                                ? item.restaurantName
                                : 'جيتك',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: const Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.basePriceValue > 0
                          ? '${_formatPrice(item.basePriceValue)} ل.س'
                          : (item.price.isNotEmpty
                              ? (item.price.contains('ل.س')
                                  ? item.price
                                  : '${item.price} ل.س')
                              : ''),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: kPrimaryOrange,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 3. Actions Column: Heart (Top) + Add Stepper (Bottom)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Provider.of<FavoriteProductProvider>(context, listen: false)
                          .toggleMealFavorite(item.id);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF0E8),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          PhosphorIconsFill.heart,
                          color: Color(0xFFEF4444),
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildQuickAddBtn(context, currentQty),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAddBtn(BuildContext context, int currentQty) {
    if (currentQty > 0) {
      return Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: kPrimaryOrange,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            '$currentQty في السلة',
            style: GoogleFonts.ibmPlexSansArabic(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final cart = locator<CartProvider>();
        if (cart.isDifferentMerchant(item.restaurantId)) {
          final shouldReplace = await ReplaceCartBottomSheet.show(
            context,
            currentStoreName: cart.getConflictingMerchantName(item.restaurantId),
            newStoreName: item.restaurantName.split(' - ').first,
          );
          if (shouldReplace != true || !context.mounted) return;
          await cart.replaceCartWithItem(
            item.id,
            item.restaurantId,
            item.basePriceValue.toDouble(),
            1,
            title: item.title,
            imageUrl: item.imageUrl,
          );
          return;
        }

        if (item.optionGroups.isNotEmpty) {
          ItemCustomizationBottomSheet.show(
            context,
            item: item,
            onAddToCart: (data) {
              final qty = (data['quantity'] as int?) ?? 1;
              locator<CartProvider>().addToCart(
                item.id,
                item.restaurantId,
                item.basePriceValue.toDouble(),
                quantity: qty,
              );
            },
          );
        } else {
          locator<CartProvider>().addToCart(
            item.id,
            item.restaurantId,
            item.basePriceValue.toDouble(),
            quantity: 1,
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: kPrimaryOrange, size: 16),
            const SizedBox(width: 2),
            Text(
              'إضافة',
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

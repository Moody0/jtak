import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../../core/models/order/order_details_model.dart';
import '../../../core/services/locator.dart';
import '../../../utils/utilities/global_var.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Cart Single Item Card Component
///
/// Features:
/// - 18px rounded white card with subtle border
/// - Food photo thumbnail (72x72) with 14px rounded corners
/// - Dish Title, options / notes, bold orange price
/// - Unified morphing stepper ([-] [count] [+]) with trash icon on 1
/// ---------------------------------------------------------------------------

class CartSingleItem extends StatelessWidget {
  final OrderDetailsModel item;
  const CartSingleItem(this.item, {super.key});

  String _formatPrice(double price) {
    return price.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final mockItem = MockCatalogData.getMenuItemById(item.productId ?? 0);
    final rawImage = item.productImage?.isNotEmpty == true
        ? item.productImage!
        : (mockItem?.imageUrl ?? '');
    final imageUrl = GlobalVar.getImageUrl(rawImage);
    final title = item.productTitle?.isNotEmpty == true
        ? item.productTitle!
        : (mockItem?.title ?? 'وجبة خاصة');
    final singlePrice = item.singleFinalPrice ?? (mockItem?.basePriceValue.toDouble() ?? 0.0);
    final quantity = item.quantity ?? 1;
    final totalPrice = singlePrice * quantity;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Food Cover Image Thumbnail (72x72)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 72,
              height: 72,
              color: const Color(0xFFF3F4F6),
              child: imageUrl.isNotEmpty
                  ? (imageUrl.startsWith('assets')
                      ? Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(PhosphorIconsFill.hamburger, color: Color(0xFF9CA3AF), size: 30),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(PhosphorIconsFill.hamburger, color: Color(0xFF9CA3AF), size: 30),
                          ),
                        ))
                  : const Center(
                      child: Icon(PhosphorIconsFill.hamburger, color: Color(0xFF9CA3AF), size: 30),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // 2. Info Body (Title & Price)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: kCharcoalDark,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.warning != null && item.warning!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFECACA), width: 0.9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          PhosphorIconsFill.warningCircle,
                          size: 13,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.warning!
                                .replaceAll('\r\n', ' ')
                                .replaceAll('\n', ' ')
                                .replaceAll(RegExp(r'^!+'), '')
                                .trim(),
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: const Color(0xFFDC2626),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${_formatPrice(totalPrice)} ل.س',
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

          // 3. Morphing Stepper [-] [count] [+]
          _CartItemStepper(
            quantity: quantity,
            onIncrement: () {
              HapticFeedback.lightImpact();
              locator<CartProvider>().setToCart(
                item.productId!,
                item.merchantId ?? 0,
                singlePrice,
                quantity + 1,
                title: title,
                imageUrl: rawImage,
              );
            },
            onDecrement: () {
              HapticFeedback.lightImpact();
              if (quantity <= 1) {
                locator<CartProvider>().removeFromCart(
                  item.productId!,
                  item.merchantId ?? 0,
                );
              } else {
                locator<CartProvider>().setToCart(
                  item.productId!,
                  item.merchantId ?? 0,
                  singlePrice,
                  quantity - 1,
                  title: title,
                  imageUrl: rawImage,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Stepper Widget inside Cart Item
/// ---------------------------------------------------------------------------
class _CartItemStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartItemStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Minus Button (Left in LTR)
            GestureDetector(
              onTap: onDecrement,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 28,
                height: 34,
                child: Center(
                  child: Icon(
                    quantity == 1 ? PhosphorIconsRegular.trash : PhosphorIconsBold.minus,
                    color: quantity == 1 ? const Color(0xFFEF4444) : kPrimaryOrange,
                    size: quantity == 1 ? 16 : 16,
                  ),
                ),
              ),
            ),

            // Number (Center)
            Text(
              '$quantity',
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
              ),
            ),

            // Plus Button (Right in LTR)
            GestureDetector(
              onTap: onIncrement,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 28,
                height: 34,
                child: Center(
                  child: Icon(
                    PhosphorIconsBold.plus,
                    color: kPrimaryOrange,
                    size: 16,
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

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
import 'replace_cart_bottom_sheet.dart';
import '../../../utils/custom_widgets/image_view_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Food Item Customization Bottom Sheet
///
/// Interactive customization modal for dishes like Burgers, Pizzas, Shawarma,
/// Coffee, and Bakery with real-time price calculation, options (sizes, sauces,
/// extra cheese, bacon, removals, drinks), quantity counter, and add-to-cart logic.
/// ---------------------------------------------------------------------------

class ItemCustomizationBottomSheet extends StatefulWidget {
  final MockMenuItemData item;
  final ValueChanged<Map<String, dynamic>>? onAddToCart;
  final bool isPreConfirmedReplace;

  const ItemCustomizationBottomSheet({
    super.key,
    required this.item,
    this.onAddToCart,
    this.isPreConfirmedReplace = false,
  });

  static Future<void> show(
    BuildContext context, {
    required MockMenuItemData item,
    ValueChanged<Map<String, dynamic>>? onAddToCart,
    bool isPreConfirmedReplace = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ItemCustomizationBottomSheet(
        item: item,
        onAddToCart: onAddToCart,
        isPreConfirmedReplace: isPreConfirmedReplace,
      ),
    );
  }

  @override
  State<ItemCustomizationBottomSheet> createState() =>
      _ItemCustomizationBottomSheetState();
}

class _ItemCustomizationBottomSheetState
    extends State<ItemCustomizationBottomSheet> {
  int _quantity = 1;
  final Map<String, String> _selectedSingleOptions = {};
  final Map<String, Set<String>> _selectedMultiOptions = {};
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize default options
    for (final group in widget.item.optionGroups) {
      if (!group.isMultiSelect) {
        final defaultOpt = group.options.firstWhere(
          (o) => o.isDefault,
          orElse: () => group.options.first,
        );
        _selectedSingleOptions[group.id] = defaultOpt.id;
      } else {
        _selectedMultiOptions[group.id] = {};
        for (final opt in group.options) {
          if (opt.isDefault) {
            _selectedMultiOptions[group.id]!.add(opt.id);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _calculatedUnitPrice {
    int price = widget.item.basePriceValue;

    for (final group in widget.item.optionGroups) {
      if (!group.isMultiSelect) {
        final selectedId = _selectedSingleOptions[group.id];
        if (selectedId != null) {
          final opt = group.options.firstWhere(
            (o) => o.id == selectedId,
            orElse: () => group.options.first,
          );
          price += opt.price;
        }
      } else {
        final selectedIds = _selectedMultiOptions[group.id] ?? {};
        for (final opt in group.options) {
          if (selectedIds.contains(opt.id)) {
            price += opt.price;
          }
        }
      }
    }
    return price;
  }

  int get _calculatedTotalPrice => _calculatedUnitPrice * _quantity;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.88;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            // 1. Scrollable Content (Image, Title, Groups, Notes)
            Expanded(
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // Food Photo Hero Banner with Floating Close Action
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        // Food Photo Container with Tap-to-Expand
                        GestureDetector(
                          onTap: () {
                            if (widget.item.imageUrl.isNotEmpty) {
                              HapticFeedback.lightImpact();
                              ImageViewPage.open(
                                context,
                                image: widget.item.imageUrl,
                                title: widget.item.title,
                                heroTag: 'dish_image_${widget.item.id}',
                              );
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Hero(
                            tag: 'dish_image_${widget.item.id}',
                            child: Container(
                              height: 230,
                              width: double.infinity,
                              color: const Color(0xFFF3F4F6),
                              child: widget.item.imageUrl.isNotEmpty
                                  ? (widget.item.imageUrl.startsWith('assets')
                                      ? Image.asset(
                                          widget.item.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: const Color(0xFFFDBA74),
                                            child: const Center(
                                              child: Icon(Icons.restaurant_rounded,
                                                  color: Colors.white, size: 54),
                                            ),
                                          ),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: widget.item.imageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: const Color(0xFFF3F4F6)),
                                          errorWidget: (_, __, ___) => Container(
                                            color: const Color(0xFFFDBA74),
                                            child: const Center(
                                              child: Icon(Icons.restaurant_rounded,
                                                  color: Colors.white, size: 54),
                                            ),
                                          ),
                                        ))
                                  : Container(
                                      color: const Color(0xFFFDBA74),
                                      child: const Center(
                                        child: Icon(Icons.restaurant_rounded,
                                            color: Colors.white, size: 54),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        // Dark Gradient Overlay at Top for Button Visibility
                        IgnorePointer(
                          child: Container(
                            height: 80,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0x70000000), Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Sleek Expand Hint Pill at Bottom Corner
                        if (widget.item.imageUrl.isNotEmpty)
                          PositionedDirectional(
                            bottom: 12,
                            start: 14,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ImageViewPage.open(
                                  context,
                                  image: widget.item.imageUrl,
                                  title: widget.item.title,
                                  heroTag: 'dish_image_${widget.item.id}',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(PhosphorIconsBold.arrowsOut, color: Colors.white, size: 12),
                                    const SizedBox(width: 5),
                                    Text(
                                      'تكبير الصورة',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        // Circular Close Button (Top-Left)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                              ),
                              child: const Center(
                                child: Icon(Icons.close_rounded,
                                    color: kCharcoalDark, size: 20),
                              ),
                            ),
                          ),
                        ),

                        // Circular Favorite Button (Top-Right)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Consumer<FavoriteProductProvider>(
                            builder: (context, favProvider, _) {
                              final isFav = favProvider.isMealFavorite(widget.item.id);
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  favProvider.toggleMealFavorite(
                                      widget.item.id, widget.item);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
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
                        ),
                      ],
                    ),
                  ),

                  // Header Section: Title, Rating, Calories & Description
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Base Price Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.item.title,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: kCharcoalDark,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.item.price,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: kPrimaryOrange,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Badges Row (Calories & Merchant)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.item.calories,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: const Color(0xFF6B7280),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'من ${widget.item.restaurantName}',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Appetizing Description
                          Text(
                            widget.item.description,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: const Color(0xFF4B5563),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFFE5E7EB), height: 1),
                        ],
                      ),
                    ),
                  ),

                  // Option Groups (Sizes, Cheeses, Extras, Sauces, Removals, Drinks)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = widget.item.optionGroups[index];
                        return _buildOptionGroupSection(group);
                      },
                      childCount: widget.item.optionGroups.length,
                    ),
                  ),

                  // Special Notes Input Field
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ملاحظات خاصة للمطعم',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: kCharcoalDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            maxLines: 2,
                            style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13.5, color: kCharcoalDark),
                            decoration: InputDecoration(
                              hintText:
                                  'مثال: بدون ملح زائد، الصوص في علبة جانبية...',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(
                                color: const Color(0xFF9CA3AF),
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: kPrimaryOrange, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Sticky Bottom Action Bar (Quantity + Real-time Total + Add to Cart)
            _buildStickyBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionGroupSection(MockItemOptionGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Title & Subtitle Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                group.title,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (group.subtitle != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: group.isRequired
                        ? const Color(0xFFFFF0E8)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    group.subtitle!,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: group.isRequired
                          ? kPrimaryOrange
                          : const Color(0xFF6B7280),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Options List
          ...group.options.map((opt) {
            if (!group.isMultiSelect) {
              // Single Select (Radio Tile)
              final isSelected = _selectedSingleOptions[group.id] == opt.id;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedSingleOptions[group.id] = opt.id;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? kPrimaryOrange
                                : const Color(0xFFCBD5E1),
                            width: isSelected ? 6 : 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          opt.name,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: isSelected
                                ? kCharcoalDark
                                : const Color(0xFF374151),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (opt.price > 0)
                        Text(
                          '+${MockCatalogData.formatCurrency(opt.price)}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: isSelected
                                ? kPrimaryOrange
                                : const Color(0xFF6B7280),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            } else {
              // Multi Select (Checkbox Tile)
              final isSelected =
                  _selectedMultiOptions[group.id]?.contains(opt.id) ?? false;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedMultiOptions.putIfAbsent(group.id, () => {});
                    if (isSelected) {
                      _selectedMultiOptions[group.id]!.remove(opt.id);
                    } else {
                      _selectedMultiOptions[group.id]!.add(opt.id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: isSelected
                              ? kPrimaryOrange
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? kPrimaryOrange
                                : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          opt.name,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: isSelected
                                ? kCharcoalDark
                                : const Color(0xFF374151),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (opt.price > 0)
                        Text(
                          '+${MockCatalogData.formatCurrency(opt.price)}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: isSelected
                                ? kPrimaryOrange
                                : const Color(0xFF6B7280),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }
          }),

          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF3F4F6), height: 1),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Quantity Counter
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: _quantity > 1
                      ? () {
                          HapticFeedback.lightImpact();
                          setState(() => _quantity--);
                        }
                      : null,
                  icon: const Icon(Icons.remove, size: 17),
                  color: _quantity > 1
                      ? kCharcoalDark
                      : const Color(0xFFCBD5E1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '$_quantity',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: kCharcoalDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _quantity++);
                  },
                  icon: const Icon(Icons.add, size: 17),
                  color: kCharcoalDark,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Add to Cart Button with Calculated Price
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final cart = locator<CartProvider>();
                  final bool needsReplace = widget.isPreConfirmedReplace || cart.isDifferentMerchant(widget.item.restaurantId);

                  if (needsReplace) {
                    if (!widget.isPreConfirmedReplace) {
                      final shouldReplace = await ReplaceCartBottomSheet.show(
                        context,
                        currentStoreName: cart.getConflictingMerchantName(widget.item.restaurantId),
                        newStoreName: widget.item.restaurantName.split(' - ').first,
                      );
                      if (shouldReplace != true || !context.mounted) return;
                    }

                    await cart.replaceCartWithItem(
                      widget.item.id,
                      widget.item.restaurantId,
                      _calculatedUnitPrice.toDouble(),
                      _quantity,
                    );
                    widget.onAddToCart?.call({
                      'item': widget.item,
                      'quantity': _quantity,
                      'unitPrice': _calculatedUnitPrice,
                      'totalPrice': _calculatedTotalPrice,
                      'singleOptions': _selectedSingleOptions,
                      'multiOptions': _selectedMultiOptions,
                      'notes': _notesController.text.trim(),
                      'replacedCart': true,
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                    return;
                  }

                  HapticFeedback.mediumImpact();
                  await cart.addToCart(
                    widget.item.id,
                    widget.item.restaurantId,
                    _calculatedUnitPrice.toDouble(),
                    quantity: _quantity,
                    title: widget.item.title,
                    imageUrl: widget.item.imageUrl,
                  );
                  widget.onAddToCart?.call({
                    'item': widget.item,
                    'quantity': _quantity,
                    'unitPrice': _calculatedUnitPrice,
                    'totalPrice': _calculatedTotalPrice,
                    'singleOptions': _selectedSingleOptions,
                    'multiOptions': _selectedMultiOptions,
                    'notes': _notesController.text.trim(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'إضافة إلى السلة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      MockCatalogData.formatCurrency(_calculatedTotalPrice),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontSize: 13.5,
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
  }
}

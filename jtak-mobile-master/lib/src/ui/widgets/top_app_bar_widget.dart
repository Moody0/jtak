import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/app_parameters_provider.dart';
import '../../core/controllers/order/cart_provider.dart';
import '../../core/controllers/user/address_provider.dart';
import '../../core/models/user/address_model.dart';
import '../../core/services/locator.dart';
import '../pages/address/add_address_page.dart';
import '../pages/cart/cart_page.dart';
import 'search_bar_widget.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Home Header (Natural Seamless Scrolling Component with PhosphorIcons)
///
/// Layout in RTL:
/// [ Row 1: Address Selector (Right) ------------- Cart Floating Badge (Left) ]
/// [ Row 2: Search Bar Pill                                                   ]
/// ---------------------------------------------------------------------------

class JtakHomeHeader extends StatelessWidget {
  final VoidCallback? onAddressTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onFilterTap;
  final bool showBackButton;
  final VoidCallback? onBackTap;

  const JtakHomeHeader({
    super.key,
    this.onAddressTap,
    this.onSearchTap,
    this.onFilterTap,
    this.showBackButton = false,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      color: kPrimaryOrange,
      padding: EdgeInsets.only(
        top: topPadding + 6,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Delivery Address Location Widget + Floating Cart Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildAddressSelector(context)),
              _buildCartButton(context),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Search Bar Pill
          JtakSearchBar(
            readOnly: true,
            onTap: onSearchTap,
            onFilterTap: onFilterTap,
          ),
        ],
      ),
    );
  }

  Widget _buildCartButton(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final totalCount = cartProvider.totalQuantity;
        final hasItems = totalCount > 0;

        return AnimatedScale(
          scale: hasItems ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: hasItems ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: hasItems
                ? GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, CartPage.routeName);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      width: 42,
                      height: 42,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // 1. White Round Container
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                            ),
                            child: const Center(
                              child: Icon(
                                PhosphorIconsFill.shoppingBag,
                                color: Color(0xFF1E293B),
                                size: 20,
                              ),
                            ),
                          ),

                          // 2. Orange Count Badge (Bottom-Left in RTL / Corner)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              decoration: BoxDecoration(
                                color: kPrimaryOrange,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.8),
                              ),
                              child: Center(
                                child: Text(
                                  '$totalCount',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: Colors.white,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: 42, height: 42),
          ),
        );
      },
    );
  }

  Widget _buildAddressSelector(BuildContext context) {
    final mainAddressService = locator<AppParametersProvider>().mainAddressService;
    AddressModel currentAddress = mainAddressService.mainAddress;

    final bool hasLocation = !mainAddressService.isCoordinateEmpty();
    final bool hasTitle = currentAddress.title != null && currentAddress.title!.isNotEmpty;
    final bool hasFullAddress = currentAddress.fullAddress != null && currentAddress.fullAddress!.isNotEmpty;

    String displayAddress;
    if (hasTitle && hasFullAddress && currentAddress.title != currentAddress.fullAddress) {
      displayAddress = '${currentAddress.title} - ${currentAddress.fullAddress}';
    } else if (hasFullAddress) {
      displayAddress = currentAddress.fullAddress!;
    } else if (hasTitle) {
      displayAddress = currentAddress.title!;
    } else if (hasLocation) {
      displayAddress = 'موقعك الحالي';
    } else {
      displayAddress = 'حدد موقع التوصيل';
    }

    return GestureDetector(
      onTap: () {
        if (onAddressTap != null) {
          onAddressTap!();
        } else {
          showJtakAddressBottomSheet(context);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Back button OR Location Pin Icon (White)
          if (showBackButton)
            GestureDetector(
              onTap: onBackTap ?? () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    PhosphorIconsRegular.caretRight,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            )
          else
            const Icon(
              PhosphorIconsFill.mapPin,
              color: Colors.white,
              size: 25,
            ),

          const SizedBox(width: 8),

          // 2. Address Content Stack (White, exactly 50% of screen width)
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.50,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Label: "التوصيل إلى" (Light White)
                Text(
                  'التوصيل إلى',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 2),

                // Main Address Title + Dropdown Chevron (Solid White)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayAddress,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      PhosphorIconsRegular.caretDown,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Solid Pinned Top Header (Always Visible at Top with Smooth Shadow on Scroll)
/// ---------------------------------------------------------------------------
class SliverJtakHeader extends StatelessWidget {
  final VoidCallback? onAddressTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onFilterTap;
  final bool showBackButton;
  final VoidCallback? onBackTap;

  const SliverJtakHeader({
    super.key,
    this.onAddressTap,
    this.onSearchTap,
    this.onFilterTap,
    this.showBackButton = false,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: false,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 3,
      shadowColor: const Color(0x18000000),
      backgroundColor: kPrimaryOrange,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: 122,
      titleSpacing: 0,
      title: Container(
        color: kPrimaryOrange,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Delivery Address Location Widget + Floating Cart Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildHeaderAddress(context)),
                _buildHeaderCartButton(context),
              ],
            ),

            const SizedBox(height: 10),

            // Row 2: Search Bar Pill
            JtakSearchBar(
              readOnly: true,
              onTap: onSearchTap,
              onFilterTap: onFilterTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCartButton(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final totalCount = cartProvider.totalQuantity;
        final hasItems = totalCount > 0;

        if (!hasItems) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, CartPage.routeName);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            width: 42,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. White Round Container
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  child: const Center(
                    child: Icon(
                      PhosphorIconsFill.shoppingBag,
                      color: Color(0xFF1E293B),
                      size: 20,
                    ),
                  ),
                ),

                // 2. Orange Count Badge (Bottom-Left in RTL / Corner)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: kPrimaryOrange,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.8),
                    ),
                    child: Center(
                      child: Text(
                        '$totalCount',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderAddress(BuildContext context) {
    final mainAddressService = locator<AppParametersProvider>().mainAddressService;
    AddressModel currentAddress = mainAddressService.mainAddress;

    final bool hasLocation = !mainAddressService.isCoordinateEmpty();
    final bool hasTitle = currentAddress.title != null && currentAddress.title!.isNotEmpty;
    final bool hasFullAddress = currentAddress.fullAddress != null && currentAddress.fullAddress!.isNotEmpty;

    String displayAddress;
    if (hasTitle && hasFullAddress && currentAddress.title != currentAddress.fullAddress) {
      displayAddress = '${currentAddress.title} - ${currentAddress.fullAddress}';
    } else if (hasFullAddress) {
      displayAddress = currentAddress.fullAddress!;
    } else if (hasTitle) {
      displayAddress = currentAddress.title!;
    } else if (hasLocation) {
      displayAddress = 'موقعك الحالي';
    } else {
      displayAddress = 'حدد موقع التوصيل';
    }

    return GestureDetector(
      onTap: () {
        if (onAddressTap != null) {
          onAddressTap!();
        } else {
          showJtakAddressBottomSheet(context);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Back button OR Location Pin Icon (White)
          if (showBackButton)
            GestureDetector(
              onTap: onBackTap ?? () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    PhosphorIconsRegular.caretRight,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            )
          else
            const Icon(
              PhosphorIconsFill.mapPin,
              color: Colors.white,
              size: 25,
            ),

          const SizedBox(width: 8),

          // 2. Address Content Stack (White, exactly 50% of screen width)
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.50,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Label: "التوصيل إلى" (Light White)
                Text(
                  'التوصيل إلى',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 2),

                // Main Address Title + Dropdown Chevron (Solid White)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayAddress,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      PhosphorIconsRegular.caretDown,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// Backward-compatible alias
typedef JtakSliverAppBar = SliverJtakHeader;

/// ---------------------------------------------------------------------------
/// Modern Address Bottom Sheet (Exact Match to Reference Mockup)
/// ---------------------------------------------------------------------------
void showJtakAddressBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _JtakAddressBottomSheetContent(),
  );
}

class _JtakAddressBottomSheetContent extends StatelessWidget {
  const _JtakAddressBottomSheetContent();

  @override
  Widget build(BuildContext context) {
    final addressProvider = Provider.of<AddressProvider>(context);
    final activeAddress =
        locator<AppParametersProvider>().mainAddressService.mainAddress;

    // Use saved addresses from provider or fallback to Syrian address presets
    List<AddressModel> addresses = addressProvider.dataList.isNotEmpty
        ? addressProvider.dataList
        : [
            AddressModel(id: 1, title: 'العمل', fullAddress: 'دمشق، البرامكة - برج دمشق'),
            AddressModel(id: 2, title: 'المنزل', fullAddress: 'دمشق، المزة فيلات غربية'),
            AddressModel(id: 3, title: 'منزل العائلة', fullAddress: 'دمشق، المالكي - شارع الجلاء'),
          ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Red Drag Handle
          Center(
            child: Container(
              width: 48,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 2. Saved Addresses List
          ...addresses.map((item) {
            final isSelected = item.title == activeAddress.title ||
                item.id == activeAddress.id ||
                (item.title == 'المنزل' && activeAddress.title == null);

            return InkWell(
              onTap: () async {
                await locator<AppParametersProvider>()
                    .mainAddressService
                    .setMainAddress(item);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    // Right: Target / Bullseye Icon
                    const Icon(
                      Icons.radio_button_checked_rounded,
                      color: Color(0xFF374151),
                      size: 22,
                    ),

                    const SizedBox(width: 14),

                    // Middle: Address Label
                    Expanded(
                      child: Text(
                        item.title ?? 'عنواني',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kCharcoalDark,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    // Left: Checkmark Icon if Selected
                    if (isSelected)
                      const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF111827),
                        size: 24,
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // 3. Separator Divider
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFE2E8F0),
          ),

          const SizedBox(height: 4),

          // 4. "Add New Address" Row (إضافة عنوان جديد)
          InkWell(
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AddAddressPage.routeName);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Right: Plus Icon
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF374151),
                    size: 24,
                  ),

                  const SizedBox(width: 14),

                  // Middle: Add New Address Label
                  Expanded(
                    child: Text(
                      'إضافة عنوان جديد',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: kCharcoalDark,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  // Left: Arrow Chevron Icon
                  const Icon(
                    PhosphorIconsRegular.caretLeft,
                    color: Color(0xFF9CA3AF),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

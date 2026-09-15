import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/app_parameters_provider.dart';
import '../../core/controllers/order/cart_provider.dart';
import '../../core/controllers/user/address_provider.dart';
import '../../core/models/user/address_model.dart';
import '../../core/services/authentication_service.dart';
import '../../core/services/locator.dart';
import '../pages/account/login_page.dart';
import '../pages/address/add_address_page.dart';
import '../pages/address/address_page.dart';
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

class _JtakAddressBottomSheetContent extends StatefulWidget {
  const _JtakAddressBottomSheetContent();

  @override
  State<_JtakAddressBottomSheetContent> createState() =>
      _JtakAddressBottomSheetContentState();
}

class _JtakAddressBottomSheetContentState
    extends State<_JtakAddressBottomSheetContent> {
  bool _isLocatingGps = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AddressProvider>(context, listen: false).loadData();
      }
    });
  }

  IconData _resolveAddressIcon(String? title) {
    final lower = (title ?? '').toLowerCase();
    if (lower.contains('منزل') ||
        lower.contains('بيت') ||
        lower.contains('home')) {
      return PhosphorIconsFill.house;
    } else if (lower.contains('عمل') ||
        lower.contains('مكتب') ||
        lower.contains('شغل') ||
        lower.contains('work') ||
        lower.contains('office')) {
      return PhosphorIconsFill.briefcase;
    }
    return PhosphorIconsFill.mapPin;
  }

  Future<void> _selectCurrentLocation() async {
    setState(() => _isLocatingGps = true);
    final mainAddressService =
        locator<AppParametersProvider>().mainAddressService;
    try {
      await mainAddressService.checkMainCorrdinate(context);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLocatingGps = false);
    Navigator.pop(context);
  }

  Future<void> _showAddressAuthPrompt(BuildContext bottomSheetContext) async {
    final rootNav = Navigator.of(bottomSheetContext, rootNavigator: true);
    await showModalBottomSheet(
      context: bottomSheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (promptCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E8),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Center(
                      child: Icon(
                        PhosphorIconsFill.mapPinPlus,
                        color: kPrimaryOrange,
                        size: 34,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'تسجيل الدخول لحفظ العنوان',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: kCharcoalDark,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'يتطلب حفظ العناوين وإدارتها تسجيل الدخول إلى حسابك لتتمكن من الوصول إليها في أي وقت وتسهيل طلباتك القادمة.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(promptCtx);
                    Navigator.pop(bottomSheetContext);
                    final res = await rootNav.pushNamed(LoginPage.routeName);
                    if (res is bool && res && rootNav.mounted) {
                      rootNav.pushNamed(AddAddressPage.routeName);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: kPrimaryOrange,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x40FF5400),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'تسجيل الدخول / إنشاء حساب',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(promptCtx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    'المتابعة كضيف واستخدام الموقع الحالي',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addressProvider = Provider.of<AddressProvider>(context);
    final mainAddressService =
        locator<AppParametersProvider>().mainAddressService;
    final activeAddress = mainAddressService.mainAddress;

    // Real saved addresses from the user's account (deduplicated for clear UX)
    final Set<String> seenAddressKeys = {};
    final List<AddressModel> savedAddresses = [];
    for (final a in addressProvider.dataList) {
      if (a.id != null && a.id! > 0) {
        final key = '${(a.title ?? '').trim()}_${(a.fullAddress ?? '').trim()}';
        if (seenAddressKeys.add(key)) {
          savedAddresses.add(a);
        }
      }
    }

    // Check if current active selection is GPS / current location
    final bool isCurrentLocationActive =
        activeAddress.id == null || activeAddress.id == 0;

    final String gpsAddressText = (activeAddress.fullAddress?.isNotEmpty == true)
        ? activeAddress.fullAddress!
        : ((activeAddress.title?.isNotEmpty == true)
            ? activeAddress.title!
            : 'تحديد الموقع تلقائياً عبر GPS');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Neutral Elegant Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Header Row: Title & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'توصيل إلى',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kCharcoalDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          PhosphorIconsRegular.x,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 3. Option A: Current GPS Location Card (الموقع الحالي)
              InkWell(
                onTap: _isLocatingGps ? null : _selectCurrentLocation,
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCurrentLocationActive
                        ? const Color(0xFFFFF7ED)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isCurrentLocationActive
                          ? kPrimaryOrange
                          : const Color(0xFFE2E8F0),
                      width: isCurrentLocationActive ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Squircle GPS Icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isCurrentLocationActive
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: _isLocatingGps
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        kPrimaryOrange),
                                  ),
                                )
                              : const Icon(
                                  PhosphorIconsFill.navigationArrow,
                                  color: kPrimaryOrange,
                                  size: 22,
                                ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'موقعي الحالي',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: kCharcoalDark,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'GPS',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              gpsAddressText,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Radio Affordance
                      Icon(
                        isCurrentLocationActive
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isCurrentLocationActive
                            ? kPrimaryOrange
                            : const Color(0xFFCBD5E1),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 4. Section: Saved Addresses Title & Manage Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'العناوين المحفوظة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      if (savedAddresses.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${savedAddresses.length}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (savedAddresses.isNotEmpty)
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AddressPage.routeName);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        child: Text(
                          'إدارة العناوين',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: kPrimaryOrange,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // 5. Dynamic Saved Addresses List or Empty State
              if (savedAddresses.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.bookmarkSimple,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'لا توجد عناوين محفوظة بعد',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'احفظ عناوينك المفضلة (المنزل، العمل...) لطلب أسرع',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.35,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: savedAddresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = savedAddresses[index];
                      final bool isSelected = !isCurrentLocationActive &&
                          item.id != null &&
                          item.id == activeAddress.id;

                      final String title = item.title?.isNotEmpty == true
                          ? item.title!
                          : 'عنوان محفوظ';
                      final String? subtitle = item.fullAddress?.isNotEmpty == true
                          ? item.fullAddress
                          : (item.level1?.isNotEmpty == true ? item.level1 : null);

                      return InkWell(
                        onTap: () async {
                          await mainAddressService.setMainAddress(item);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFFF7ED)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? kPrimaryOrange
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFEDD5)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _resolveAddressIcon(title),
                                  color: isSelected
                                      ? kPrimaryOrange
                                      : const Color(0xFF64748B),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: kCharcoalDark,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (subtitle != null &&
                                        subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          color: const Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Delete action
                              InkWell(
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  final id = item.id;
                                  if (id != null && id > 0) {
                                    await addressProvider.delete(id);
                                    if (isSelected && context.mounted) {
                                      await mainAddressService.checkMainCorrdinate(context);
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(
                                    PhosphorIconsRegular.trash,
                                    color: Color(0xFF94A3B8),
                                    size: 19,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),

                              // Selection indicator
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected
                                    ? kPrimaryOrange
                                    : const Color(0xFFCBD5E1),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // 6. "Add New Address" Action Card (إضافة عنوان جديد)
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final isLogin = locator<AuthenticationService>().isLogin();
                  if (!isLogin) {
                    _showAddressAuthPrompt(context);
                    return;
                  }
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AddAddressPage.routeName);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            PhosphorIconsBold.plus,
                            color: kPrimaryOrange,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إضافة عنوان جديد',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: kCharcoalDark,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'حدد موقعاً جديداً على الخريطة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: const Color(0xFF64748B),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        PhosphorIconsBold.caretLeft,
                        color: Color(0xFF94A3B8),
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

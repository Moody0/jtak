import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/app/merchant_state_provider.dart';
import '../../core/controllers/app_parameters_provider.dart';
import '../../core/controllers/merchant_profile_provider.dart';
import '../../core/services/authentication_service.dart';
import '../../core/services/locator.dart';
import '../../core/services/upload_service.dart';
import '../../utils/custom_widgets/messages.dart';
import '../sections/merchant_bottom_navigation.dart';
import 'catalog/products_page.dart';
import 'order/orders_page.dart';
import 'store/store_settings_page.dart';
import 'transaction/transaction_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Merchant Owner App Shell (Main Navigation, Store Status Pill & Tabs)
/// ---------------------------------------------------------------------------

class MainPage extends StatefulWidget {
  static const String routeName = '/MainPage';
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final List<Widget> _pages = [
    const OrdersPage(),
    const SearchPage(),
    const TransactionPage(),
    const StoreSettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    locator<AppParametersProvider>().initServices(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      locator<MerchantProfileProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final merchantProvider = Provider.of<MerchantStateProvider>(context);
    final profileProv = Provider.of<MerchantProfileProvider>(context);
    final authService = Provider.of<AuthenticationService>(context);
    final user = authService.user;
    final p = profileProv.profile;

    final storeName = p?.title.isNotEmpty == true
        ? p!.title
        : (user?.fullName?.isNotEmpty == true ? user!.fullName! : 'متجري');
    final logoUrl = UploadService.resolveImageUrl(p?.logo);

    return PopScope(
      canPop: merchantProvider.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && merchantProvider.currentIndex != 0) {
          merchantProvider.setIndex(0);
        }
      },
      child: Scaffold(
        backgroundColor: kPageBackground,
        appBar: _buildHeaderAppBar(context, merchantProvider, profileProv, storeName, logoUrl),
        body: IndexedStack(
          index: merchantProvider.currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: MerchantBottomNavigation(
          onChange: (index) => merchantProvider.setIndex(index),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeaderAppBar(
    BuildContext context,
    MerchantStateProvider merchantProvider,
    MerchantProfileProvider profileProv,
    String storeName,
    String logoUrl,
  ) {
    final isOpen = merchantProvider.isStoreOpen;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          merchantProvider.setIndex(3);
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            // Store Logo / Brand Squircle Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD6C2), width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: logoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Center(
                          child: Transform.flip(
                            flipX: true,
                            child: const Icon(PhosphorIconsFill.storefront, size: 20, color: kPrimaryOrange),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Center(
                          child: Transform.flip(
                            flipX: true,
                            child: const Icon(PhosphorIconsFill.storefront, size: 20, color: kPrimaryOrange),
                          ),
                        ),
                      )
                    : Center(
                        child: Transform.flip(
                          flipX: true,
                          child: const Icon(
                            PhosphorIconsFill.storefront,
                            size: 20,
                            color: kPrimaryOrange,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),

            // Store Name & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          storeName,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: kCharcoalDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.flip(
                        flipX: true,
                        child: const Icon(
                          PhosphorIconsFill.sealCheck,
                          size: 15,
                          color: kPrimaryOrange,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'لوحة تحكّم المتجر',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: kCharcoalMuted,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // 1. Live Store Status Toggle Pill (Open 🟢 / Closed 🔴)
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            merchantProvider.toggleStoreStatus();
            final nowOpen = merchantProvider.isStoreOpen;
            profileProv.toggleStoreStatus(nowOpen);
            SnackBarWidget.showCustomSnackBar(
              context,
              nowOpen
                  ? 'المتجر متاح ويستقبل الطلبات الآن 🟢'
                  : 'تم إيقاف استقبال الطلبات مؤقتاً 🔴',
              backgroundColor: nowOpen ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOpen ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOpen ? 'مفتوح' : 'مغلق',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isOpen ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 6),

        // 2. Audio Alert Sound Toggle (Chime on/off)
        IconButton(
          icon: Transform.flip(
            flipX: true,
            child: Icon(
              merchantProvider.isSoundAlertEnabled
                  ? PhosphorIconsFill.bellRinging
                  : PhosphorIconsRegular.bellSlash,
              size: 20,
              color: merchantProvider.isSoundAlertEnabled ? kPrimaryOrange : const Color(0xFF94A3B8),
            ),
          ),
          tooltip: merchantProvider.isSoundAlertEnabled
              ? 'تنبيهات الطلبات الصوتية مفعلة'
              : 'تنبيهات الطلبات الصوتية معطلة',
          onPressed: () {
            HapticFeedback.lightImpact();
            merchantProvider.toggleSoundAlert();
            SnackBarWidget.showCustomSnackBar(
              context,
              merchantProvider.isSoundAlertEnabled
                  ? 'تم تفعيل نغمة تنبيه الطلبات 🔔'
                  : 'تم كتم نغمة التنبيه 🔕',
            );
          },
        ),

        const SizedBox(width: 8),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE2E8F0), thickness: 1),
      ),
    );
  }
}

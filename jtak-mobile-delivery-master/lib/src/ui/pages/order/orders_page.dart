import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/order_provider.dart';
import '../../../core/controllers/transactions_provider.dart';
import '../../../core/models/lat_lng_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../core/services/location_service.dart';
import '../../../utils/extensions/context_extension.dart';
import '../../../ui/pages/account/login_page.dart';
import '../../../ui/pages/account/profile_page.dart';
import '../../../ui/pages/order/order_details_page.dart';
import '../../../ui/pages/setting_page.dart';
import '../../../ui/pages/transaction/transaction_page.dart';
import '../../../utils/utilities/global_var.dart';

class OrdersPage extends StatefulWidget {
  static const String routeName = '/OrdersPage';
  const OrdersPage({Key? key}) : super(key: key);

  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  Timer? _refreshTimer;
  LatLng? _driverLocation;

  @override
  void initState() {
    super.initState();
    _loadInitialDashboardData();
    _refreshDriverLocation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final model = Provider.of<OrderProvider>(context, listen: false);
      if (!model.isBusy) model.silentSync();
      _refreshDriverLocation();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshDriverLocation() async {
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc != null && mounted) {
        setState(() => _driverLocation = loc);
      }
    } catch (_) {
      // Best-effort only: order cards fall back to no distance shown.
    }
  }

  /// Real driver->pickup distance computed from the live GPS fix and the
  /// merchant's coordinates. Returns null when either point is unavailable
  /// so callers can show a neutral state instead of a made-up figure.
  double? _distanceToOrderKm(OrderModel order) {
    final driver = _driverLocation;
    if (driver == null) return null;

    double? destLat;
    double? destLng;
    if (order.orderDetails != null && order.orderDetails!.isNotEmpty) {
      destLat = order.orderDetails!.first.lat;
      destLng = order.orderDetails!.first.lng;
    }
    destLat ??= order.lat;
    destLng ??= order.lng;
    if (destLat == null || destLng == null) return null;

    final meters = Geolocator.distanceBetween(
      driver.latitude,
      driver.longitude,
      destLat,
      destLng,
    );
    return meters / 1000;
  }

  Future<void> _loadInitialDashboardData() async {
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final transProv = Provider.of<TransactionsProvider>(context, listen: false);
    final authService = Provider.of<AuthenticationService>(context, listen: false);

    await Future.wait([
      orderProv.refreshData(),
      transProv.loadBalances(),
      authService.loadUserData(),
    ]);
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return '0';
    final rounded = amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    return rounded.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _toggleShiftStatus(BuildContext context, OrderProvider orderProv) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final targetOnline = !orderProv.isOnline;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              targetOnline ? Icons.play_circle_filled_rounded : Icons.pause_circle_filled_rounded,
              color: targetOnline ? kGreen : kRed,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              targetOnline
                  ? (isArabic ? 'بدء وردية التوصيل' : 'Go Online')
                  : (isArabic ? 'إيقاف مؤقت للوردية' : 'Go Offline'),
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          targetOnline
              ? (isArabic
                  ? 'هل تريد بدء الوردية واستلام طلبات جديدة ومشاركة موقعك مع العملاء؟'
                  : 'Start your shift to begin receiving delivery requests and broadcast live GPS?')
              : (isArabic
                  ? 'هل تريد إيقاف الوردية؟ لن يتم توجيه أي طلبات جديدة إليك أثناء التوقف.'
                  : 'Pause your shift? You will not receive any new delivery dispatches while offline.'),
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, color: kCharcoalMuted),
        ),
        actions: [
          TextButton(
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: GoogleFonts.ibmPlexSansArabic()),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: targetOnline ? kGreen : kRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              targetOnline ? (isArabic ? 'تأكيد والبدء' : 'Confirm') : (isArabic ? 'إيقاف الآن' : 'Pause Shift'),
              style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              orderProv.setShiftStatus(targetOnline);
            },
          ),
        ],
      ),
    );
  }

  void _openHelpCenter(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isArabic ? 'مركز مساعدة السائقين' : 'Driver Support Center',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'فريق الدعم الفني جاهز لمساعدتك على مدار الساعة أثناء التوصيل.'
                  : 'Our driver support team is ready to assist you 24/7.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                color: kCharcoalMuted,
              ),
            ),
            const SizedBox(height: 22),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kSurfaceWarm,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(PhosphorIcons.phoneCallBold, color: kPrimaryOrange),
              ),
              title: Text(
                isArabic ? 'الاتصال المباشر بالدعم' : 'Call Support',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('+963 11 9876543', style: GoogleFonts.ibmPlexSansArabic(color: kCharcoalMuted)),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('tel:+963119876543');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(PhosphorIcons.whatsappLogoBold, color: kGreen),
              ),
              title: Text(
                isArabic ? 'محادثة واتساب الفورية' : 'WhatsApp Support',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                isArabic ? 'رد فوري لمشاكل التوصيل' : 'Instant response for active delivery issues',
                style: GoogleFonts.ibmPlexSansArabic(color: kCharcoalMuted),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('https://wa.me/963985615705');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isArabic ? 'تسجيل الخروج' : 'Logout',
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من رغبتك في تسجيل الخروج من تطبيق السائق؟'
              : 'Are you sure you want to log out of the delivery app?',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, color: kCharcoalMuted),
        ),
        actions: [
          TextButton(
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: GoogleFonts.ibmPlexSansArabic()),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isArabic ? 'تأكيد الخروج' : 'Log Out',
              style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await locator<AuthenticationService>().logOut();
              if (context.mounted) {
                context.navigateToReset(LoginPage.routeName);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStoreIcon(OrderModel order) {
    final merchantTitle = (order.orderDetails != null && order.orderDetails!.isNotEmpty)
        ? (order.orderDetails!.first.merchantTitle ?? '').toLowerCase()
        : '';

    IconData iconData = PhosphorIcons.shoppingBagBold;

    if (merchantTitle.contains('حلويات') ||
        merchantTitle.contains('كافيه') ||
        merchantTitle.contains('قهوة') ||
        merchantTitle.contains('sweet')) {
      iconData = PhosphorIcons.coffeeBold;
    } else if (merchantTitle.contains('مطعم') ||
        merchantTitle.contains('شاورما') ||
        merchantTitle.contains('برغر') ||
        merchantTitle.contains('food')) {
      iconData = PhosphorIcons.forkKnifeBold;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: kPrimaryOrange,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(iconData, color: Colors.white, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);
    final transProv = Provider.of<TransactionsProvider>(context);
    final authService = Provider.of<AuthenticationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final user = authService.user;
    final fullName = user?.fullName?.trim() ?? '';
    final firstName = fullName.isNotEmpty ? fullName.split(' ').first : (isArabic ? 'السائق' : 'Driver');

    final activeOrders = orderProv.dataList;
    final balanceAmount = transProv.balances.amount ?? 0.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : kPageBackground,
      body: RefreshIndicator(
        color: kPrimaryOrange,
        onRefresh: _loadInitialDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Driver Greeting & Interactive Shift Status Toggle
              _buildGreetingAndShiftRow(context, firstName, isArabic, orderProv),

              const SizedBox(height: 18),

              // 2. Driver KPI Performance Cards (3 Cards Row)
              _buildKpiCardsRow(context, balanceAmount, isArabic, activeOrders.length),

              const SizedBox(height: 24),

              // 3. Active Deliveries Header ("الطلبات الحالية")
              _buildActiveOrdersHeader(context, isArabic, activeOrders.length),

              const SizedBox(height: 12),

              // 4. Active Deliveries List or Clean Empty State
              _buildActiveOrdersContent(context, activeOrders, isArabic, isDark),

              const SizedBox(height: 24),

              // 5. Quick Navigation Menu List
              _buildQuickNavigationSection(context, isArabic, isDark),

              const SizedBox(height: 20),

              // 6. Bottom Logout Button
              _buildLogoutButton(context, isArabic),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Greeting & Shift Status Toggle
  // ---------------------------------------------------------------------------
  Widget _buildGreetingAndShiftRow(
    BuildContext context,
    String firstName,
    bool isArabic,
    OrderProvider orderProv,
  ) {
    final isOnline = orderProv.isOnline;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Driver Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'مرحباً $firstName' : 'Welcome, $firstName',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isArabic ? 'مستعد لتوصيل المزيد من الطلبات؟' : 'Ready to deliver more orders?',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kCharcoalMuted,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Interactive Shift Status Toggle Pill
        GestureDetector(
          onTap: () => _toggleShiftStatus(context, orderProv),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isOnline ? kGreen : kRed).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? kGreen : kRed,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? (isArabic ? 'متاح' : 'Online') : (isArabic ? 'غير متاح' : 'Offline'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isOnline ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline
                      ? (isArabic ? 'جاهز لاستقبال الطلبات' : 'Ready for orders')
                      : (isArabic ? 'الوردية متوقفة' : 'Shift paused'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isOnline ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. 3-Card KPI Performance Metrics Row
  // ---------------------------------------------------------------------------
  Widget _buildKpiCardsRow(
    BuildContext context,
    double balanceAmount,
    bool isArabic,
    int activeCount,
  ) {
    return Row(
      children: [
        // 1. Current Balance Card
        Expanded(
          child: _buildMetricCard(
            icon: PhosphorIcons.walletBold,
            value: '${_formatCurrency(balanceAmount)} ${isArabic ? 'ل.س' : 'SYP'}',
            label: isArabic ? 'الرصيد الحالي' : 'Current Balance',
          ),
        ),
        const SizedBox(width: 10),

        // 2. Active Orders Card
        Expanded(
          child: _buildMetricCard(
            icon: PhosphorIcons.packageBold,
            value: '$activeCount',
            label: isArabic ? 'الطلبات النشطة' : 'Active Orders',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kPrimaryOrange, size: 20),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: kCharcoalMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Active Deliveries Header Row
  // ---------------------------------------------------------------------------
  Widget _buildActiveOrdersHeader(
    BuildContext context,
    bool isArabic,
    int count,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              isArabic ? 'الطلبات الحالية' : 'Current Orders',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD4C0), width: 1),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryOrange,
                ),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            // Refresh / view all
            Provider.of<OrderProvider>(context, listen: false).refreshData();
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            isArabic ? 'عرض الكل' : 'View All',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: kPrimaryOrange,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Active Deliveries Content (Order Cards or Empty State)
  // ---------------------------------------------------------------------------
  Widget _buildActiveOrdersContent(
    BuildContext context,
    List<OrderModel> orders,
    bool isArabic,
    bool isDark,
  ) {
    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0E8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIcons.mopedBold,
                color: kPrimaryOrange,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'لا توجد طلبات جارية حالياً' : 'No active deliveries right now',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kCharcoalDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isArabic
                  ? 'سيتم إسناد الطلبات الجديدة إليك فور تأكيدها وتجهيزها.'
                  : 'New orders will appear here automatically when assigned.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                color: kCharcoalMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: orders.asMap().entries.map((entry) {
        final index = entry.key;
        final order = entry.value;
        final isPrimaryAction = index == 0;

        final merchantTitle = (order.orderDetails != null && order.orderDetails!.isNotEmpty)
            ? (order.orderDetails!.first.merchantTitle ?? '')
            : '';
        final merchantTitleDisplay =
            merchantTitle.isNotEmpty ? merchantTitle : (isArabic ? 'متجر غير معروف' : 'Unknown merchant');

        final streetAddress = (order.orderDetails != null && order.orderDetails!.isNotEmpty)
            ? (order.orderDetails!.first.merchantAddress ?? order.address ?? '')
            : (order.address ?? '');
        final streetAddressDisplay =
            streetAddress.isNotEmpty ? streetAddress : (isArabic ? 'العنوان غير متوفر' : 'Address unavailable');

        final timeFormatted = GlobalVar.dateForamt(order.purchaseDate, 'HH:mm') ?? '--:--';
        final priceFormatted = _formatCurrency(order.price);
        final distanceKm = _distanceToOrderKm(order);
        final distanceFormatted = distanceKm != null
            ? '${distanceKm.toStringAsFixed(1)} ${isArabic ? 'كم' : 'km'}'
            : '-- ${isArabic ? 'كم' : 'km'}';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrimaryAction ? const Color(0xFFFFD4C0) : const Color(0xFFE2E8F0),
              width: isPrimaryAction ? 1.2 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row: Store Icon + Info on Right, Time/Distance/Price on Left
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Category Icon Squircle
                  _buildStoreIcon(order),

                  const SizedBox(width: 12),

                  // Store Info & Order ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.id != null ? '#${order.id}' : '',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kPrimaryOrange,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          merchantTitleDisplay,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kCharcoalDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          streetAddressDisplay,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: kCharcoalMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Time, Distance, Price Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeFormatted,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: kCharcoalDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(PhosphorIcons.clockBold, size: 14, color: kCharcoalMuted),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            distanceFormatted,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: kCharcoalMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(PhosphorIcons.mapPinBold, size: 14, color: kCharcoalMuted),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$priceFormatted ${isArabic ? 'ل.س' : 'SYP'}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: kPrimaryOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Action Button: "ابدأ التوصيل"
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsPage(order),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPrimaryAction ? kPrimaryOrange : const Color(0xFFFFF0E8),
                    foregroundColor: isPrimaryAction ? Colors.white : kPrimaryOrange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isArabic ? 'ابدأ التوصيل' : 'Start Delivery',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isPrimaryAction ? Colors.white : kPrimaryOrange,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Quick Access Navigation Menu List
  // ---------------------------------------------------------------------------
  Widget _buildQuickNavigationSection(
    BuildContext context,
    bool isArabic,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        children: [
          // 1. Transactions
          _buildQuickNavItem(
            icon: PhosphorIcons.receiptBold,
            title: isArabic ? 'سجل الحركات المالية' : 'Transactions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransactionPage()),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 2. Profile
          _buildQuickNavItem(
            icon: PhosphorIcons.userCircleBold,
            title: isArabic ? 'الملف الشخصي' : 'Profile',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 3. Settings
          _buildQuickNavItem(
            icon: PhosphorIcons.gearBold,
            title: isArabic ? 'الإعدادات' : 'Settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingPage()),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 4. Help Center
          _buildQuickNavItem(
            icon: PhosphorIcons.chatCircleDotsBold,
            title: isArabic ? 'مركز المساعدة' : 'Help Center',
            onTap: () => _openHelpCenter(context),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Chevron arrow (Left side in RTL)
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: Color(0xFF94A3B8),
            ),

            const Spacer(),

            // Title
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kCharcoalDark,
              ),
            ),

            const SizedBox(width: 14),

            // Icon Squircle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: kCharcoalDark, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Logout Button
  // ---------------------------------------------------------------------------
  Widget _buildLogoutButton(BuildContext context, bool isArabic) {
    return TextButton.icon(
      onPressed: () => _confirmLogout(context),
      icon: const Icon(PhosphorIcons.signOutBold, color: kRed, size: 20),
      label: Text(
        isArabic ? 'تسجيل الخروج' : 'Log Out',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: kRed,
        ),
      ),
    );
  }
}

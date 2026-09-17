import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/order_provider.dart';
import '../../../core/models/lat_lng_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/location_service.dart';
import '../../../ui/widgets/app_widgets.dart';
import 'order_widgets.dart';

class OrdersPage extends StatefulWidget {
  static const String routeName = '/OrdersPage';
  const OrdersPage({Key? key}) : super(key: key);

  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  Timer? _refreshTimer;
  LatLng? _driverLocation;
  int _selectedOrdersTab = 0; // 0 = Active, 1 = Completed

  @override
  void initState() {
    super.initState();
    _loadInitialDashboardData();
    _refreshDriverLocation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final model = Provider.of<OrderProvider>(context, listen: false);
      if (!model.isBusy) {
        model.silentSync();
        if (model.isOnline) model.fetchAvailableOrders();
      }
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
    final authService =
        Provider.of<AuthenticationService>(context, listen: false);

    await Future.wait([
      orderProv.refreshData(),
      orderProv.fetchAvailableOrders(),
      authService.loadUserData(),
    ]);
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return '0';
    final rounded =
        amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
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
            HomeMirroredIcon(
              targetOnline
                  ? Icons.play_circle_filled_rounded
                  : Icons.pause_circle_filled_rounded,
              color: targetOnline ? kGreen : kRed,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              targetOnline
                  ? (isArabic ? 'بدء وردية التوصيل' : 'Go Online')
                  : (isArabic ? 'إيقاف مؤقت للوردية' : 'Go Offline'),
              style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w700, fontSize: 16),
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
          style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5, color: kCharcoalMuted),
        ),
        actions: [
          TextButton(
            child: Text(isArabic ? 'إلغاء' : 'Cancel',
                style: GoogleFonts.ibmPlexSansArabic()),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: targetOnline ? kGreen : kRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              targetOnline
                  ? (isArabic ? 'تأكيد والبدء' : 'Confirm')
                  : (isArabic ? 'إيقاف الآن' : 'Pause Shift'),
              style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white, fontWeight: FontWeight.w700),
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

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);
    final authService = Provider.of<AuthenticationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final user = authService.user;
    final fullName = user?.fullName?.trim() ?? '';
    final firstName = fullName.isNotEmpty
        ? fullName.split(' ').first
        : (isArabic ? 'السائق' : 'Driver');

    final activeOrders = orderProv.activeOrders;
    final completedOrders = orderProv.completedOrders;
    final displayOrders =
        _selectedOrdersTab == 0 ? activeOrders : completedOrders;
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
              _buildGreetingAndShiftRow(
                  context, firstName, isArabic, orderProv),

              const SizedBox(height: 18),

              // 2. Dispatch summary: only information needed to work the shift
              _buildDispatchSummary(context, orderProv, isArabic, isDark),

              const SizedBox(height: 24),

              // 3. Available orders are visible and actionable, not hidden
              // behind a notification-only flow.
              if (orderProv.availableOrders.isNotEmpty) ...[
                _buildAvailableOrdersSection(
                    context, orderProv, isArabic, isDark),
                const SizedBox(height: 24),
              ],

              // 4. Active vs Completed Deliveries Header Tabs
              _buildActiveOrdersHeader(context, isArabic, activeOrders.length,
                  completedOrders.length),

              const SizedBox(height: 12),

              // 5. Deliveries List or Clean Empty State
              _buildActiveOrdersContent(
                  context, displayOrders, isArabic, isDark),

              const SizedBox(height: 24),
              // Account, finances, help and logout stay in dedicated tabs/menu.
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
                isArabic
                    ? 'مستعد لتوصيل المزيد من الطلبات؟'
                    : 'Ready to deliver more orders?',
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
              color:
                  isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOnline
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFFECACA),
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
                      isOnline
                          ? (isArabic ? 'متاح' : 'Online')
                          : (isArabic ? 'غير متاح' : 'Offline'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isOnline
                            ? const Color(0xFF047857)
                            : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline
                      ? (isArabic
                          ? 'جاهز لاستقبال الطلبات'
                          : 'Ready for orders')
                      : (isArabic ? 'الوردية متوقفة' : 'Shift paused'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isOnline
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
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
  Widget _buildDispatchSummary(
    BuildContext context,
    OrderProvider orderProv,
    bool isArabic,
    bool isDark,
  ) {
    final activeCount = orderProv.activeOrders.length;
    final availableCount = orderProv.availableOrders.length;
    final accent = availableCount > 0 ? kPrimaryOrange : kGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : kCardBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: HomeMirroredIcon(
              availableCount > 0
                  ? PhosphorIcons.bellRingingBold
                  : PhosphorIcons.checkCircleBold,
              color: accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  availableCount > 0
                      ? (isArabic
                          ? 'طلبات جديدة متاحة'
                          : 'New orders are available')
                      : (isArabic
                          ? 'كل شيء تحت السيطرة'
                          : 'You are all caught up'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isArabic
                      ? '$activeCount طلب نشط • $availableCount متاح للاستلام'
                      : '$activeCount active • $availableCount available to receive',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFFCBD5E1) : kCharcoalMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: orderProv.isFetchingAvailable
                ? null
                : orderProv.fetchAvailableOrders,
            tooltip:
                isArabic ? 'تحديث الطلبات المتاحة' : 'Refresh available orders',
            icon: orderProv.isFetchingAvailable
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : HomeMirroredIcon(
                    PhosphorIcons.arrowsClockwiseBold,
                    color: isDark ? Colors.white70 : kCharcoalMuted,
                    size: 20,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableOrdersSection(
    BuildContext context,
    OrderProvider orderProv,
    bool isArabic,
    bool isDark,
  ) {
    final orders = orderProv.availableOrders.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'طلبات يمكنك استلامها' : 'Orders you can receive',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : kCharcoalDark,
              ),
            ),
            if (orderProv.availableOrders.length > orders.length)
              Text(
                '+${orderProv.availableOrders.length - orders.length}',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryOrange,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...orders.map((order) => _buildAvailableOrderCard(
            context, orderProv, order, isArabic, isDark)),
      ],
    );
  }

  Widget _buildAvailableOrderCard(
    BuildContext context,
    OrderProvider orderProv,
    OrderModel order,
    bool isArabic,
    bool isDark,
  ) {
    final isClaiming = orderProv.isActionInFlight(order.id);
    final price = _formatCurrency(order.price);
    final store = order.primaryMerchantTitle;
    final pickupAddress = order.primaryMerchantAddress;
    final dropoffAddress = order.address ??
        (isArabic ? 'عنوان العميل غير متوفر' : 'Customer address unavailable');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryOrange.withValues(alpha: 0.28)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.id ?? '--'}  •  $store',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                ),
              ),
              Text(
                order.isCod
                    ? '$price ${isArabic ? 'ل.س نقداً' : 'SYP cash'}'
                    : (isArabic ? 'مدفوع' : 'Prepaid'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: order.isCod ? kPrimaryOrange : kGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRouteLine(
            icon: PhosphorIcons.storefrontBold,
            label: isArabic ? 'من $pickupAddress' : 'From $pickupAddress',
            color: kPrimaryOrange,
            isDark: isDark,
          ),
          const SizedBox(height: 5),
          _buildRouteLine(
            icon: PhosphorIcons.mapPinBold,
            label: isArabic ? 'إلى $dropoffAddress' : 'To $dropoffAddress',
            color: kGreen,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: isClaiming || order.id == null
                  ? null
                  : () => _claimAvailableOrder(
                      context, orderProv, order.id!, isArabic),
              icon: isClaiming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const HomeMirroredIcon(PhosphorIcons.handPointingBold,
                      size: 18),
              label: Text(
                isClaiming
                    ? (isArabic ? 'جارٍ الاستلام...' : 'Receiving...')
                    : (isArabic ? 'استلام الطلب' : 'Receive order'),
                style:
                    GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteLine({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        HomeMirroredIcon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : kCharcoalMuted,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _claimAvailableOrder(
    BuildContext context,
    OrderProvider orderProv,
    int orderId,
    bool isArabic,
  ) async {
    try {
      final claimed = await orderProv.claimOrder(orderId);
      if (!context.mounted || !claimed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم استلام الطلب وإضافته إلى طلباتك الحالية'
                : 'Order received and added to your active deliveries',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
          ),
          backgroundColor: kGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', '').trim(),
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
          ),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await orderProv.fetchAvailableOrders();
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Active & Completed Deliveries Header Tabs
  // ---------------------------------------------------------------------------
  Widget _buildActiveOrdersHeader(
    BuildContext context,
    bool isArabic,
    int activeCount,
    int completedCount,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildOrderTabPill(
              title: isArabic ? 'الطلبات الحالية' : 'Current',
              count: activeCount,
              isSelected: _selectedOrdersTab == 0,
              onTap: () {
                setState(() => _selectedOrdersTab = 0);
              },
            ),
            const SizedBox(width: 8),
            _buildOrderTabPill(
              title: isArabic ? 'سجل الطلبات' : 'History',
              count: completedCount,
              isSelected: _selectedOrdersTab == 1,
              onTap: () {
                setState(() => _selectedOrdersTab = 1);
              },
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            // Refresh
            Provider.of<OrderProvider>(context, listen: false).refreshData();
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            isArabic ? 'تحديث' : 'Refresh',
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

  Widget _buildOrderTabPill({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryOrange : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimaryOrange : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : kCharcoalDark,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : kCharcoalMuted,
                ),
              ),
            ),
          ],
        ),
      ),
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
      final isCompletedTab = _selectedOrdersTab == 1;
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isCompletedTab
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFF0E8),
                shape: BoxShape.circle,
              ),
              child: HomeMirroredIcon(
                isCompletedTab
                    ? PhosphorIcons.checkCircleBold
                    : PhosphorIcons.mopedBold,
                color:
                    isCompletedTab ? const Color(0xFF059669) : kPrimaryOrange,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isCompletedTab
                  ? (isArabic
                      ? 'لا توجد طلبات مكتملة حتى الآن'
                      : 'No completed deliveries yet')
                  : (isArabic
                      ? 'لا توجد طلبات جارية حالياً'
                      : 'No active deliveries right now'),
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : kCharcoalDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isCompletedTab
                  ? (isArabic
                      ? 'الطلبات التي تقوم بتسليمها بنجاح ستظهر في هذا السجل.'
                      : 'Orders you successfully deliver will appear in this history.')
                  : (isArabic
                      ? 'سيتم إسناد الطلبات الجديدة إليك من الإدارة فور تجهيزها.'
                      : 'New orders will appear here automatically when assigned.'),
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
      children: orders.map((order) {
        final distanceKm = _distanceToOrderKm(order);
        return DeliveryOrderCard(
          order: order,
          distanceKm: distanceKm,
        );
      }).toList(),
    );
  }
}

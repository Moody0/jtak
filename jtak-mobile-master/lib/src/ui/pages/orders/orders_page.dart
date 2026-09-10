import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app/home_navigation_provider.dart';
import '../../../core/controllers/order/order_provider.dart';
import '../../../core/enums/order_details_status_enum.dart';
import '../../../core/models/order/order_model.dart';
import '../../../core/services/authentication_service.dart';
import '../../../ui/pages/account/login_page.dart';
import '../../../ui/sections/bottom_navigation.dart';
import '../../widgets/clean_shimmer_skeletons.dart';
import 'order_widgets.dart';

/// ---------------------------------------------------------------------------
/// JTAK My Orders Page (طلباتي - Smooth Segmented TabBar & TabBarView)
/// ---------------------------------------------------------------------------

class OrderPage extends StatefulWidget {
  static const String routeName = '/OrderPage';

  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> with SingleTickerProviderStateMixin {
  late OrderProvider _provider;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadOrders() {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    provider.page = 0;
    provider.loadPagedData();
  }

  bool _isOrderActive(OrderModel order) {
    if (order.orderDetails == null || order.orderDetails!.isEmpty) return false;
    final status = order.orderDetails!.first.orderDetailStatus ?? OrderDetailsStatus.pending;
    return status != OrderDetailsStatus.delivered &&
        status != OrderDetailsStatus.customerCanceled &&
        status != OrderDetailsStatus.deliveryCanceled &&
        status != OrderDetailsStatus.merchantRejected;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthenticationService>(context);
    _provider = Provider.of<OrderProvider>(context);

    final allOrders = _provider.dataList;
    final activeOrders = allOrders.where(_isOrderActive).toList();
    final pastOrders = allOrders.where((o) => !_isOrderActive(o)).toList();
    final isLogin = authService.isLogin();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: BottomNavigation.height),
          child: !isLogin && allOrders.isEmpty
              ? _buildGuestView()
              : _provider.isBusy && allOrders.isEmpty
                  ? const OrdersListSkeleton(count: 4)
                  : Column(
                      children: [
                        // 1. Smooth Segmented TabBar
                        _buildSegmentedTabBar(activeOrders.length, pastOrders.length),

                        // 2. Gesture-Enabled TabBarView with Zero Flickering
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            physics: const ClampingScrollPhysics(),
                            children: [
                              _buildOrdersTab(activeOrders, isActiveTab: true),
                              _buildOrdersTab(pastOrders, isActiveTab: false),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Text(
        'طلباتي',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 18.5,
          fontWeight: FontWeight.w800,
          color: kCharcoalDark,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
      ),
    );
  }

  Widget _buildSegmentedTabBar(int activeCount, int pastCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          labelColor: kPrimaryOrange,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsFill.motorcycle, size: 16),
                  const SizedBox(width: 6),
                  Text('الطلبات الحالية ($activeCount)'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsFill.clockCounterClockwise, size: 16),
                  const SizedBox(width: 6),
                  Text('الطلبات السابقة ($pastCount)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab(List<OrderModel> orders, {required bool isActiveTab}) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _loadOrders(),
        color: kPrimaryOrange,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _buildEmptyOrdersState(isActiveTab: isActiveTab),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadOrders(),
      color: kPrimaryOrange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderSingleItem(order);
        },
      ),
    );
  }

  Widget _buildEmptyOrdersState({required bool isActiveTab}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD6C2), width: 1.5),
              ),
              child: Center(
                child: Icon(
                  isActiveTab ? PhosphorIconsFill.motorcycle : PhosphorIconsFill.clockCounterClockwise,
                  size: 40,
                  color: kPrimaryOrange,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isActiveTab ? 'لا توجد طلبات جارية حالياً' : 'سجل الطلبات فارغ',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isActiveTab
                  ? 'أي طلب جديد تقوم بإجرائه سيظهر هنا لتتبعه في الوقت الفعلي'
                  : 'اكتشف أفضل المطاعم والمتاجر واستمتع بوجباتك المفضلة!',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Provider.of<HomeNavigationProvider>(context, listen: false).changePage(0);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: kPrimaryOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(PhosphorIconsFill.shoppingBag, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'ابدأ التسوق الآن',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsFill.user,
                  size: 40,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'يرجى تسجيل الدخول',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'سجّل دخولك الآن لعرض ومتابعة كافة طلباتك الحالية والسابقة',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                final loggedIn = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
                if (loggedIn == true && mounted) {
                  _loadOrders();
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: kPrimaryOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(PhosphorIconsFill.user, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'تسجيل الدخول',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Provider.of<HomeNavigationProvider>(context, listen: false).changePage(0);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'تصفح المتاجر والمنتجات كزائر',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                    decoration: TextDecoration.underline,
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

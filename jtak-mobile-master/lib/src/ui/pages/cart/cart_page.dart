import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app/home_navigation_provider.dart';
import '../../../core/controllers/app_parameters_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/models/user/address_model.dart';
import '../../../core/models/order/order_details_model.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../widgets/top_app_bar_widget.dart';
import '../../widgets/header_circle_button.dart';
import '../account/login_page.dart';
import 'cart_widgets.dart';
import 'order_payment_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Cart & Checkout Review Page
///
/// Features matching reference design:
/// 1. Sleek AppBar with Back button, "سلة المشتريات", and Clear Cart action
/// 2. Delivery Address summary row with quick "تغيير" action
/// 3. Store Group Card with store name, ETA, and "+ إضافة أصناف أخرى" link
/// 4. Modern Food Item Cards with thumbnails, titles, prices, and [- count +] steppers
/// 5. Special Notes to Restaurant input card
/// 6. Clear Bill Breakdown Receipt Card (Subtotal, Delivery Fee, Grand Total)
/// 7. Sticky Bottom Checkout Bar with "المتابعة إلى الدفع" orange pill
/// 8. Beautiful Empty State with "ابدأ التسوق" CTA
/// ---------------------------------------------------------------------------

class CartPage extends StatefulWidget {
  static const String routeName = '/CartPage';

  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => locator<CartProvider>().loadCart());
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    return price.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تفريغ السلة',
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: kCharcoalDark,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف جميع الأصناف من السلة؟',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            color: const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              locator<CartProvider>().resetData();
            },
            child: Text(
              'حذف الكل',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final orderDetails = cartProvider.effectiveOrderDetails;
    final hasItems = orderDetails.isNotEmpty;

    final deliveryFee = cartProvider.deliveryFee;
    final subtotal = cartProvider.subtotal;
    final grandTotal = hasItems ? subtotal + deliveryFee : 0.0;
    final isLoading = cartProvider.isBusy && !hasItems;

    return Scaffold(
      backgroundColor: hasItems ? const Color(0xFFF8F9FA) : Colors.white,
      appBar: _buildAppBar(hasItems, cartProvider.totalQuantity),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: kPrimaryOrange,
              ),
            )
          : hasItems
              ? ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
                  children: [
                    // 1. Delivery Address Summary Bar
                    _buildAddressBar(context),

                    const SizedBox(height: 12),

                    // 2. Grouped Store Sections (supports multi-merchant orders seamlessly)
                    ..._buildGroupedStoreSections(orderDetails, cartProvider),

                    const SizedBox(height: 12),

                    // 4. Special Notes to Restaurant
                    _buildNotesCard(),

                    const SizedBox(height: 12),

                    // 5. Bill Breakdown Summary Card
                    _buildBillBreakdownCard(subtotal, deliveryFee, grandTotal),
                  ],
                )
              : _buildEmptyState(context),
      bottomNavigationBar: hasItems
          ? _buildBottomCheckoutBar(context, cartProvider, subtotal, grandTotal)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(bool hasItems, int totalQuantity) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1.5,
      shadowColor: const Color(0x10000000),
      leading: Center(
        child: HeaderCircleButton.back(
          onTap: () => Navigator.pop(context),
        ),
      ),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'سلة المشتريات',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hasItems && totalQuantity > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$totalQuantity',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kPrimaryOrange,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (hasItems)
          IconButton(
            onPressed: _showClearCartDialog,
            icon: const Icon(
              PhosphorIconsRegular.trash,
              color: Color(0xFFEF4444),
              size: 22,
            ),
            tooltip: 'تفريغ السلة',
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAddressBar(BuildContext context) {
    final mainAddressService = locator<AppParametersProvider>().mainAddressService;
    AddressModel currentAddress = mainAddressService.mainAddress;
    final displayAddress = currentAddress.title?.isNotEmpty == true
        ? currentAddress.title!
        : (currentAddress.fullAddress?.isNotEmpty == true ? currentAddress.fullAddress! : 'موقعك الحالي');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                PhosphorIconsFill.mapPin,
                color: kPrimaryOrange,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التوصيل إلى',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  displayAddress,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: kCharcoalDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showJtakAddressBottomSheet(context),
            behavior: HitTestBehavior.opaque,
            child: Text(
              'تغيير',
              style: GoogleFonts.ibmPlexSansArabic(
                color: kPrimaryOrange,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedStoreSections(
      List<OrderDetailsModel> details, CartProvider cartProvider) {
    final Map<int, List<OrderDetailsModel>> groups = {};
    for (final item in details) {
      final mid = item.merchantId ?? 1;
      groups.putIfAbsent(mid, () => []).add(item);
    }

    final List<Widget> widgets = [];
    final isMulti = groups.length > 1;

    if (isMulti) {
      widgets.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Center(
                  child: Icon(
                    PhosphorIconsFill.shoppingBag,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب مجمّع من ${groups.length} متاجر',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E40AF),
                      ),
                    ),
                    Text(
                      'سيتم جمع طلباتك وتوصيلها جميعاً في مسار واحد',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    for (final entry in groups.entries) {
      final storeItems = entry.value;
      final storeName = storeItems.first.merchantTitle ?? 'المتجر';
      widgets.add(_buildStoreHeader(entry.key, storeName, cartProvider));
      widgets.add(const SizedBox(height: 8));
      for (final item in storeItems) {
        widgets.add(CartSingleItem(item));
      }
      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  Widget _buildStoreHeader(
      int merchantId, String storeName, CartProvider cartProvider) {
    final int storeMinOrder = cartProvider.getMinOrderForMerchant(merchantId);
    final double storeSubtotal = cartProvider.getSubtotalForMerchant(merchantId);
    final bool hasMinOrder = storeMinOrder > 0;
    final bool reachedMin = !hasMinOrder || storeSubtotal >= storeMinOrder;
    final double remaining =
        (storeMinOrder - storeSubtotal).clamp(0.0, double.infinity);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasMinOrder && !reachedMin
              ? const Color(0xFFFDE68A)
              : const Color(0xFFE5E7EB),
          width: hasMinOrder && !reachedMin ? 1.3 : 1.1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Center(
              child: Icon(
                PhosphorIconsFill.storefront,
                color: kPrimaryOrange,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        storeName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kCharcoalDark,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasMinOrder) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: reachedMin
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: reachedMin
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFDE68A),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          reachedMin
                              ? 'مستوفي الحد'
                              : 'متبقي ${_formatPrice(remaining)} ل.س',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: reachedMin
                                ? const Color(0xFF065F46)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(PhosphorIconsRegular.clock,
                        size: 13, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text(
                      'توصيل خلال 15-25 دقيقة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF6B7280),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+ إضافة المزيد',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsRegular.pencilSimple, size: 18, color: kPrimaryOrange),
              const SizedBox(width: 8),
              Text(
                'ملاحظات خاصة للطلب',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              color: kCharcoalDark,
            ),
            decoration: InputDecoration(
              hintText: 'مثال: بدون بصل، زيادة صوص الثوم، شوك وملاعق...',
              hintStyle: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryOrange, width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillBreakdownCard(double subtotal, double deliveryFee, double grandTotal) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص الدفع',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),

          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مجموع الوجبات',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_formatPrice(subtotal)} ل.س',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Delivery Fee
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'رسوم التوصيل',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_formatPrice(deliveryFee)} ل.س',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الإجمالي النهائي',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${_formatPrice(grandTotal)} ل.س',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kPrimaryOrange,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckoutBar(BuildContext context,
      CartProvider cartProvider, double subtotal, double grandTotal) {
    final bool reachesMinOrder = cartProvider.reachesAllMinOrders;
    final violation = cartProvider.primaryMinOrderViolation;
    final int minOrder =
        violation?.minOrder ?? cartProvider.currentMerchantMinOrder;
    final double remaining = violation?.remaining ??
        (minOrder - subtotal).clamp(0.0, double.infinity);
    final String storeLabel = (violation != null && violation.merchantName.isNotEmpty)
        ? ' من «${violation.merchantName}»'
        : '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimum Order Notice Bar (Shown when any merchant hasn't reached minimum)
          if (!reachesMinOrder)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBEB), // Gentle Warm Amber
                border: Border(
                  bottom: BorderSide(color: Color(0xFFFDE68A), width: 0.9),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsFill.warningCircle,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الحد الأدنى للطلب$storeLabel هو ${_formatPrice(minOrder.toDouble())} ل.س • متبقي ${_formatPrice(remaining)} ل.س للمتابعة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF92400E),
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Total Amount on Right in RTL
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المجموع النهائي',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_formatPrice(grandTotal)} ل.س',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: reachesMinOrder
                            ? kPrimaryOrange
                            : const Color(0xFF9CA3AF),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                // Orange Checkout Button on Left in RTL (Disabled if minimum pay not met)
                GestureDetector(
                  onTap: reachesMinOrder
                      ? () async {
                          HapticFeedback.mediumImpact();
                          final authService = locator<AuthenticationService>();
                          if (!authService.isLogin()) {
                            await authService.getAuthorizationData();
                          }
                          if (authService.isLogin()) {
                            if (!context.mounted) return;
                            Navigator.pushNamed(
                                context, OrderPaymentPage.routeName);
                          } else {
                            if (!context.mounted) return;
                            final loggedIn = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LoginPage()),
                            );
                            if (loggedIn == true && context.mounted) {
                              await authService.getAuthorizationData();
                              if (!context.mounted) return;
                              await Provider.of<CartProvider>(context,
                                      listen: false)
                                  .cartInfo
                                  .initData();
                              if (!context.mounted) return;
                              Navigator.pushNamed(
                                  context, OrderPaymentPage.routeName);
                            }
                          }
                        }
                      : () {
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF1F2937),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              content: Row(
                                children: [
                                  const Icon(PhosphorIconsFill.warningCircle,
                                      color: Color(0xFFFBBF24), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'الحد الأدنى للطلب$storeLabel هو ${_formatPrice(minOrder.toDouble())} ل.س (متبقي ${_formatPrice(remaining)} ل.س)',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: reachesMinOrder
                          ? kPrimaryOrange
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'المتابعة إلى الدفع',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: reachesMinOrder
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          PhosphorIconsRegular.caretRight,
                          color: reachesMinOrder
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty Cart State
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3EB),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                PhosphorIconsThin.shoppingBag,
                size: 56,
                color: kPrimaryOrange,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'سلة المشتريات فارغة!',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 20.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لم تقم بإضافة أي منتجات أو وجبات بعد.',
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFF6B7280),
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () {
              Navigator.popUntil(context, (route) => route.isFirst);
              Provider.of<HomeNavigationProvider>(context, listen: false)
                  .changePage(0);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: kPrimaryOrange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'ابدأ التسوق الآن',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

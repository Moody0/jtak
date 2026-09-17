import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../main_imports.dart';
import '../../../config/constants/app_constant.dart';
import '../../../utils/utilities/lunch_url.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/app_parameters_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/controllers/order/order_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../../core/enums/order_details_status_enum.dart';
import '../../../core/models/order/order_details_model.dart';
import '../../../core/models/order/order_model.dart';
import '../../../core/services/locator.dart';
import '../../../core/services/route_directions_service.dart';
import '../../../ui/sections/rate_order.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../pages/cart/cart_page.dart';
import '../../widgets/header_circle_button.dart';
import 'order_widgets.dart';
import 'custom_map_markers.dart';
import 'live_tracking_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Order Tracking & Details Page
/// Fully Dynamic • Real-Time Backend Sync • Real Google Maps • Flat Clean UI
/// ---------------------------------------------------------------------------

class OrderDetailsPage extends StatefulWidget {
  static const String routeName = '/OrderDetailsPage';
  final OrderModel order;

  const OrderDetailsPage(this.order, {super.key});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late OrderProvider provider;
  bool _isItemsExpanded = true;
  Timer? _liveSyncTimer;
  GoogleMapController? _previewMapController;

  // Custom Markers & Preview Road Route
  BitmapDescriptor? _courierMarker;
  BitmapDescriptor? _customerMarker;
  List<LatLng> _previewRoadPoints = [];
  LatLng? _lastPreviewDriverPos;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final prov = Provider.of<OrderProvider>(context, listen: false);
        prov.setOrderObject(widget.order);
        final initialStatus = prov.getOrderStatus(widget.order);
        if (initialStatus == OrderDetailsStatus.merchantRejected ||
            initialStatus == OrderDetailsStatus.customerCanceled ||
            initialStatus == OrderDetailsStatus.deliveryCanceled) {
          locator<CartProvider>().clearCart();
        }
        // Immediately fetch fresh order details & OTP from backend without 5-second delay
        if (widget.order.id != null) {
          prov.loadOrder(widget.order.id!, silent: true);
        }
        _startLiveBackendSync();
      }
    });
  }

  void _loadCustomMarkers() async {
    final courier = await CustomMapMarkers.getCourierMarker();
    final customer = await CustomMapMarkers.getCustomerMarker();
    if (mounted) {
      setState(() {
        _courierMarker = courier;
        _customerMarker = customer;
      });
    }
  }

  void _updatePreviewRoute(LatLng driverPos, LatLng clientPos) async {
    if (_lastPreviewDriverPos != null) {
      final double d = (driverPos.latitude - _lastPreviewDriverPos!.latitude).abs() +
          (driverPos.longitude - _lastPreviewDriverPos!.longitude).abs();
      if (d < 0.0002 && _previewRoadPoints.isNotEmpty) return;
    }
    _lastPreviewDriverPos = driverPos;
    try {
      final route = await RouteDirectionsService.fetchRoadRoute(
        origin: driverPos,
        destination: clientPos,
      );
      if (mounted && route.points.isNotEmpty) {
        setState(() {
          _previewRoadPoints = route.points;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    _previewMapController?.dispose();
    super.dispose();
  }

  /// Periodic live synchronization with the backend / admin / delivery sides
  void _startLiveBackendSync() {
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final p = Provider.of<OrderProvider>(context, listen: false);
      final current = p.order ?? widget.order;
      final status = p.getOrderStatus(current);

      final bool isActive = status != OrderDetailsStatus.delivered &&
          status != OrderDetailsStatus.customerCanceled &&
          status != OrderDetailsStatus.deliveryCanceled &&
          status != OrderDetailsStatus.merchantRejected;

      if (isActive && current.id != null) {
        p.loadOrder(current.id!, silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<OrderProvider>(context);
    final currentOrder = provider.order ?? widget.order;
    final status = provider.getOrderStatus(currentOrder);

    // If order was rejected by merchant, guarantee cart vanishes completely
    if (status == OrderDetailsStatus.merchantRejected) {
      final cart = locator<CartProvider>();
      if (cart.totalQuantity > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          cart.clearCart();
        });
      }
    }

    // Conditional visibility: Driver & Live Location appear ONLY during Shipping
    final bool isShippingState = (status == OrderDetailsStatus.shipping);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(),
        body: SafeArea(
          child: FullScreenLoading(
            inAsyncCall: provider.isBusy,
            child: RefreshIndicator(
              onRefresh: () async {
                if (currentOrder.id != null) {
                  await provider.loadOrder(currentOrder.id!);
                }
              },
              color: kPrimaryOrange,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics()),
                children: [
                  // 1. Order Tracking Status Card (4-Stage Progress Timeline)
                  _buildTrackingStatusCard(currentOrder, status),
                  const SizedBox(height: 14),

                  // 2. Delivery Confirmation PIN Code Card (رمز تأكيد الاستلام)
                  if (currentOrder.deliveryOtp != null &&
                      currentOrder.deliveryOtp!.trim().isNotEmpty &&
                      status != OrderDetailsStatus.customerCanceled &&
                      status != OrderDetailsStatus.deliveryCanceled &&
                      status != OrderDetailsStatus.merchantRejected) ...[
                    _buildDeliveryPinCard(currentOrder, status),
                    const SizedBox(height: 14),
                  ],

                  // 3. Delivery Driver Card (Appears ONLY when order is in Shipping state)
                  if (isShippingState) ...[
                    _buildDeliveryDriverCard(currentOrder),
                    const SizedBox(height: 14),
                  ],

                  // 3. Live Google Map Tracking Card (Appears ONLY when order is in Shipping state)
                  if (isShippingState) ...[
                    _buildLiveMapTrackingCard(currentOrder),
                    const SizedBox(height: 14),
                  ],

                  // 4. Order Items Card (طلبي - Real products & prices from backend)
                  _buildOrderItemsCard(currentOrder),
                  const SizedBox(height: 14),

                  // 5. Address & Order Info Card (عنوان التوصيل وتفاصيل الفاتورة)
                  _buildDeliveryDetailsCard(currentOrder),
                  const SizedBox(height: 18),

                  // 6. Contextual Action Buttons (إلغاء الطلب / تقييم / إعادة الطلب)
                  _buildBottomActions(currentOrder, status),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Top AppBar (تتبع الطلب + زر المساعدة)
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leading: Center(
        child: HeaderCircleButton.back(
          onTap: () => Navigator.pop(context),
        ),
      ),
      title: Text(
        'تتبع الطلب',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 18.5,
          fontWeight: FontWeight.w800,
          color: kCharcoalDark,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 16),
          child: Center(
            child: GestureDetector(
              onTap: () => _showHelpBottomSheet(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.info,
                      size: 15,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'المساعدة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Order Tracking Status Card (Timeline Progress matching Image 1)
  // ---------------------------------------------------------------------------
  Widget _buildTrackingStatusCard(OrderModel order, OrderDetailsStatus status) {
    final String merchantName = _resolveMerchantName(order);

    int stageIndex = 0;
    String mainTitle = 'تم استلام طلبك';
    String subtitle = 'طلبك قيد المراجعة وبانتظار موافقة المتجر';
    bool isCanceled = false;

    switch (status) {
      case OrderDetailsStatus.pending:
      case OrderDetailsStatus.customerPending:
        stageIndex = 0;
        mainTitle = 'تم استلام طلبك';
        subtitle = 'طلبك قيد المراجعة وبانتظار موافقة $merchantName';
        break;

      case OrderDetailsStatus.merchantAccepted:
        stageIndex = 1;
        mainTitle = 'جاري تحضير طلبك';
        subtitle = 'متجر $merchantName يحضر طلبك الآن في المطبخ';
        break;

      case OrderDetailsStatus.readyForPickup:
        stageIndex = 1;
        mainTitle = 'طلبك جاهز للاستلام';
        subtitle = 'أنهى $merchantName تجهيز الطلب وبانتظار تعيين مندوب التوصيل';
        break;

      case OrderDetailsStatus.shipping:
        stageIndex = 2;
        mainTitle = 'طلبك في الطريق';
        subtitle =
            '${order.deliveryUser ?? 'مندوب التوصيل'} استلم طلبك وهو في الطريق إليك';
        break;

      case OrderDetailsStatus.delivered:
        stageIndex = 3;
        mainTitle = 'تم توصيل طلبك';
        subtitle = 'تم تسليم طلبك بنجاح. نتمنى لك تجربة ممتعة!';
        break;

      case OrderDetailsStatus.merchantRejected:
        stageIndex = -1;
        isCanceled = true;
        mainTitle = 'نعتذر، تعذر قبول الطلب من قِبل المتجر';
        // order.warning is a generic backend flag reused for unrelated cart
        // checks (min order, store hours); on a rejected order it always
        // resolves to a fixed placeholder ("يرجى مراجعة المواد") that masks
        // the actual reason the merchant typed. The real reason lives in
        // order.notes (and mirrored per-item in orderDetails[].warning), so
        // those take priority here and order.warning is never used as the
        // displayed reason.
        final String reason = order.notes ??
            (order.orderDetails?.firstWhere(
                (d) => d.warning != null && d.warning!.trim().isNotEmpty,
                orElse: () => OrderDetailsModel()).warning) ??
            '';
        if (reason.trim().isNotEmpty) {
          subtitle =
              'اعتذر $merchantName عن قبول طلبك للسبب التالي:\n«$reason»\n\nتم تفريغ سلة المشتريات تلقائياً لتتمكن من اختيار وجبة أخرى أو متجر آخر.';
        } else {
          subtitle =
              'نعتذر منك، اعتذر $merchantName عن قبول طلبك في الوقت الحالي.\nتم تفريغ سلة المشتريات تلقائياً لتتمكن من اختيار وجبة أخرى أو متجر آخر.';
        }
        break;

      case OrderDetailsStatus.customerCanceled:
      case OrderDetailsStatus.deliveryCanceled:
        stageIndex = -1;
        isCanceled = true;
        mainTitle = 'تم إلغاء الطلب';
        subtitle =
            'تم إلغاء هذا الطلب بناءً على رغبتك أو تعذر التجهيز من المتجر';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Top Status Title
          Text(
            mainTitle,
            textAlign: TextAlign.start,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: isCanceled ? const Color(0xFFDC2626) : kCharcoalDark,
            ),
          ),

          const SizedBox(height: 18),

          // B. 4-Stage Horizontal Progress Timeline (RTL Flow: Right -> Left)
          if (!isCanceled)
            _buildTimelineProgressRow(stageIndex)
          else if (status == OrderDetailsStatus.merchantRejected)
            _buildRejectedTimelineBadge()
          else
            _buildCanceledTimelineBadge(),

          const SizedBox(height: 16),

          // C. Dynamic Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.start,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineProgressRow(int activeStageIndex) {
    return Row(
      children: [
        // Node 0 (Rightmost in RTL): تم استلام طلبك (Receipt)
        _buildTimelineNode(
          icon: PhosphorIconsFill.receipt,
          isActive: activeStageIndex >= 0,
        ),

        // Line 0-1
        _buildTimelineConnector(isActive: activeStageIndex >= 1),

        // Node 1: جاري التحضير (Storefront)
        _buildTimelineNode(
          icon: PhosphorIconsFill.storefront,
          isActive: activeStageIndex >= 1,
        ),

        // Line 1-2
        _buildTimelineConnector(isActive: activeStageIndex >= 2),

        // Node 2: في الطريق (Delivery Car)
        _buildTimelineNode(
          icon: PhosphorIconsFill.car,
          isActive: activeStageIndex >= 2,
        ),

        // Line 2-3
        _buildTimelineConnector(isActive: activeStageIndex >= 3),

        // Node 3 (Leftmost in RTL): تم التوصيل (Flipped Checkmark)
        _buildTimelineNode(
          icon: PhosphorIconsBold.check,
          isActive: activeStageIndex >= 3,
          isDelivered: true,
        ),
      ],
    );
  }

  Widget _buildTimelineNode({
    required IconData icon,
    required bool isActive,
    bool isDelivered = false,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? kPrimaryOrange : const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? kPrimaryOrange : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Center(
        child: isDelivered
            ? Transform.flip(
                flipX: true,
                child: Icon(
                  icon,
                  size: 19,
                  color: isActive ? Colors.white : const Color(0xFF94A3B8),
                ),
              )
            : Icon(
                icon,
                size: 19,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
      ),
    );
  }

  Widget _buildTimelineConnector({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 4.0,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? kPrimaryOrange : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildCanceledTimelineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(PhosphorIconsFill.xCircle,
              color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          Text(
            'تم إلغاء الطلب',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedTimelineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(PhosphorIconsFill.xCircle,
              color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          Text(
            'اعتذر المتجر عن قبول الطلب',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Delivery Confirmation PIN Card (رمز تأكيد الاستلام)
  // ---------------------------------------------------------------------------
  Widget _buildDeliveryPinCard(OrderModel order, OrderDetailsStatus status) {
    final String cleanOtp = (order.deliveryOtp ?? '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    final bool isDelivered = status == OrderDetailsStatus.delivered;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDelivered ? const Color(0xFFF8FAFC) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDelivered ? const Color(0xFFE2E8F0) : const Color(0xFFFFEDD5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDelivered ? const Color(0xFFE2E8F0) : const Color(0xFFFFF0E8),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isDelivered ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.shieldCheck,
                    size: 22,
                    color: isDelivered ? const Color(0xFF64748B) : kPrimaryOrange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رمز تأكيد الاستلام (PIN)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDelivered ? const Color(0xFF475569) : kCharcoalDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDelivered
                          ? 'تم التحقق من الرمز وتسليم الطلب بنجاح'
                          : 'أعطِ هذا الرمز لمندوب التوصيل عند استلام طلبك',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cleanOtp.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. PIN Digit Boxes in strict LTR
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: cleanOtp.split('').map((digit) {
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 38,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDelivered ? const Color(0xFFCBD5E1) : const Color(0xFFFFB280),
                            width: 1.4,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            digit,
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDelivered ? const Color(0xFF64748B) : kPrimaryOrange,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // 2. Copy Button
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Clipboard.setData(ClipboardData(text: cleanOtp));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(PhosphorIconsFill.checkCircle, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'تم نسخ رمز التأكيد: \u200E$cleanOtp\u200E',
                              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: kCharcoalDark,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDelivered ? const Color(0xFFCBD5E1) : const Color(0xFFFFD8C2),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.copy,
                          size: 15,
                          color: isDelivered ? const Color(0xFF64748B) : kPrimaryOrange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'نسخ الرمز',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDelivered ? const Color(0xFF64748B) : kPrimaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Delivery Driver Card (مندوب التوصيل - Appears only in Shipping)
  // ---------------------------------------------------------------------------
  Widget _buildDeliveryDriverCard(OrderModel order) {
    final driverPos = _resolveDriverCoordinates(order);
    final bool isLive = _isDriverLocationFresh(order);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        children: [
          // A. Courier Info Row
          Row(
            children: [
              // Avatar with subtle shadow and border
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFF0E8),
                  border: Border.all(
                      color: const Color(0xFFFFD6C2), width: 1.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/person.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(PhosphorIconsFill.user,
                          color: kPrimaryOrange, size: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Courier Name & Title (Expanded to avoid any overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مندوب التوصيل',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\u2068${order.deliveryUser ?? 'مندوب التوصيل'}\u2069',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Live Status Badge (Only shown when live GPS location is active)
              if (driverPos != null && isLive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    'التتبع مباشر',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // B. Contact Delivery - PHONE CALL ONLY (Prominent single call action)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _callDriver(context, order),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF7ED),
                foregroundColor: kPrimaryOrange,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFFFEDD5), width: 1.2),
                ),
              ),
              icon: const Icon(PhosphorIconsFill.phoneCall,
                  size: 18, color: kPrimaryOrange),
              label: Text(
                'اتصال بمندوب التوصيل',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Live Map Tracking Card with Real Google Maps API Integration
  // ---------------------------------------------------------------------------
  Widget _buildLiveMapTrackingCard(OrderModel order) {
    final clientPos = _resolveClientCoordinates(order);
    final driverPos = _resolveDriverCoordinates(order);

    if (driverPos != null) {
      _updatePreviewRoute(driverPos, clientPos);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Header Row: Right = Title, Left = "فتح <"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsBold.arrowsClockwise,
                      color: Color(0xFF475569),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'تتبع الموقع المباشر لطلبك',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kCharcoalDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _openFullMap(context, order),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'فتح',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: kPrimaryOrange,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: kPrimaryOrange,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // B. Real Google Map Preview with Road Following Polyline
          GestureDetector(
            onTap: () => _openFullMap(context, order),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 165,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  children: [
                    GoogleMap(
                      mapType: MapType.normal,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      tiltGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      initialCameraPosition: CameraPosition(
                        target: driverPos ?? clientPos,
                        zoom: 14.2,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('destination'),
                          position: clientPos,
                          anchor: CustomMapMarkers.customerAnchor,
                          infoWindow:
                              const InfoWindow(title: 'عنوان التوصيل (موقعك)'),
                          icon: _customerMarker ??
                              BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueRed),
                        ),
                        if (driverPos != null)
                          Marker(
                            markerId: const MarkerId('driver'),
                            position: driverPos,
                            anchor: CustomMapMarkers.courierAnchor,
                            infoWindow: InfoWindow(
                                title: order.deliveryUser ?? 'مندوب التوصيل'),
                            icon: _courierMarker ??
                                BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueOrange),
                          ),
                      },
                      polylines: {
                        if (driverPos != null) ...[
                          Polyline(
                            polylineId: const PolylineId('route_preview_border'),
                            points: _previewRoadPoints.isNotEmpty
                                ? _previewRoadPoints
                                : [driverPos, clientPos],
                            color: Colors.white,
                            width: 6,
                          ),
                          Polyline(
                            polylineId: const PolylineId('route_preview'),
                            points: _previewRoadPoints.isNotEmpty
                                ? _previewRoadPoints
                                : [driverPos, clientPos],
                            color: kPrimaryOrange,
                            width: 4,
                          ),
                        ],
                      },
                      onMapCreated: (controller) =>
                          _previewMapController = controller,
                      onTap: (_) => _openFullMap(context, order),
                    ),

                    // Tap Overlay to ensure tapping opens the full interactive map
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openFullMap(context, order),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Action Button to open the separate dedicated Live Tracking Page
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openFullMap(context, order),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(PhosphorIconsFill.navigationArrow,
                  size: 18, color: Colors.white),
              label: Text(
                'عرض التتبع المباشر على الخريطة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Order Items Card (طلبي - 100% Real Backend Data)
  // ---------------------------------------------------------------------------
  Widget _buildOrderItemsCard(OrderModel order) {
    final details = order.orderDetails ?? [];
    final double computedTotal = order.price ??
        details.fold<double>(0.0, (sum, item) {
          final p = (item.singleFinalPrice ?? item.singlePrice ?? 0);
          final q = (item.quantity ?? 1);
          return sum + (p * q);
        });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Header Row: Right = "طلبي", Left = "إخفاء ^ / عرض v"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'طلبي',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: kCharcoalDark,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isItemsExpanded = !_isItemsExpanded;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isItemsExpanded ? 'إخفاء' : 'عرض',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryOrange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isItemsExpanded
                          ? PhosphorIconsBold.caretUp
                          : PhosphorIconsBold.caretDown,
                      size: 14,
                      color: kPrimaryOrange,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // B. Collapsible Items List
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _isItemsExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const SizedBox(height: 14),
                if (details.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'لا توجد عناصر مسجلة في هذا الطلب',
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13, color: const Color(0xFF94A3B8)),
                    ),
                  )
                else
                  ...details.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Column(
                      children: [
                        _buildOrderItemRow(item),
                        if (index < details.length - 1)
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      ],
                    );
                  }),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),

                // Subtotal Row: Right = "المجموع الجزئي", Left = Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المجموع الجزئي',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    Text(
                      '${OrderSingleItem.formatPrice(computedTotal)} $kMainCurrencySymbol',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: kCharcoalDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(OrderDetailsModel item) {
    final double itemPrice =
        (item.singleFinalPrice ?? item.singlePrice ?? 0) * (item.quantity ?? 1);
    final mockItem = MockCatalogData.getMenuItemById(item.productId ?? 0);
    final raw = item.productImage;
    final img = (raw != null && raw.trim().isNotEmpty && raw != 'null')
        ? raw.split(',').first.trim()
        : (mockItem?.imageUrl ?? '');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Right in RTL: Image Thumbnail
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: ImageView(
              img,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Middle in RTL: Title & Add-ons Dialog Trigger
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productTitle ?? mockItem?.title ?? 'وجبة خاصة',
                textAlign: TextAlign.start,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
              const SizedBox(height: 3),
              GestureDetector(
                onTap: () => _showAddonsDialog(context, item),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'عرض الإضافات',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      PhosphorIconsBold.caretDown,
                      size: 11,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Left in RTL: Price
        Text(
          '${OrderSingleItem.formatPrice(itemPrice)} $kMainCurrencySymbol',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: kCharcoalDark,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Address & Details Card
  // ---------------------------------------------------------------------------
  Widget _buildDeliveryDetailsCard(OrderModel order) {
    final String address = order.address ??
        locator<AppParametersProvider>()
            .mainAddressService
            .mainAddress
            .fullAddress ??
        'دمشق، سوريا';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        children: [
          // Address Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(PhosphorIconsFill.mapPin,
                      color: kPrimaryOrange, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عنوان التوصيل',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kCharcoalDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Order ID & Timestamp Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'رقم الطلب: #${order.id ?? ""}',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
              Text(
                _formatOrderDate(order.purchaseDate ?? order.createdDate),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Contextual Actions (إلغاء الطلب / تقييم / إعادة الطلب)
  // ---------------------------------------------------------------------------
  Widget _buildBottomActions(OrderModel order, OrderDetailsStatus status) {
    if (status == OrderDetailsStatus.delivered) {
      return Row(
        children: [
          // Rate Order Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                showDialog(
                    context: context, builder: (context) => RateOrder(order));
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsFill.star,
                        size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Text(
                      'تقييم الطلب',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Reorder Button (Adds all items to CartProvider)
          Expanded(
            child: GestureDetector(
              onTap: () => _reorderAllItems(order),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: kPrimaryOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsRegular.arrowsClockwise,
                        size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'إعادة الطلب',
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
          ),
        ],
      );
    } else if (status == OrderDetailsStatus.pending ||
        status == OrderDetailsStatus.customerPending ||
        status == OrderDetailsStatus.merchantAccepted) {
      return GestureDetector(
        onTap: () => _confirmCancelOrder(order),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECACA), width: 1.0),
          ),
          child: Center(
            child: Text(
              'إلغاء الطلب',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        ),
      );
    } else if (status == OrderDetailsStatus.merchantRejected) {
      return GestureDetector(
        onTap: () {
          locator<CartProvider>().clearCart();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: kPrimaryOrange,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kPrimaryOrange.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsRegular.storefront,
                  color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                'تصفح المطاعم والمتاجر الأخرى',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------------
  // Helper Coordinates & Calculations
  // ---------------------------------------------------------------------------
  LatLng _resolveClientCoordinates(OrderModel order) {
    if (order.lat != null &&
        order.lng != null &&
        order.lat != 0 &&
        order.lng != 0) {
      return LatLng(order.lat!.toDouble(), order.lng!.toDouble());
    }
    final mainAddress =
        locator<AppParametersProvider>().mainAddressService.mainAddress;
    if (mainAddress.lat != null &&
        mainAddress.lng != null &&
        mainAddress.lat != 0 &&
        mainAddress.lng != 0) {
      return LatLng(mainAddress.lat!.toDouble(), mainAddress.lng!.toDouble());
    }
    return const LatLng(33.5138, 36.2765); // Damascus center
  }

  LatLng? _resolveDriverCoordinates(OrderModel order) {
    if (order.deliveryLat != null &&
        order.deliveryLng != null &&
        order.deliveryLat != 0 &&
        order.deliveryLng != 0) {
      return LatLng(order.deliveryLat!, order.deliveryLng!);
    }
    return null;
  }

  bool _isDriverLocationFresh(OrderModel order) {
    final raw = order.deliveryLocationUpdatedAt;
    if (raw == null || raw.isEmpty) return false;
    try {
      final updatedAt = DateTime.parse(raw);
      final diff = DateTime.now().difference(updatedAt);
      return diff.inMinutes < 3 && !diff.isNegative;
    } catch (_) {
      return false;
    }
  }

  String _resolveMerchantName(OrderModel order) {
    if (order.orderDetails != null && order.orderDetails!.isNotEmpty) {
      final name = order.orderDetails!.first.merchantTitle;
      if (name != null && name.isNotEmpty) return name.split(' - ').first;
    }
    if (order.description != null && order.description!.isNotEmpty) {
      return order.description!.split(' - ').first;
    }
    return 'المتجر';
  }

  String _formatOrderDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'اليوم';
    try {
      final date = DateTime.parse(rawDate);
      return '${date.day}/${date.month}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _reorderAllItems(OrderModel order) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final details = order.orderDetails ?? [];
    if (details.isEmpty) {
      if (mounted) {
        context.showSnakBar('لا توجد أصناف قابلة للإعادة في هذا الطلب');
      }
      return;
    }

    for (var item in details) {
      if (item.productId != null) {
        final price = item.singleFinalPrice ?? item.singlePrice ?? 0;
        final qty = item.quantity ?? 1;
        final mId = item.merchantId ?? 1;
        await cart.setToCart(item.productId!, mId, price, qty);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تمت إضافة جميع الأصناف إلى السلة بنجاح 🛒',
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
        ),
        action: SnackBarAction(
          label: 'عرض السلة',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, CartPage.routeName);
          },
        ),
        backgroundColor: kPrimaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _callDriver(BuildContext context, [OrderModel? order]) async {
    final phone = order?.deliveryUserPhone?.trim();
    final targetPhone =
        (phone != null && phone.isNotEmpty) ? phone : kSupportPhoneNumber;
    await LunchUrl.makeCall(targetPhone, context: context);
  }

  void _openFullMap(BuildContext context, OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => LiveTrackingPage(order: order),
      ),
    );
  }

  void _showAddonsDialog(BuildContext context, OrderDetailsModel item) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            item.productTitle ?? 'تفاصيل وإضافات الوجبة',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kCharcoalDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• الكمية المطلوبة: ${item.quantity ?? 1}',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              Text(
                '• سعر القطعة: ${OrderSingleItem.formatPrice(item.singleFinalPrice ?? item.singlePrice ?? 0)} $kMainCurrencySymbol',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5, color: const Color(0xFF475569)),
              ),
              if (item.warning != null && item.warning!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '• ملاحظات: ${item.warning}',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5, color: const Color(0xFF475569)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إغلاق',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w800, color: kPrimaryOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpBottomSheet(BuildContext context, [OrderModel? order]) {
    final currentOrder = order ??
        Provider.of<OrderProvider>(context, listen: false).order ??
        widget.order;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'مركز مساعدة ودعم الطلب',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'فريق دعم جيتك متواجد على مدار الساعة لمساعدتك في أي استفسار أو مشكلة تواجه طلبك.',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13.5,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                onTap: () async {
                  Navigator.pop(ctx);
                  final orderNum =
                      currentOrder.id != null ? '#${currentOrder.id}' : '';
                  final msg = orderNum.isNotEmpty
                      ? 'مرحباً خدمة عملاء جيتك، أحتاج مساعدة بخصوص طلبي رقم $orderNum'
                      : 'مرحباً خدمة عملاء جيتك، أحتاج مساعدة بخصوص طلبي';
                  await LunchUrl.openWhatsApp(
                    phone: kSupportWhatsAppNumber,
                    message: msg,
                    context: context,
                  );
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(PhosphorIconsFill.whatsappLogo,
                      color: Color(0xFF059669)),
                ),
                title: Text(
                  'محادثة الدعم عبر الواتساب',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                trailing: const Icon(PhosphorIconsBold.caretLeft, size: 14),
              ),
              ListTile(
                onTap: () async {
                  Navigator.pop(ctx);
                  await LunchUrl.makeCall(kSupportPhoneNumber, context: context);
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(PhosphorIconsFill.phoneCall,
                      color: kPrimaryOrange),
                ),
                title: Text(
                  'الاتصال بالخط الساخن المباشر',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                trailing: const Icon(PhosphorIconsBold.caretLeft, size: 14),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCancelOrder(OrderModel order) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تأكيد إلغاء الطلب',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: kCharcoalDark,
            ),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              color: const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'تراجع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await provider.cancelOrder();
                if (!mounted) return;
                context.showSnakBar('تم إلغاء الطلب بنجاح');
              },
              child: Text(
                'نعم، إلغاء',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

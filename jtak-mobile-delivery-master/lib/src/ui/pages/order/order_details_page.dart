import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/order_provider.dart';
import '../../../core/enums/order_details_status_enum.dart';
import '../../../core/models/order_model.dart';
import '../../../ui/widgets/app_widgets.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/utilities/global_var.dart';
import 'order_widgets.dart';

class OrderDetailsPage extends StatefulWidget {
  static const String routeName = '/OrderDetailsPage';
  final OrderModel order;
  const OrderDetailsPage(this.order, {Key? key}) : super(key: key);

  @override
  _OrderDetailsPageState createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<OrderProvider>(context, listen: false);
    provider.setOrderObject(widget.order);
    if (widget.order.id != null) {
      provider.silentSyncOrder(widget.order.id!);
    }

    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      final prov = Provider.of<OrderProvider>(context, listen: false);
      if (widget.order.id != null && !prov.isBusy && !prov.isActionInFlight(widget.order.id!)) {
        prov.silentSyncOrder(widget.order.id!);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _confirmCancelOrder(BuildContext context, OrderModel order) {
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: kRed, size: 26),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'إلغاء مهمة التوصيل' : 'Cancel Delivery Task',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: isDark ? Colors.white : kCharcoalDark,
              ),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من رغبتك في إلغاء توصيل الطلب #${order.id}؟ سيتم إخطار الإدارة والتاجر وإلغاء المهمة.'
              : 'Are you sure you want to cancel delivery for order #${order.id}? Management and merchants will be notified.',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13.5,
            color: isDark ? const Color(0xFFCBD5E1) : kCharcoalMuted,
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              isArabic ? 'تراجع' : 'Back',
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isArabic ? 'تأكيد الإلغاء' : 'Confirm Cancel',
              style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await orderProv.cancelOrder(order.id!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic ? 'تم إلغاء مهمة التوصيل بنجاح' : 'Delivery canceled successfully',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                      ),
                      backgroundColor: kRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '').trim()),
                      backgroundColor: kRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final order = (provider.order?.id == widget.order.id)
        ? provider.order!
        : widget.order;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : kPageBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'تفاصيل الطلب #${order.id}' : 'Order #${order.id}',
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: isArabic ? 'تحديث' : 'Refresh',
            onPressed: () {
              if (order.id != null) {
                provider.silentSyncOrder(order.id!);
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(context, order, provider, isArabic),
      body: FullScreenLoading(
        inAsyncCall: provider.isBusy && provider.orderIsEmpty(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Status Banner Card & Next Step Guide
                _buildStatusBanner(order, isDark, isArabic),

                const SizedBox(height: 12),

                // 2. Financial & COD Amount Card
                _buildPaymentCard(order, isDark, isArabic),

                const SizedBox(height: 16),

                // 3. Multi-Merchant Pickup Progress Header (if multiple)
                if (order.totalMerchantsCount > 1)
                  _buildMultiMerchantProgress(order, isDark, isArabic),

                // 4. Merchant Pickup Stops
                if (order.orderDetails != null && order.orderDetails!.isNotEmpty) ...[
                  Text(
                    isArabic ? 'نقاط الاستلام (المتاجر)' : 'Pickup Stops (Stores)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : kCharcoalDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...order.orderDetails!.map((merchant) => MerchentOrderDetailsCard(
                        item: merchant,
                        orderId: order.id!,
                        showPickupAction: true,
                      )),
                ],

                const SizedBox(height: 16),

                // 5. Customer Destination Card
                Text(
                  isArabic ? 'وجهة التسليم (العميل)' : 'Dropoff Destination (Customer)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                ),
                const SizedBox(height: 10),
                CustomerOrderDetailsCard(order: order),

                const SizedBox(height: 20),

                // 6. Cancel Delivery Action (If non-terminal)
                if (!order.isTerminal) ...[
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: provider.isActionInFlight(order.id)
                          ? null
                          : () => _confirmCancelOrder(context, order),
                      icon: const AppIcon(PhosphorIcons.xCircleBold, size: 16, color: kRed),
                      label: Text(
                        isArabic ? 'إلغاء مهمة التوصيل لهذا الطلب' : 'Cancel Delivery for Order',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kRed,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kRed.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status Header & Next Step Banner
  // ---------------------------------------------------------------------------
  Widget _buildStatusBanner(OrderModel order, bool isDark, bool isArabic) {
    final status = order.deliveryStatus;
    final timeFormatted = GlobalVar.dateForamt(order.purchaseDate, 'yyyy-MM-dd HH:mm') ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : kCardBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Order ID badge with copy action
              InkWell(
                onTap: () {
                  if (order.id != null) {
                    Clipboard.setData(ClipboardData(text: '${order.id}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic ? 'تم نسخ رقم الطلب' : 'Order ID copied',
                          style: GoogleFonts.ibmPlexSansArabic(),
                        ),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : kSurfaceWarm,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const AppIcon(PhosphorIcons.hashBold, size: 14, color: kPrimaryOrange),
                      const SizedBox(width: 4),
                      Text(
                        '${order.id}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kPrimaryOrange,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 12, color: kPrimaryOrange),
                    ],
                  ),
                ),
              ),

              // Status Pill
              _buildStatusPill(status, isDark, isArabic),
            ],
          ),

          const SizedBox(height: 12),

          // Next Step Guide Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _nextStepBackgroundColor(order, isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _nextStepBorderColor(order, isDark)),
            ),
            child: Row(
              children: [
                AppIcon(
                  _nextStepIcon(order),
                  size: 22,
                  color: _nextStepTextColor(order, isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'الخطوة التالية للمندوب:' : 'Next Action:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _nextStepTextColor(order, isDark).withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _nextStepDescription(order, isArabic),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _nextStepTextColor(order, isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? kDarkRedBg : kRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDark ? kDarkRedBorder : kRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  AppIcon(PhosphorIcons.warningCircleBold,
                      size: 16, color: isDark ? kDarkRedText : kRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${isArabic ? "ملاحظات / سبب الرفض: " : "Notes / Rejection Reason: "}${order.notes}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? kDarkRedText : kRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (timeFormatted.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppIcon(PhosphorIcons.clockBold,
                    size: 13,
                    color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
                const SizedBox(width: 4),
                Text(
                  timeFormatted,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                    fontWeight: FontWeight.w500,
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
  // Payment / COD Card
  // ---------------------------------------------------------------------------
  Widget _buildPaymentCard(OrderModel order, bool isDark, bool isArabic) {
    final isCod = order.isCod;
    final priceFormatted = GlobalVar.priceForamt(order.price);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCod
            ? (isDark ? kDarkAmberBg : const Color(0xFFFFFBEB))
            : (isDark ? kDarkGreenBg : const Color(0xFFECFDF5)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCod
              ? (isDark ? kDarkAmberBorder : const Color(0xFFFDE68A))
              : (isDark ? kDarkGreenBorder : const Color(0xFFA7F3D0)),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isCod
                  ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                  : (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: AppIcon(
                isCod ? PhosphorIcons.moneyBold : PhosphorIcons.creditCardBold,
                size: 22,
                color: isCod
                    ? (isDark ? kDarkAmberText : const Color(0xFFB45309))
                    : (isDark ? kDarkGreenText : const Color(0xFF047857)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCod
                      ? (isArabic ? 'المطلوب تحصيله من العميل (نقداً):' : 'Collect from customer (Cash):')
                      : (isArabic ? 'الطلب مدفوع إلكترونياً (مسبقاً)' : 'Order is Prepaid (Card)'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isCod
                        ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                        : (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCod
                      ? '$priceFormatted ${isArabic ? 'ليرة سورية' : 'SYP'}'
                      : (isArabic ? 'لا تقم بتحصيل أي مبالغ نقدية من العميل' : 'Do not collect any cash'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: isCod ? 16 : 13,
                    fontWeight: FontWeight.w800,
                    color: isCod
                        ? (isDark ? kDarkAmberText : const Color(0xFFB45309))
                        : (isDark ? kDarkGreenText : const Color(0xFF047857)),
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
  // Multi-merchant progress indicator
  // ---------------------------------------------------------------------------
  Widget _buildMultiMerchantProgress(OrderModel order, bool isDark, bool isArabic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? kDarkBlueBorder : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        children: [
          AppIcon(PhosphorIcons.pathBold,
              size: 20,
              color: isDark ? kDarkBlueText : const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'توصيل متعدد المتاجر' : 'Multi-Store Delivery',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? kDarkBlueText
                        : const Color(0xFF1E40AF),
                  ),
                ),
                Text(
                  isArabic
                      ? 'تم استلام ${order.pickedUpMerchantsCount} من أصل ${order.totalMerchantsCount} متاجر'
                      : 'Picked up ${order.pickedUpMerchantsCount} of ${order.totalMerchantsCount} stores',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E3A8A),
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
  // Persistent Bottom Primary Action Bar
  // ---------------------------------------------------------------------------
  Widget _buildBottomActionBar(
    BuildContext context,
    OrderModel order,
    OrderProvider provider,
    bool isArabic,
  ) {
    final isActionInFlight = provider.isActionInFlight(order.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (order.isDelivered) {
      return Container(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? kDarkGreenBg : kGreenLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(PhosphorIcons.checkCircleBold,
                  color: isDark ? kDarkGreenText : kGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'تم تسليم هذا الطلب بنجاح ✓' : 'Order Delivered Successfully ✓',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? kDarkGreenText : kGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (order.isCanceled) {
      return Container(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? kDarkRedBg : kRedLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(PhosphorIcons.xCircleBold,
                  color: isDark ? kDarkRedText : kRed, size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'هذا الطلب ملغي' : 'Order is Canceled',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? kDarkRedText : kRed,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Workflow Actions:
    // 1. All merchants in transit -> Primary Action: Deliver to Customer
    if (order.canDeliverToCustomer) {
      return Container(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isActionInFlight
                ? null
                : () => PoDVerificationDialog.show(context, order),
            icon: isActionInFlight
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const AppIcon(PhosphorIcons.shieldCheckBold, size: 20, color: Colors.white),
            label: Text(
              isArabic ? 'تأكيد تسليم الطلب للعميل (PoD)' : 'Confirm Delivery to Customer',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      );
    }

    // 2. Pending Pickups -> Primary Action: Pickup from Next Merchant
    final nextMerchant = order.nextPendingMerchant;
    if (nextMerchant != null && nextMerchant.orderDetailStatus == OrderDetailsStatus.readyForPickup) {
      return Container(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isActionInFlight
                ? null
                : () async {
                    try {
                      await provider.startShipping(order.id!, nextMerchant.merchantId!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isArabic
                                  ? 'تم استلام الطلب من ${nextMerchant.merchantTitle ?? "المتجر"} بنجاح ✓'
                                  : 'Order picked up successfully ✓',
                              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: kGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceAll('Exception: ', '').trim(),
                              style: GoogleFonts.ibmPlexSansArabic(),
                            ),
                            backgroundColor: kRed,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
            icon: isActionInFlight
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const AppIcon(PhosphorIcons.storefrontBold, size: 20, color: Colors.white),
            label: Text(
              isActionInFlight
                  ? (isArabic ? 'جاري التأكيد...' : 'Confirming...')
                  : (isArabic
                      ? 'استلام الطلب من ${nextMerchant.merchantTitle ?? "المتجر"}'
                      : 'Pickup from ${nextMerchant.merchantTitle ?? "Store"}'),
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      );
    }

    // Fallback: Merchant still preparing
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? kDarkAmberBg : kAmberLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(PhosphorIcons.clockBold,
                color: isDark ? kDarkAmberText : const Color(0xFFB45309),
                size: 18),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'المتجر يقوم بتجهيز الطلب حالياً...' : 'Merchant is preparing order...',
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? kDarkAmberText : const Color(0xFFB45309),
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Color & Label Methods
  // ---------------------------------------------------------------------------
  Widget _buildStatusPill(OrderDetailsStatus status, bool isDark, bool isArabic) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case OrderDetailsStatus.delivered:
        bg = isDark ? kDarkGreenBg : kGreenLight;
        fg = isDark ? kDarkGreenText : kGreen;
        text = isArabic ? 'تم التسليم بنجاح ✓' : 'Delivered ✓';
        break;
      case OrderDetailsStatus.shipping:
        bg = isDark ? const Color(0xFF334155) : kSurfaceWarm;
        fg = kPrimaryOrange;
        text = isArabic ? 'قيد التوصيل للعميل' : 'Out for Delivery';
        break;
      case OrderDetailsStatus.readyForPickup:
        bg = isDark ? kDarkBlueBg : kBlueLight;
        fg = isDark ? kDarkBlueText : kBlue;
        text = isArabic ? 'جاهز للاستلام من المتجر' : 'Ready for Pickup';
        break;
      case OrderDetailsStatus.merchantAccepted:
        bg = isDark ? kDarkAmberBg : kAmberLight;
        fg = isDark ? kDarkAmberText : const Color(0xFFB45309);
        text = isArabic ? 'قيد التجهيز لدى المتجر' : 'Preparing';
        break;
      case OrderDetailsStatus.deliveryCanceled:
      case OrderDetailsStatus.customerCanceled:
      case OrderDetailsStatus.merchantRejected:
        bg = isDark ? kDarkRedBg : kRedLight;
        fg = isDark ? kDarkRedText : kRed;
        text = isArabic ? 'ملغي' : 'Canceled';
        break;
      default:
        bg = isDark ? const Color(0xFF334155) : kGreyBackground;
        fg = isDark ? Colors.white : kCharcoalDark;
        text = status.value;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Color _nextStepBackgroundColor(OrderModel o, bool isDark) {
    if (o.isDelivered) return isDark ? kDarkGreenBg : kGreenLight;
    if (o.isCanceled) return isDark ? kDarkRedBg : kRedLight;
    if (o.canDeliverToCustomer) return isDark ? const Color(0xFF2A1C12) : const Color(0xFFFFF0E8);
    if (o.hasPendingPickups) return isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
    return isDark ? kDarkAmberBg : kAmberLight;
  }

  Color _nextStepBorderColor(OrderModel o, bool isDark) {
    if (o.isDelivered) return isDark ? kDarkGreenBorder : const Color(0xFFA7F3D0);
    if (o.isCanceled) return isDark ? kDarkRedBorder : const Color(0xFFFECACA);
    if (o.canDeliverToCustomer) return isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFD4C0);
    if (o.hasPendingPickups) return isDark ? kDarkBlueBorder : const Color(0xFFBFDBFE);
    return isDark ? kDarkAmberBorder : const Color(0xFFFDE68A);
  }

  Color _nextStepTextColor(OrderModel o, bool isDark) {
    if (o.isDelivered) return isDark ? kDarkGreenText : const Color(0xFF047857);
    if (o.isCanceled) return isDark ? kDarkRedText : const Color(0xFFB91C1C);
    if (o.canDeliverToCustomer) return kPrimaryOrange;
    if (o.hasPendingPickups) return isDark ? kDarkBlueText : const Color(0xFF1E40AF);
    return isDark ? kDarkAmberText : const Color(0xFFB45309);
  }

  IconData _nextStepIcon(OrderModel o) {
    if (o.isDelivered) return PhosphorIcons.checkCircleBold;
    if (o.isCanceled) return PhosphorIcons.xCircleBold;
    if (o.canDeliverToCustomer) return PhosphorIcons.mopedBold;
    if (o.hasPendingPickups) return PhosphorIcons.storefrontBold;
    return PhosphorIcons.clockBold;
  }

  String _nextStepDescription(OrderModel o, bool isArabic) {
    if (o.isDelivered) {
      return isArabic ? 'تم إتمام وتوثيق تسليم هذا الطلب بنجاح.' : 'Order delivery completed.';
    }
    if (o.isCanceled) {
      return isArabic ? 'تم إلغاء هذا الطلب.' : 'This order has been canceled.';
    }
    if (o.canDeliverToCustomer) {
      final customerName = o.user ?? (isArabic ? 'العميل' : 'Customer');
      return isArabic
          ? 'الطلب في حوزتك. توجه إلى $customerName وأكد التسليم.'
          : 'Order with you. Head to $customerName and confirm delivery.';
    }
    if (o.hasPendingPickups) {
      final next = o.nextPendingMerchant;
      final storeName = next?.merchantTitle ?? (isArabic ? 'المتجر' : 'Store');
      if (next?.orderDetailStatus == OrderDetailsStatus.readyForPickup) {
        return isArabic
            ? 'الطلب جاهز! توجه إلى $storeName للاستلام.'
            : 'Order ready! Head to $storeName for pickup.';
      }
      return isArabic
          ? 'المتجر $storeName يقوم بتجهيز الطلب.'
          : 'Store $storeName is preparing the items.';
    }
    return isArabic ? 'بانتظار تجهيز الطلب' : 'Waiting for order preparation';
  }
}

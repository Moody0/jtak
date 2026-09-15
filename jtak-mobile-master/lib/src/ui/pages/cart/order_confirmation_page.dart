import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/constants/app_constant.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/app/home_navigation_provider.dart';
import '../../../core/enums/payment_method_enum.dart';
import '../../../core/models/order/order_model.dart';
import '../../../utils/utilities/global_var.dart';
import '../../widgets/header_circle_button.dart';
import '../orders/order_details_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Order Confirmation Page (صفحة تأكيد الطلب)
/// Displayed immediately upon order placement with full order data & tracking CTA
/// ---------------------------------------------------------------------------

class OrderConfirmationPage extends StatelessWidget {
  static const String routeName = '/OrderConfirmationPage';

  final OrderModel order;

  const OrderConfirmationPage({super.key, required this.order});

  static String _formatPrice(double? price) {
    if (price == null) return '0';
    return price.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'اليوم، الآن';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = [
        'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
        'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'
      ];
      final monthName = months[dt.month - 1];
      final period = dt.hour >= 12 ? 'م' : 'ص';
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $monthName ${dt.year} - $hour:$minute $period';
    } catch (_) {
      return 'اليوم، الآن';
    }
  }

  String _getPaymentMethodTitle(PaymentMethod? method) {
    switch (method) {
      case PaymentMethod.payOnDelivery:
        return 'الدفع عند الاستلام (كاش)';
      case PaymentMethod.creditCardPayment:
        return 'الدفع الإلكتروني / البطاقات';
      default:
        return 'الدفع عند الاستلام (كاش)';
    }
  }

  void _onBackToHome(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).popUntil((route) => route.isFirst);
    Provider.of<HomeNavigationProvider>(context, listen: false).changePage(0);
  }

  void _onTrackOrderLive(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsPage(order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int itemsCount = order.orderDetails?.length ?? 0;
    final double totalPrice = order.price ?? 0.0;
    final String orderNumText = order.id != null ? '#${order.id}' : 'طلب جديد';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackToHome(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            physics: const ClampingScrollPhysics(),
            children: [
              // 1. Celebratory Success Hero Header
              _buildSuccessHero(context, orderNumText),
              const SizedBox(height: 16),

              // 2. Order Quick Meta Stats Grid
              _buildMetaGrid(context, orderNumText),
              const SizedBox(height: 16),

              // 3. Ordered Items Breakdown
              _buildOrderItemsCard(context),
              const SizedBox(height: 16),

              // 4. Delivery & Recipient Details
              _buildDeliveryDetailsCard(context),
              const SizedBox(height: 16),

              // 5. Payment & Financial Summary
              _buildPaymentSummaryCard(context, totalPrice, itemsCount),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leading: Center(
        child: HeaderCircleButton(
          iconData: PhosphorIconsRegular.house,
          onTap: () => _onBackToHome(context),
        ),
      ),
      title: Text(
        'تم تأكيد الطلب',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 18,
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

  Widget _buildSuccessHero(BuildContext context, String orderNum) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        children: [
          // Celebratory Icon Badge
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                ),
              ),
              Transform.flip(
                flipX: true,
                child: const Icon(
                  PhosphorIconsFill.checkCircle,
                  color: Color(0xFF10B981),
                  size: 46,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'تم تأكيد طلبك بنجاح!',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: kCharcoalDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'شكراً لطلبك من جيتك. بدأ المتجر بتحضير وجباتك وسيتولى كابتن التوصيل إيصالها بأسرع وقت.',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaGrid(BuildContext context, String orderNum) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Order Number with Copy CTA
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (order.id != null) {
                      Clipboard.setData(ClipboardData(text: order.id.toString()));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم نسخ رقم الطلب (${order.id})',
                            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600),
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: kCharcoalDark,
                        ),
                      );
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFEDD5), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsFill.receipt, color: kPrimaryOrange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'رقم الطلب',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFC2410C),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    orderNum,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                      color: kPrimaryOrange,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(PhosphorIconsRegular.copy, size: 13, color: kPrimaryOrange),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Estimated Delivery Time
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsFill.clock, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'وقت التوصيل التقديري',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                            Text(
                              '25 - 35 دقيقة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Order Status Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'حالة الطلب: قيد التحضير في المطعم',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kCharcoalDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(order.purchaseDate),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard(BuildContext context) {
    final items = order.orderDetails ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(PhosphorIconsFill.shoppingBagOpen, color: kPrimaryOrange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الوجبات والأصناف المطلوبة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kCharcoalDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length} أصناف',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: Color(0xFFF8FAFC)),
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final rawImg = item.productImage ?? '';
              final imgUrl = GlobalVar.getImageUrl(rawImg);
              final title = item.productTitle ?? 'وجبة خاصة';
              final merchant = item.merchantTitle ?? '';
              final qty = item.quantity ?? 1;
              final unitPrice = item.singleFinalPrice ?? 0.0;
              final itemTotal = item.totalFinalPrice ?? (unitPrice * qty);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Item Image Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFFF1F5F9),
                      child: imgUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: const Color(0xFFF1F5F9)),
                              errorWidget: (_, __, ___) => const Icon(
                                PhosphorIconsFill.hamburger,
                                color: Color(0xFF94A3B8),
                                size: 22,
                              ),
                            )
                          : const Icon(
                              PhosphorIconsFill.hamburger,
                              color: Color(0xFF94A3B8),
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Item Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: kCharcoalDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (merchant.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            merchant,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          '$qty × ${_formatPrice(unitPrice)} $kMainCurrencySymbol',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Item Total
                  Text(
                    '${_formatPrice(itemTotal)} $kMainCurrencySymbol',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kCharcoalDark,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetailsCard(BuildContext context) {
    final address = order.address?.trim() ?? 'دمشق، سوريا';
    final recipientName = order.user?.trim().isNotEmpty == true ? order.user!.trim() : 'عميل جيتك';
    final phone = order.phonenumber?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsFill.mapPin, color: kPrimaryOrange, size: 18),
              const SizedBox(width: 8),
              Text(
                'تفاصيل ومعلومات التوصيل',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(PhosphorIconsRegular.navigationArrow, size: 16, color: kCharcoalMedium),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عنوان التوصيل',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
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
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Recipient & Phone
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(PhosphorIconsRegular.user, size: 16, color: kCharcoalMedium),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المستلم',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            recipientName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kCharcoalDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(PhosphorIconsRegular.phone, size: 16, color: kCharcoalMedium),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رقم الهاتف',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              phone,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kCharcoalDark,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(BuildContext context, double total, int itemsCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsFill.wallet, color: kPrimaryOrange, size: 18),
              const SizedBox(width: 8),
              Text(
                'ملخص الدفع والفاتورة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          _buildSummaryLine('طريقة الدفع', _getPaymentMethodTitle(order.paymentMethod)),
          const SizedBox(height: 8),
          _buildSummaryLine('إجمالي الأصناف', '$itemsCount وجبات'),
          const SizedBox(height: 8),
          _buildSummaryLine('خدمة التوصيل', 'مجاناً', isHighlight: true),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المبلغ الإجمالي للدفع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: kCharcoalDark,
                ),
              ),
              Text(
                '${_formatPrice(total)} $kMainCurrencySymbol',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: kPrimaryOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
            color: isHighlight ? const Color(0xFF059669) : kCharcoalDark,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Primary Action: Track Live Order
            GestureDetector(
              onTap: () => _onTrackOrderLive(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: kPrimaryOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsFill.navigationArrow, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'متابعة الطلب مباشرة (تتبع حي)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 2. Secondary Action: Back to Home
            GestureDetector(
              onTap: () => _onBackToHome(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Text(
                    'العودة إلى الصفحة الرئيسية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: kCharcoalDark,
                    ),
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../main_imports.dart';
import '../../../config/constants/app_constant.dart';
import '../../../config/themes/colors.dart';
import '../../../core/enums/order_details_status_enum.dart';
import '../../../core/models/order/order_details_model.dart';
import '../../../core/models/order/order_model.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../../utils/utilities/global_var.dart';
import 'order_details_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Order Card (Flat, Shadow-Free Design System)
/// ---------------------------------------------------------------------------

class OrderSingleItem extends StatelessWidget {
  final OrderModel item;
  final VoidCallback? onReorder;
  final VoidCallback? onTrack;

  const OrderSingleItem(
    this.item, {
    super.key,
    this.onReorder,
    this.onTrack,
  });

  static String formatPrice(double? price) {
    if (price == null) return '0';
    return price.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final status = _getOrderStatus(item);
    final isDelivered = status == OrderDetailsStatus.delivered;
    final isCanceled = status == OrderDetailsStatus.customerCanceled ||
        status == OrderDetailsStatus.deliveryCanceled ||
        status == OrderDetailsStatus.merchantRejected;
    final isActive = !isDelivered && !isCanceled;

    final String storeName = _getStoreName(item);
    final String itemsSummary = _getItemsSummary(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            context.navigateName(OrderDetailsPage.routeName, data: item);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Store Icon + Title + Order ID + Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Store Avatar Squircle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFD6C2), width: 1.2),
                      ),
                      child: const Center(
                        child: Icon(
                          PhosphorIconsFill.storefront,
                          color: kPrimaryOrange,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Store Name & Order #
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: kCharcoalDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'طلب #${item.id ?? ""}',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _formatDate(item.purchaseDate),
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    _buildStatusBadge(status),
                  ],
                ),

                const SizedBox(height: 14),

                // 2. Middle: Food Image Squircles & Items Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
                  ),
                  child: Row(
                    children: [
                      _buildThumbnailsRow(context),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          itemsSummary,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Bottom Row: Total Price & Quick Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Total Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المجموع الكلي',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatPrice(item.price),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: kPrimaryOrange,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              kMainCurrencySymbol,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kPrimaryOrange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Contextual Action Button
                    if (isActive)
                      GestureDetector(
                        onTap: () {
                          context.navigateName(OrderDetailsPage.routeName, data: item);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: kPrimaryOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIconsFill.motorcycle, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'تتبع الطلب',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (isDelivered)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Details Link
                          GestureDetector(
                            onTap: () {
                              context.navigateName(OrderDetailsPage.routeName, data: item);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'التفاصيل',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Reorder Button
                          GestureDetector(
                            onTap: onReorder ??
                                () {
                                  context.showSnakBar('تمت إضافة الوجبات إلى السلة بنجاح 🛒');
                                },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0E8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFD6C2), width: 1.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(PhosphorIconsRegular.arrowsClockwise, size: 15, color: kPrimaryOrange),
                                  const SizedBox(width: 5),
                                  Text(
                                    'إعادة الطلب',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: kPrimaryOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      // Canceled details link
                      GestureDetector(
                        onTap: () {
                          context.navigateName(OrderDetailsPage.routeName, data: item);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'تفاصيل الإلغاء',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailsRow(BuildContext context) {
    final details = item.orderDetails ?? [];
    if (details.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(PhosphorIconsRegular.shoppingBag, color: Color(0xFF94A3B8), size: 20),
      );
    }

    final int maxThumbs = math.min(2, details.length);
    final int extraCount = details.length - maxThumbs;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < maxThumbs; i++)
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: ImageView(
                details[i].productImage?.split(',').first,
                height: 44,
                width: 44,
              ),
            ),
          ),
        if (extraCount > 0)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '+$extraCount',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(OrderDetailsStatus status) {
    Color bg;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case OrderDetailsStatus.shipping:
        bg = const Color(0xFFFFF0E8);
        textColor = kPrimaryOrange;
        text = 'في الطريق للتوصيل';
        icon = PhosphorIconsFill.motorcycle;
        break;
      case OrderDetailsStatus.pending:
      case OrderDetailsStatus.merchantAccepted:
      case OrderDetailsStatus.customerPending:
        bg = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF2563EB);
        text = 'قيد التحضير';
        icon = PhosphorIconsFill.clock;
        break;
      case OrderDetailsStatus.delivered:
        bg = const Color(0xFFECFDF5);
        textColor = const Color(0xFF059669);
        text = 'تم التوصيل';
        icon = PhosphorIconsFill.checkCircle;
        break;
      case OrderDetailsStatus.customerCanceled:
      case OrderDetailsStatus.deliveryCanceled:
      case OrderDetailsStatus.merchantRejected:
        bg = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        text = 'تم الإلغاء';
        icon = PhosphorIconsFill.xCircle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  OrderDetailsStatus _getOrderStatus(OrderModel order) {
    if (GlobalVar.checkListNotEmpty(order.orderDetails)) {
      var status = order.orderDetails!.first.orderDetailStatus ?? OrderDetailsStatus.pending;
      for (var element in order.orderDetails!) {
        if ((element.orderDetailStatus?.index ?? 0) < status.index) {
          status = element.orderDetailStatus ?? OrderDetailsStatus.pending;
        }
      }
      return status;
    }
    return OrderDetailsStatus.pending;
  }

  String _getStoreName(OrderModel order) {
    if (order.description != null && order.description!.isNotEmpty) {
      return order.description!;
    }
    if (order.orderDetails != null && order.orderDetails!.isNotEmpty) {
      return order.orderDetails!.first.merchantTitle ?? 'متجر جيتك';
    }
    return 'طلب توصيل جيتك';
  }

  String _getItemsSummary(OrderModel order) {
    final details = order.orderDetails ?? [];
    if (details.isEmpty) return 'تفاصيل الوجبات والمنتجات';
    return details.map((d) => '${d.quantity ?? 1}x ${d.productTitle ?? ""}').join('، ');
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'اليوم';
    try {
      final date = DateTime.parse(rawDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) {
        return 'منذ ${diff.inMinutes} دقيقة';
      } else if (diff.inHours < 24 && date.day == now.day) {
        return 'اليوم، ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'أمس، ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return rawDate;
    }
  }
}

/// ---------------------------------------------------------------------------
/// JTAK Modern Order Details Line Item (Flat Shadow-Free)
/// ---------------------------------------------------------------------------

class OrderDetailsSingleItem extends StatelessWidget {
  final OrderDetailsModel item;
  const OrderDetailsSingleItem(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        children: [
          // Item Image Squircle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: ImageView(
                item.productImage?.split(',').first,
                height: 60,
                width: 60,
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
                  item.productTitle ?? '',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kCharcoalDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity ?? 1} × ${OrderSingleItem.formatPrice(item.singleFinalPrice)} $kMainCurrencySymbol',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Total Item Price
          Text(
            '${OrderSingleItem.formatPrice(item.totalFinalPrice)} $kMainCurrencySymbol',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: kPrimaryOrange,
            ),
          ),
        ],
      ),
    );
  }
}

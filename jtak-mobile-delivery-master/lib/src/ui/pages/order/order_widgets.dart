import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/constants/constants.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/order_provider.dart';
import '../../../core/enums/order_details_status_enum.dart';
import '../../../core/models/merchant_order_details.dart';
import '../../../core/models/order_details_model.dart';
import '../../../core/models/order_model.dart';
import '../../../ui/widgets/app_widgets.dart';
import '../../../ui/widgets/price_widgets.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';

class OrderSingleItem extends StatelessWidget {
  final OrderModel item;
  const OrderSingleItem(this.item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final status = orderProvider.getOrderStatus(item);
    final isDelivered = status == OrderDetailsStatus.delivered;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDelivered
              ? (isDark ? const Color(0xFF334155) : kBorderColor)
              : (isDark ? const Color(0xFF475569) : kPrimaryOrange.withOpacity(0.25)),
          width: isDelivered ? 1 : 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Order Header (ID + Date + Price + Status Pill)
          _buildHeader(context, status, isDark, isArabic),

          Divider(height: 1, color: isDark ? const Color(0xFF334155) : kBorderColor),

          // 2. Merchant Store & Pickup Details
          if (item.orderDetails != null && item.orderDetails!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.orderDetails!
                    .map((merchant) => MerchentOrderDetails(merchant, item.id!))
                    .toList(),
              ),
            ),

          Divider(height: 1, color: isDark ? const Color(0xFF334155) : kBorderColor),

          // 3. Customer Destination & Action Section
          _buildCustomerSection(context, status, isDark, isArabic),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, OrderDetailsStatus status, bool isDark, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Order Number Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(PhosphorIcons.hashBold, size: 14, color: kPrimaryOrange),
                    const SizedBox(width: 2),
                    Text(
                      '${item.id}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryOrange,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Pill
              _buildStatusPill(status, isDark, isArabic),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Timestamp
              Row(
                children: [
                  AppIcon(PhosphorIcons.clockBold, size: 14, color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
                  const SizedBox(width: 4),
                  Text(
                    GlobalVar.dateForamt(item.purchaseDate, kDateTimeFormat) ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Price
              PriceTextWidget.small(
                price: item.price,
                currencyString: isArabic ? 'ل.س' : 'SYP',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(OrderDetailsStatus status, bool isDark, bool isArabic) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case OrderDetailsStatus.delivered:
        bg = isDark ? const Color(0xFF064E3B) : kGreenLight;
        fg = isDark ? const Color(0xFF34D399) : kGreen;
        text = isArabic ? 'تم التسليم بنجاح' : 'Delivered';
        icon = PhosphorIcons.checkCircleBold;
        break;
      case OrderDetailsStatus.shipping:
        bg = isDark ? const Color(0xFF334155) : kSurfaceWarm;
        fg = kPrimaryOrange;
        text = isArabic ? 'قيد التوصيل للعميل' : 'Out for Delivery';
        icon = PhosphorIcons.mopedBold;
        break;
      case OrderDetailsStatus.merchantAccepted:
        bg = isDark ? const Color(0xFF1E3A8A) : kBlueLight;
        fg = isDark ? const Color(0xFF60A5FA) : kBlue;
        text = isArabic ? 'جاهز للاستلام من المتجر' : 'Ready for Pickup';
        icon = PhosphorIcons.storefrontBold;
        break;
      default:
        bg = isDark ? const Color(0xFF334155) : kGreyBackground;
        fg = isDark ? Colors.white : kCharcoalDark;
        text = status.value;
        icon = PhosphorIcons.infoBold;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(BuildContext context, OrderDetailsStatus status, bool isDark, bool isArabic) {
    final isDelivered = status == OrderDetailsStatus.delivered;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Details Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : kGreyBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const AppIcon(PhosphorIcons.mapPinBold, size: 18, color: kPrimaryOrange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.user ?? (isArabic ? 'العميل' : 'Customer'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : kCharcoalDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.address ?? (isArabic ? 'لا يوجد عنوان محدد' : 'No specified address'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDelivered && GlobalVar.checkString(item.phonenumber))
                InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:${item.phonenumber}')),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : kGreenLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF047857) : kGreen.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: AppIcon(
                      PhosphorIcons.phoneCallBold,
                      size: 18,
                      color: isDark ? const Color(0xFF34D399) : kGreen,
                    ),
                  ),
                ),
            ],
          ),

          if (!isDelivered) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                // 1. Open Google Maps Navigation Button
                if (GlobalVar.checkString(item.mapsUrl))
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        try {
                          launchUrl(Uri.parse(item.mapsUrl ?? ''), mode: LaunchMode.externalApplication);
                        } catch (err) {
                          showDialog(context: context, builder: (ctx) => CustomDialog(message: err.toString()));
                        }
                      },
                      icon: const AppIcon(PhosphorIcons.navigationArrowBold, size: 16),
                      label: Text(isArabic ? 'تتبع الخريطة' : 'Map Navigation'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryOrange,
                        side: const BorderSide(color: kPrimaryOrange, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                if (GlobalVar.checkString(item.mapsUrl)) const SizedBox(width: 10),

                // 2. Deliver to Customer Action Button
                Expanded(
                  flex: 6,
                  child: ElevatedButton.icon(
                    onPressed: status == OrderDetailsStatus.shipping
                        ? () => _confirmDelivery(context, isArabic)
                        : null,
                    icon: const AppIcon(PhosphorIcons.checkCircleBold, size: 18),
                    label: Text(isArabic ? 'تأكيد التسليم' : 'Confirm Delivery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      disabledBackgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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

  void _confirmDelivery(BuildContext context, bool isArabic) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isArabic ? 'تأكيد تسليم الطلب' : 'Confirm Order Delivery',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          isArabic
              ? 'هل تم تسليم الطلب #${item.id} للعميل واستلام المبلغ بنجاح؟'
              : 'Has order #${item.id} been delivered to the customer and payment collected?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            child: Text(
              isArabic ? 'نعم، تم التسليم' : 'Yes, Delivered',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await Provider.of<OrderProvider>(context, listen: false).deliverOrder(item.id!);
              } catch (err) {
                showDialog(context: context, builder: (ctx) => CustomDialog(message: err.toString()));
              }
            },
          ),
        ],
      ),
    );
  }
}

class MerchentOrderDetails extends StatelessWidget {
  final MerchentOrderDetailsModel item;
  final int orderId;
  const MerchentOrderDetails(this.item, this.orderId, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAccepted = item.orderDetailStatus == OrderDetailsStatus.merchantAccepted;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : kPageBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : kBorderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Name & Pickup Action
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const AppIcon(PhosphorIcons.storefrontBold, size: 16, color: kPrimaryOrange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.merchantTitle ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                ),
              ),
              if (isAccepted)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isArabic ? 'استلام من المتجر' : 'Store Pickup',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () async {
                    try {
                      await Provider.of<OrderProvider>(context, listen: false).startShipping(orderId, item.merchantId!);
                    } catch (err) {
                      showDialog(context: context, builder: (ctx) => CustomDialog(message: err.toString()));
                    }
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B) : kGreenLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isArabic ? 'تم الاستلام ✓' : 'Picked Up ✓',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF34D399) : kGreen,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Items inside this merchant order
          if (item.orderDetails != null)
            Column(
              children: item.orderDetails!
                  .map((product) => OrderDetailsSingleItem(product))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class OrderDetailsSingleItem extends StatelessWidget {
  final OrderDetailsModel item;
  const OrderDetailsSingleItem(this.item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Product Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _image(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productTitle ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                ),
                if (GlobalVar.checkString(item.productUnit))
                  Text(
                    item.productUnit ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                    ),
                  ),
              ],
            ),
          ),
          // Quantity Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF334155) : kBorderColor, width: 1),
            ),
            child: Text(
              '${item.quantity} ×',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kPrimaryOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image() {
    const double size = 44;
    if (GlobalVar.checkString(item.productImage)) {
      return ImageView(item.productImage?.split(',').first, height: size, width: size);
    }
    return Image.asset(kNoImage, height: size, width: size, fit: BoxFit.cover);
  }
}

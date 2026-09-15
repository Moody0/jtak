import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/constants/constants.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/order_provider.dart';
import '../../../core/enums/order_status_enum.dart';
import '../../../core/models/order_model.dart';
import '../../../ui/widgets/app_widgets.dart';
import '../../../ui/widgets/price_widgets.dart';
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
  late OrderProvider provider;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    Provider.of<OrderProvider>(context, listen: false)
        .setOrderObject(widget.order);
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final model = Provider.of<OrderProvider>(context, listen: false);
      if (widget.order.id != null) model.silentSyncOrder(widget.order.id!);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<OrderProvider>(context);
    return Scaffold(
      backgroundColor: kPageBackground,
      appBar: AppBar(
        title: Text(
          'تفاصيل الطلب #${widget.order.id}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: FullScreenLoading(
        inAsyncCall: provider.isBusy,
        child: SafeArea(child: _pageBody()),
      ),
    );
  }

  Widget _pageBody() {
    if (provider.orderIsEmpty()) {
      if (provider.isBusy) return const SizedBox();
      return const NoDataAvailableWidget(msg: 'لم يتم العثور على بيانات الطلب');
    }

    final order = provider.order!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCardBorderColor, width: 1.1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kSurfaceWarm,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${order.id}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryOrange,
                        ),
                      ),
                    ),
                    PriceTextWidget.large(price: order.price),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: kBorderColor, height: 1),
                const SizedBox(height: 14),
                _buildInfoRow(
                    PhosphorIcons.calendarBlankBold,
                    'تاريخ الطلب',
                    GlobalVar.dateForamt(order.purchaseDate, kDateTimeFormat) ??
                        ''),
                if (GlobalVar.checkString(order.description))
                  _buildInfoRow(
                      PhosphorIcons.notepadBold, 'ملاحظات', order.description!),
                _buildInfoRow(PhosphorIcons.tagBold, 'الحالة',
                    order.orderStatus?.value ?? 'غير محدد'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Customer Details Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCardBorderColor, width: 1.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'بيانات العميل والتوصيل',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kCharcoalDark,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                    PhosphorIcons.userBold, 'الاسم', order.user ?? 'غير محدد'),
                _buildInfoRow(PhosphorIcons.mapPinBold, 'العنوان',
                    order.address ?? 'غير محدد'),
                if (GlobalVar.checkString(order.phonenumber))
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const AppIcon(PhosphorIcons.phoneBold,
                              size: 16, color: kCharcoalMuted),
                          const SizedBox(width: 8),
                          Text(order.phonenumber!,
                              style: const TextStyle(
                                  fontSize: 13, color: kCharcoalDark)),
                        ],
                      ),
                      IconButton(
                        icon: const AppIcon(PhosphorIcons.phoneCallBold,
                            color: kGreen, size: 20),
                        onPressed: () =>
                            launchUrl(Uri.parse('tel:${order.phonenumber}')),
                      ),
                    ],
                  ),
                Builder(
                  builder: (context) {
                    final navUrl = GlobalVar.getCustomerNavigationUrl(
                      lat: order.lat,
                      lng: order.lng,
                      address: order.address,
                    );

                    if (navUrl == null) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(navUrl),
                              mode: LaunchMode.externalApplication),
                          icon: const AppIcon(PhosphorIcons.navigationArrowBold,
                              size: 16),
                          label: const Text('تتبع موقع العميل على الخريطة'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimaryOrange,
                            side: const BorderSide(
                                color: kPrimaryOrange, width: 1.2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Merchant Details Checklist
          if (order.orderDetails != null && order.orderDetails!.isNotEmpty)
            ...order.orderDetails!
                .map((merchant) => MerchentOrderDetails(merchant, order.id!))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 16, color: kCharcoalMuted),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(fontSize: 13, color: kCharcoalMuted)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kCharcoalDark),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:app_jtak_warehouse/src/config/constants/constants.dart';
import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/enums/order_details_status_enum.dart';
import 'package:app_jtak_warehouse/src/core/enums/payment_method_enum.dart';
import 'package:app_jtak_warehouse/src/core/models/order_model.dart';
import 'package:app_jtak_warehouse/src/ui/pages/order/order_widgets.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/price_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/dotted_separater.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/messages.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/opposite_icon.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/lunch_url.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrderDetailsPage extends StatefulWidget {
  static const String routeName = '/OrderDetailsPage';
  final OrderModel order;
  const OrderDetailsPage(this.order, {Key? key}) : super(key: key);

  @override
  _OrderDetailsPageState createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  Timer? _refreshTimer;
  bool _isPeriodicRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      provider.setOrderObject(widget.order);
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      if (_isPeriodicRefreshing) return;
      final provider = Provider.of<OrderProvider>(context, listen: false);
      if (widget.order.id != null) {
        _isPeriodicRefreshing = true;
        try {
          await provider.loadOrder(widget.order.id!, isSilent: true);
        } catch (_) {
        } finally {
          if (mounted) {
            _isPeriodicRefreshing = false;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final activeOrder = provider.order ?? widget.order;
    final status = provider.getOrderStatus(activeOrder);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(
          'تفاصيل الطلب #${activeOrder.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: _buildStatusBadge(status),
          ),
        ],
      ),
      body: FullScreenLoading(
        inAsyncCall: provider.isBusy && provider.orderIsEmpty(),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              if (status == OrderDetailsStatus.merchantAccepted) ...[
                _buildKitchenLiveCard(activeOrder, provider),
                const SizedBox(height: 12),
              ],
              _buildCustomerCard(activeOrder),
              if (activeOrder.deliveryUser != null || activeOrder.deliveryUserPhone != null) ...[
                const SizedBox(height: 12),
                _buildCourierCard(activeOrder, status),
              ],
              if ((activeOrder.description != null && activeOrder.description!.isNotEmpty) ||
                  (activeOrder.notes != null && activeOrder.notes!.isNotEmpty)) ...[
                const SizedBox(height: 12),
                _buildNotesCard(activeOrder),
              ],
              const SizedBox(height: 16),
              _buildItemsHeader(activeOrder),
              const SizedBox(height: 8),
              if (activeOrder.orderDetails != null)
                ...activeOrder.orderDetails!.map((e) => OrderDetailsSingleItem(e)).toList(),
              const SizedBox(height: 16),
              _buildFinancialSummary(activeOrder),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(activeOrder, status, provider),
    );
  }

  Widget _buildStatusBadge(OrderDetailsStatus status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;
    String text = status.value;

    switch (status) {
      case OrderDetailsStatus.pending:
        bg = JtakColors.primary.withValues(alpha: 0.12);
        fg = JtakColors.primary;
        text = 'جديد';
        break;
      case OrderDetailsStatus.merchantAccepted:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        text = 'قيد التحضير';
        break;
      case OrderDetailsStatus.readyForPickup:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        text = 'جاهز للمندوب';
        break;
      case OrderDetailsStatus.shipping:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        text = 'مع المندوب';
        break;
      case OrderDetailsStatus.delivered:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        text = 'مكتمل';
        break;
      case OrderDetailsStatus.merchantRejected:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        text = 'مرفوض';
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildKitchenLiveCard(OrderModel activeOrder, OrderProvider provider) {
    final deadline = provider.getPrepDeadline(activeOrder.id ?? 0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: OppositeIcon(Icons.kitchen, color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مؤقت التحضير المباشر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('الوقت المتبقي لتسليم الطلب للمندوب', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
          PrepCountdownWidget(deadline: deadline),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(OrderModel activeOrder) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: const OppositeIcon(Icons.person, size: 18, color: Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    activeOrder.user ?? 'بيانات العميل',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              if (activeOrder.phonenumber != null && activeOrder.phonenumber!.isNotEmpty)
                ElevatedButton.icon(
                  icon: const OppositeIcon(Icons.phone, size: 14, color: Colors.white),
                  label: const Text('اتصال', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => LunchUrl.canLaunch('tel:${activeOrder.phonenumber}'),
                ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F1F1)),
          if (activeOrder.phonenumber != null && activeOrder.phonenumber!.isNotEmpty) ...[
            Row(
              children: [
                const OppositeIcon(Icons.phone_android, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  activeOrder.phonenumber!,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (activeOrder.address != null && activeOrder.address!.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OppositeIcon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeOrder.address!,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const OppositeIcon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'تاريخ الطلب: ${GlobalVar.dateForamt(activeOrder.createdDate ?? activeOrder.purchaseDate, kDateTimeFormat) ?? ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourierCard(OrderModel activeOrder, OrderDetailsStatus status) {
    final hasValidPhone = activeOrder.deliveryUserPhone != null &&
        activeOrder.deliveryUserPhone!.trim().isNotEmpty;
    final hasCourierName = activeOrder.deliveryUser != null &&
        activeOrder.deliveryUser!.trim().isNotEmpty;

    final String courierTitle = hasCourierName
        ? activeOrder.deliveryUser!.trim()
        : 'مندوب التوصيل';

    final String courierSubtitle;
    switch (status) {
      case OrderDetailsStatus.pending:
      case OrderDetailsStatus.customerPending:
      case OrderDetailsStatus.merchantAccepted:
      case OrderDetailsStatus.readyForPickup:
        courierSubtitle = 'جارٍ انتظار قبول المندوب';
        break;
      case OrderDetailsStatus.shipping:
        courierSubtitle = 'الطلب في طريقه إلى العميل مع المندوب';
        break;
      case OrderDetailsStatus.delivered:
        courierSubtitle = 'تم تسليم الطلب للعميل بنجاح';
        break;
      case OrderDetailsStatus.merchantRejected:
        courierSubtitle = 'تم رفض الطلب من المتجر';
        break;
      case OrderDetailsStatus.customerCanceled:
      case OrderDetailsStatus.deliveryCanceled:
        courierSubtitle = 'تم إلغاء الطلب';
        break;
    }

    final bool showCallButton = hasValidPhone &&
        (status == OrderDetailsStatus.readyForPickup || status == OrderDetailsStatus.shipping);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
            child: const OppositeIcon(Icons.delivery_dining, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courierTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  courierSubtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (showCallButton)
            ElevatedButton.icon(
              icon: const OppositeIcon(Icons.phone, size: 14, color: Colors.white),
              label: const Text('اتصال بالمندوب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () => LunchUrl.canLaunch('tel:${activeOrder.deliveryUserPhone}'),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(OrderModel activeOrder) {
    final note = (activeOrder.description != null && activeOrder.description!.isNotEmpty)
        ? activeOrder.description!
        : (activeOrder.notes ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OppositeIcon(Icons.notes_rounded, color: Colors.amber.shade900, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ملاحظات خاصة من العميل:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsHeader(OrderModel activeOrder) {
    final count = activeOrder.orderDetails?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'محتويات الفاتورة ($count أصناف)',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
      ),
    );
  }

  Widget _buildFinancialSummary(OrderModel activeOrder) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الملخص المالي',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Divider(height: 20, color: Color(0xFFF1F1F1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('طريقة الدفع', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activeOrder.paymentMethod?.value ?? 'نقداً عند الاستلام',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المجموع الكلي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              PriceTextWidget.small(
                price: activeOrder.price,
                currencyIntegerStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryOrange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(OrderModel activeOrder, OrderDetailsStatus status, OrderProvider provider) {
    if (status == OrderDetailsStatus.pending) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: () {
                  showRejectOrderSheet(context, activeOrder, (reason) async {
                    try {
                      await provider.rejectOrder(activeOrder, reason: reason);
                      Navigator.pop(context);
                    } catch (e) {
                      showDialog(context: context, builder: (_) => CustomDialog(message: e.toString()));
                    }
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('رفض الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: ElevatedButton.icon(
                icon: const OppositeIcon(Icons.check_circle_outline, size: 20, color: Colors.white),
                label: const Text('قبول وبدء التحضير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                onPressed: () {
                  showAcceptPrepTimeSheet(context, activeOrder, (prepMinutes) async {
                    try {
                      await provider.acceptOrder(activeOrder, prepMinutes: prepMinutes);
                    } catch (e) {
                      showDialog(context: context, builder: (_) => CustomDialog(message: e.toString()));
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: JtakColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (status == OrderDetailsStatus.merchantAccepted) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3)),
          ],
        ),
        child: ElevatedButton.icon(
          icon: const OppositeIcon(Icons.check_circle, size: 20, color: Colors.white),
          label: const Text('جاهز للتسليم للمندوب 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () async {
            try {
              await provider.markOrderReady(activeOrder);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إرسال إشعار للمندوب بأن الطلب جاهز للتسليم!'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              showDialog(context: context, builder: (_) => CustomDialog(message: e.toString()));
            }
          },
        ),
      );
    }

    if (status == OrderDetailsStatus.shipping &&
        activeOrder.deliveryUserPhone != null &&
        activeOrder.deliveryUserPhone!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3)),
          ],
        ),
        child: ElevatedButton.icon(
          icon: const OppositeIcon(Icons.phone, size: 20, color: Colors.white),
          label: Text(
            'اتصال بالمندوب (${activeOrder.deliveryUser ?? ''})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () => LunchUrl.canLaunch('tel:${activeOrder.deliveryUserPhone}'),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

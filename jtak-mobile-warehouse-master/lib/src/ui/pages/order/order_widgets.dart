import 'dart:async';
import 'package:app_jtak_warehouse/src/config/constants/constants.dart';
import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/enums/order_details_status_enum.dart';
import 'package:app_jtak_warehouse/src/core/enums/payment_method_enum.dart';
import 'package:app_jtak_warehouse/src/core/models/order_details_model.dart';
import 'package:app_jtak_warehouse/src/core/models/order_model.dart';
import 'package:app_jtak_warehouse/src/ui/pages/order/order_details_page.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/price_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/image_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/messages.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/opposite_icon.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/lunch_url.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../main_imports.dart';

// ---------------------------------------------------------------------------
// Pulsing Orange Border for Urgent / New Pending Orders
// ---------------------------------------------------------------------------
class PulsingBorderWidget extends StatefulWidget {
  final Widget child;
  const PulsingBorderWidget({Key? key, required this.child}) : super(key: key);

  @override
  _PulsingBorderWidgetState createState() => _PulsingBorderWidgetState();
}

class _PulsingBorderWidgetState extends State<PulsingBorderWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: JtakColors.primary.withValues(alpha: 0.45 + (_animation.value - 1.0) * 0.45),
              width: _animation.value,
            ),
            boxShadow: [
              BoxShadow(
                color: JtakColors.primary.withValues(alpha: 0.10 * _animation.value),
                blurRadius: 8 * _animation.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Live Kitchen Prep Countdown Timer
// ---------------------------------------------------------------------------
class PrepCountdownWidget extends StatefulWidget {
  final DateTime? deadline;
  const PrepCountdownWidget({Key? key, this.deadline}) : super(key: key);

  @override
  _PrepCountdownWidgetState createState() => _PrepCountdownWidgetState();
}

class _PrepCountdownWidgetState extends State<PrepCountdownWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deadline == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OppositeIcon(Icons.kitchen_outlined, size: 14, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Text(
              'قيد التحضير بالمطبخ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
            ),
          ],
        ),
      );
    }

    final diff = widget.deadline!.difference(DateTime.now());
    final isOverdue = diff.isNegative;
    final totalSecs = diff.inSeconds.abs();
    final mins = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSecs % 60).toString().padLeft(2, '0');

    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String label;

    if (isOverdue) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      icon = Icons.warning_amber_rounded;
      label = 'متأخر: -$mins:$secs دقيقة';
    } else if (diff.inMinutes < 5) {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade900;
      icon = Icons.local_fire_department_rounded;
      label = 'متبقي: $mins:$secs دقيقة';
    } else {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
      icon = Icons.timer_rounded;
      label = 'متبقي: $mins:$secs دقيقة';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OppositeIcon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Accept Modal with Prep Time Selection
// ---------------------------------------------------------------------------
void showAcceptPrepTimeSheet(BuildContext context, OrderModel order, Function(int) onAccept) {
  int selectedMinutes = 25;
  final customController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: JtakColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const OppositeIcon(Icons.restaurant, color: JtakColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('قبول الطلب #${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text('حدد الوقت التقديري لتجهيز الطلب في المطبخ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [15, 25, 35, 45, 60].map((mins) {
                    final isSelected = selectedMinutes == mins;
                    return ChoiceChip(
                      label: Text('$mins دقيقة'),
                      selected: isSelected,
                      selectedColor: JtakColors.primary,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setModalState(() {
                            selectedMinutes = mins;
                            customController.clear();
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: customController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'أو أدخل وقتاً مخصصاً (بالدقائق)...',
                    prefixIcon: const OppositeIcon(Icons.access_time_outlined, size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (val) {
                    final custom = int.tryParse(val);
                    if (custom != null && custom > 0) {
                      setModalState(() {
                        selectedMinutes = custom;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onAccept(selectedMinutes);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JtakColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'تأكيد القبول ($selectedMinutes دقيقة) وبدء التحضير',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Quick Reject Modal with Reason Selection
// ---------------------------------------------------------------------------
void showRejectOrderSheet(BuildContext context, OrderModel order, Function(String) onReject) {
  final reasons = [
    'المكونات غير متوفرة حالياً',
    'ضغط عمل مرتفع في المطبخ',
    'المتجر مغلق أو انتهت ساعات العمل',
    'الموقع خارج نطاق التوصيل',
    'سبب آخر',
  ];
  String selectedReason = reasons.first;
  final otherController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: OppositeIcon(Icons.cancel_outlined, color: Colors.red.shade600, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('رفض الطلب #${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                          const Text('يرجى تحديد سبب الرفض لتحديث حالة الطلب', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...reasons.map((r) {
                  return RadioListTile<String>(
                    value: r,
                    groupValue: selectedReason,
                    title: Text(r, style: const TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: Colors.red,
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedReason = val;
                        });
                      }
                    },
                  );
                }).toList(),
                if (selectedReason == 'سبب آخر') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: otherController,
                    decoration: InputDecoration(
                      hintText: 'اكتب سبب الرفض بالتفصيل...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final finalReason = selectedReason == 'سبب آخر' && otherController.text.trim().isNotEmpty
                        ? otherController.text.trim()
                        : selectedReason;
                    Navigator.pop(ctx);
                    onReject(finalReason);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'تأكيد رفض الطلب',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Modern Order Kanban Card (Used in all 4 tabs)
// ---------------------------------------------------------------------------
class OrderSingleItem extends StatelessWidget {
  final OrderModel item;
  const OrderSingleItem(this.item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final status = provider.getOrderStatus(item);
    final isNew = status == OrderDetailsStatus.pending;

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.navigateName(OrderDetailsPage.routeName, data: item);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, status, provider),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),
                _buildCustomerRow(context),
                if ((item.notes != null && item.notes!.trim().isNotEmpty) ||
                    (item.description != null && item.description!.trim().isNotEmpty)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OppositeIcon(Icons.speaker_notes_outlined, size: 14, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'ملاحظة: ${item.notes?.isNotEmpty == true ? item.notes : item.description}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (item.orderDetails != null && item.orderDetails!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildItemsSection(context, status, provider),
                ],
                const SizedBox(height: 14),
                _buildActionBar(context, status, provider),
              ],
            ),
          ),
        ),
      ),
    );

    if (isNew) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: PulsingBorderWidget(child: cardContent),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: cardContent,
    );
  }

  String _formatRelativeTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());
    if (diff.inSeconds < 45) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return GlobalVar.dateForamt(dt, 'yyyy/MM/dd HH:mm') ?? '';
  }

  Widget _buildHeader(BuildContext context, OrderDetailsStatus status, OrderProvider provider) {
    final relTime = _formatRelativeTime(item.createdDate ?? item.purchaseDate);
    final isCash = item.paymentMethod == PaymentMethod.payOnDelivery;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '#${item.id}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(width: 8),
            if (relTime.isNotEmpty) ...[
              const OppositeIcon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 3),
              Text(
                relTime,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCash ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCash ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                  width: 0.8,
                ),
              ),
              child: Text(
                isCash ? '💵 نقداً' : '💳 إلكتروني',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isCash ? const Color(0xFF065F46) : const Color(0xFF1D4ED8),
                ),
              ),
            ),
          ],
        ),
        _buildStatusBadge(status),
      ],
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
        text = 'طلب جديد ⚡';
        break;
      case OrderDetailsStatus.merchantAccepted:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        text = 'قيد التحضير 🍳';
        break;
      case OrderDetailsStatus.readyForPickup:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        text = 'جاهز للمندوب ✅';
        break;
      case OrderDetailsStatus.shipping:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        text = 'مع المندوب 🛵';
        break;
      case OrderDetailsStatus.delivered:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        text = 'مكتمل ✅';
        break;
      case OrderDetailsStatus.merchantRejected:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        text = 'مرفوض ✖';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
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

  Widget _buildCustomerRow(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: const OppositeIcon(Icons.person_outline, color: Colors.black54, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.user ?? 'عميل JTAK',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.address != null && item.address!.isNotEmpty)
                Text(
                  item.address!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (item.phonenumber != null && item.phonenumber!.isNotEmpty)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const OppositeIcon(Icons.phone, size: 16, color: Colors.green),
            ),
            tooltip: 'اتصال بالعميل',
            onPressed: () => LunchUrl.canLaunch('tel:${item.phonenumber}'),
          ),
        PriceTextWidget.small(
          price: item.price,
          currencyIntegerStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildItemsSection(BuildContext context, OrderDetailsStatus status, OrderProvider provider) {
    final items = item.orderDetails!;
    final isPreparing = status == OrderDetailsStatus.merchantAccepted;
    final pickedCount = items.where((d) => d.isPicked).length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    isPreparing ? 'عناصر الطلب ($pickedCount/${items.length})' : 'عناصر الطلب (${items.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  if (isPreparing && pickedCount == items.length && items.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'مكتمل ✓',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ],
              ),
              if (isPreparing)
                Text(
                  'اضغط للتحقق من التجهيز',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.take(isPreparing ? items.length : 3).map((detail) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: isPreparing ? () => provider.toggleItemChecklist(item.id ?? 0, detail.id ?? 0) : null,
                child: Row(
                  children: [
                    if (isPreparing)
                      OppositeIcon(
                        detail.isPicked ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 18,
                        color: detail.isPicked ? Colors.green : Colors.grey,
                      ),
                    if (isPreparing) const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kPrimaryOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${detail.quantity}x',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kPrimaryOrange),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detail.productTitle ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: (isPreparing && detail.isPicked) ? TextDecoration.lineThrough : null,
                          color: (isPreparing && detail.isPicked) ? Colors.grey : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PriceTextWidget.small(
                      price: detail.singleFinalPrice,
                      currencyIntegerStyle: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          if (!isPreparing && items.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${items.length - 3} عناصر أخرى...',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, OrderDetailsStatus status, OrderProvider provider) {
    if (status == OrderDetailsStatus.pending) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: () {
                showRejectOrderSheet(context, item, (reason) async {
                  try {
                    await provider.rejectOrder(item, reason: reason);
                  } catch (e) {
                    showDialog(context: context, builder: (_) => CustomDialog(message: e.toString()));
                  }
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('رفض', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: ElevatedButton.icon(
              icon: const OppositeIcon(Icons.check_circle_outline, size: 18, color: Colors.white),
              label: const Text('قبول وتحديد الوقت', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: () {
                showAcceptPrepTimeSheet(context, item, (prepMinutes) async {
                  try {
                    await provider.acceptOrder(item, prepMinutes: prepMinutes);
                  } catch (e) {
                    showDialog(context: context, builder: (_) => CustomDialog(message: e.toString()));
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: JtakColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }

    if (status == OrderDetailsStatus.merchantAccepted) {
      final deadline = provider.getPrepDeadline(item.id ?? 0);
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PrepCountdownWidget(deadline: deadline),
              ElevatedButton.icon(
                icon: const OppositeIcon(Icons.check_circle, size: 16, color: Colors.white),
                label: const Text('جاهز للتسليم', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () async {
                  try {
                    await provider.markOrderReady(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إرسال إشعار للمندوب بأن الطلب جاهز للتسليم!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    showDialog(context: context, builder: (_) => CustomDialog(message: e.toString()));
                  }
                },
              ),
            ],
          ),
        ],
      );
    }

    if (status == OrderDetailsStatus.shipping) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.amber.shade50.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            const OppositeIcon(Icons.delivery_dining, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.deliveryUser != null && item.deliveryUser!.isNotEmpty
                        ? 'المندوب: ${item.deliveryUser}'
                        : 'جاري تسليم الطلب للمندوب',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Text('الطلب في طريقه إلى العميل', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            if (item.deliveryUserPhone != null && item.deliveryUserPhone!.isNotEmpty)
              ElevatedButton.icon(
                icon: const OppositeIcon(Icons.phone, size: 14, color: Colors.white),
                label: const Text('المندوب', style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => LunchUrl.canLaunch('tel:${item.deliveryUserPhone}'),
              ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          item.deliveryUser != null ? 'توصيل: ${item.deliveryUser}' : 'طلب منتهي',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const Text(
          'عرض التفاصيل >',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: JtakColors.primary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Order Details Single Item (Used inside OrderDetailsPage and warehouse inspection)
// ---------------------------------------------------------------------------
class OrderDetailsSingleItem extends StatelessWidget {
  final OrderDetailsModel item;
  const OrderDetailsSingleItem(this.item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _image(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productTitle ?? '', maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (item.productUnit != null && item.productUnit!.isNotEmpty) ...[
                      Text(item.productUnit!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const Text(' • '),
                    ],
                    PriceTextWidget.small(
                      price: item.singleFinalPrice,
                      currencyIntegerStyle: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ],
                ),
                if (item.locationBin != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '📍 ${item.locationBin}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown.shade800),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kPrimaryOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.quantity}x',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kPrimaryOrange),
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(height: 4),
              PriceTextWidget.small(
                price: item.totalFinalPrice,
                currencyIntegerStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _image() {
    const double size = 48;
    if (GlobalVar.checkString(item.productImage)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ImageView(item.productImage!.split(',').first, height: size, width: size),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(kNoImage, height: size, width: size, fit: BoxFit.cover),
    );
  }
}

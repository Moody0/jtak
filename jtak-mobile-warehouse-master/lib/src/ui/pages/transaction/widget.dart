import 'package:app_jtak_warehouse/src/config/constants/app_constant.dart';
import 'package:app_jtak_warehouse/src/config/constants/constants.dart';
import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/payment_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/transactions_provider.dart';
import 'package:app_jtak_warehouse/src/core/enums/payment_method_enum.dart';
import 'package:app_jtak_warehouse/src/core/models/bill_model.dart';
import 'package:app_jtak_warehouse/src/core/models/order_model.dart';
import 'package:app_jtak_warehouse/src/core/models/payment_model.dart';
import 'package:app_jtak_warehouse/src/core/services/authentication_service.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/ui/pages/order/order_details_page.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/messages.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/lunch_url.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/phone_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

/// ---------------------------------------------------------------------------
/// Shared Price Formatter (Thousands Separators, e.g. 1,250,000)
/// ---------------------------------------------------------------------------
String formatPrice(num? amount) {
  if (amount == null) return '0';
  final formatter = NumberFormat('#,###', 'en_US');
  return formatter.format(amount.round());
}

/// ---------------------------------------------------------------------------
/// Flipped Icon (Horizontally Mirrored so it faces the opposite direction)
/// ---------------------------------------------------------------------------
class FlippedIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;

  const FlippedIcon(this.icon, {Key? key, this.color, this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: true,
      child: Icon(icon, color: color, size: size),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Modern Merchant Payment / Payout Card Widget
/// ---------------------------------------------------------------------------
class PaymentSingleItem extends StatelessWidget {
  final PaymentModel item;
  final VoidCallback? onReceiptConfirmed;

  const PaymentSingleItem(this.item, {Key? key, this.onReceiptConfirmed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isReceived = item.isReceived;
    final title = item.requestNumber != null
        ? 'طلب تسوية ${item.requestNumber}'
        : (item.id != null ? 'دفعة تسوية #${item.id}' : 'دفعة تسوية');
    final dateString = item.completedAt ?? item.handoverDate ?? item.reviewedAt ?? item.createdDate;

    String statusLabel;
    Color statusBg;
    Color statusBorder;
    Color statusText;
    Color statusDot;

    if (isReceived) {
      statusLabel = 'تم الاستلام';
      statusBg = const Color(0xFFDCFCE7);
      statusBorder = const Color(0xFF86EFAC);
      statusText = const Color(0xFF15803D);
      statusDot = const Color(0xFF16A34A);
    } else if (item.status == 0) {
      statusLabel = 'قيد المراجعة';
      statusBg = const Color(0xFFFEF3C7);
      statusBorder = const Color(0xFFFCD34D);
      statusText = const Color(0xFFB45309);
      statusDot = const Color(0xFFD97706);
    } else if (item.status == 2) {
      statusLabel = 'مرفوض';
      statusBg = const Color(0xFFFEE2E2);
      statusBorder = const Color(0xFFFCA5A5);
      statusText = const Color(0xFFB91C1C);
      statusDot = const Color(0xFFDC2626);
    } else {
      statusLabel = 'قيد التسليم';
      statusBg = const Color(0xFFFFF7ED);
      statusBorder = const Color(0xFFFFEDD5);
      statusText = const Color(0xFFC2410C);
      statusDot = const Color(0xFFEA580C);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showReceiptDetailsSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isReceived ? const Color(0xFFE2E8F0) : const Color(0xFFFFD6C2),
              width: isReceived ? 1.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Payout ID & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isReceived ? const Color(0xFFDCFCE7) : const Color(0xFFFFF0E8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: FlippedIcon(
                              isReceived ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.clock,
                              size: 18,
                              color: isReceived ? const Color(0xFF16A34A) : kPrimaryOrange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                if (dateString != null)
                                  Text(
                                    GlobalVar.dateForamt(dateString, kDateTimeFormat) ?? "",
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10.5,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusDot,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // Amount & Actions Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المبلغ المسلّم للمتجر',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatPrice(item.amount),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ل.س',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (!isReceived && item.status != 0 && item.status != 2)
                      ElevatedButton.icon(
                        onPressed: () => _confirmReceiptWithDialog(context),
                        icon: const FlippedIcon(PhosphorIconsBold.check, size: 14),
                        label: const Text('تأكيد الاستلام'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          textStyle: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (item.byUser != null && item.byUser!.isNotEmpty)
                      Row(
                        children: [
                          const FlippedIcon(PhosphorIconsRegular.user, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            'المسلّم: ${item.byUser}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
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

  void _showReceiptDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PayoutReceiptSheet(
        payment: item,
        onConfirmReceipt: (!item.isReceived && item.status != 0 && item.status != 2)
            ? () {
                Navigator.pop(ctx);
                _confirmReceiptWithDialog(context);
              }
            : null,
      ),
    );
  }

  void _confirmReceiptWithDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    final formattedAmount = formatPrice(item.amount);
    final courierName = item.byUser ?? 'إدارة جيتك';
    final refNumber = item.requestNumber ?? (item.id != null ? '#${item.id}' : '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const FlippedIcon(PhosphorIconsFill.shieldCheck, color: kPrimaryOrange, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'تأكيد استلام الدفعة',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل استلمت بالفعل هذا المبلغ من الإدارة / المندوب؟',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المبلغ المطلوب تأكيده:',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        '$formattedAmount ل.س',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                  if (refNumber.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'رقم الطلب / الإيصال:',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        Text(
                          refNumber,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'طريقة التسليم:',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        courierName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ملاحظة: تأكيد الاستلام سيقوم بتحديث الحسابات وتوثيق تسليم المبلغ نهائياً.',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF94A3B8), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _executeReceipt(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'نعم، استلمت المبلغ',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeReceipt(BuildContext context) async {
    HapticFeedback.mediumImpact();
    try {
      final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
      bool success = false;
      if (item.isSettlementRequest && item.requestId != null) {
        success = await paymentProvider.confirmSettlementReceipt(item.requestId!);
      } else if (item.id != null) {
        success = await paymentProvider.recivePayment(item.id!);
      }

      if (success && context.mounted) {
        try {
          await Provider.of<TransactionsProvider>(context, listen: false).loadBalances();
        } catch (_) {}

        onReceiptConfirmed?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const FlippedIcon(PhosphorIconsFill.checkCircle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'تم تأكيد استلام الدفعة وتحديث الرصيد بنجاح!',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'تعذر تأكيد الاستلام: $e',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    }
  }
}

/// ---------------------------------------------------------------------------
/// Modern Merchant Order Bill / Settlement Card Widget
/// ---------------------------------------------------------------------------
class BillSingleItem extends StatelessWidget {
  final BillModel item;
  const BillSingleItem(this.item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final paymentTitle = _getPaymentMethodLabel(item.paymentMethod);
    final isCash = item.paymentMethod == PaymentMethod.payOnDelivery;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBillDetailsSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Order ID & Payment Method Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFD6C2)),
                          ),
                          child: Text(
                            'طلب #${item.orderId ?? ""}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kPrimaryOrange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'فاتورة #${item.id ?? ""}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCash ? const Color(0xFFF8FAFC) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCash ? const Color(0xFFCBD5E1) : const Color(0xFFBFDBFE),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FlippedIcon(
                            isCash ? PhosphorIconsRegular.money : PhosphorIconsRegular.creditCard,
                            size: 12,
                            color: isCash ? const Color(0xFF475569) : const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            paymentTitle,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCash ? const Color(0xFF475569) : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),

                // Breakdown Row: Net Merchant Earnings vs Total Customer Order Value
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Merchant Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مستحقات المتجر من الطلب',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '+${formatPrice(item.merchantAmount)}',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ل.س',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Total Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'إجمالي الطلب بالكامل',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatPrice(item.totalAmount)} ل.س',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Date & View Details hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تاريخ الفاتورة: ${GlobalVar.dateForamt(item.createdDate ?? item.dueDate, kDateTimeFormat) ?? ""}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'عرض التفاصيل',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kPrimaryOrange,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const FlippedIcon(PhosphorIconsBold.caretLeft, size: 12, color: kPrimaryOrange),
                      ],
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

  void _showBillDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InvoiceDetailsSheet(bill: item),
    );
  }

  String _getPaymentMethodLabel(PaymentMethod? method) {
    if (method == PaymentMethod.creditCardPayment) return 'إلكتروني / سيريتل كاش';
    if (method == PaymentMethod.payOnDelivery) return 'نقداً عند الاستلام';
    return 'غير محدد';
  }
}

/// ---------------------------------------------------------------------------
/// Invoice Details Bottom Sheet (Voucher & Order Navigation)
/// ---------------------------------------------------------------------------
class InvoiceDetailsSheet extends StatefulWidget {
  final BillModel bill;
  const InvoiceDetailsSheet({Key? key, required this.bill}) : super(key: key);

  @override
  State<InvoiceDetailsSheet> createState() => _InvoiceDetailsSheetState();
}

class _InvoiceDetailsSheetState extends State<InvoiceDetailsSheet> {
  bool _isLoadingOrder = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final total = b.totalAmount ?? 0;
    final net = b.merchantAmount ?? 0;
    final commission = total - net;
    final isCash = b.paymentMethod == PaymentMethod.payOnDelivery;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FlippedIcon(PhosphorIconsFill.receipt, color: kPrimaryOrange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'تفاصيل الفاتورة المالية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const FlippedIcon(PhosphorIconsRegular.x, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reference Tags
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('فاتورة رقم: ', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B))),
                    Text(
                      '#${b.id ?? ""}',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 12),
                    Text('طلب رقم: ', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B))),
                    Text(
                      '#${b.orderId ?? ""}',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimaryOrange),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: 'فاتورة #${b.id} لطلب #${b.orderId}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ بيانات الفاتورة!'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: Row(
                    children: [
                      const FlippedIcon(PhosphorIconsRegular.copy, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text('نسخ', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Breakdown Card
          Text(
            'تفصيل المبالغ المالية',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildModalRow('إجمالي قيمة الطلب للزبون', '${formatPrice(total)} ل.س', const Color(0xFF0F172A)),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildModalRow(
                  'عمولة ورسوم الخدمة',
                  commission > 0 ? '-${formatPrice(commission)} ل.س' : '0 ل.س',
                  const Color(0xFFEF4444),
                ),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildModalRow(
                  'صافي مستحقات المتجر',
                  '+${formatPrice(net)} ل.س',
                  const Color(0xFF16A34A),
                  isBold: true,
                  fontSize: 15,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Metadata Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('طريقة الدفع:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B))),
                    Text(
                      isCash ? 'نقداً عند الاستلام' : 'إلكتروني / سيريتل كاش',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                    ),
                  ],
                ),
                if (b.createdDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('تاريخ الإنشاء:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B))),
                      Text(
                        GlobalVar.dateForamt(b.createdDate, kDateTimeFormat) ?? "",
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF475569)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Action Button: View Full Order Details
          if (b.orderId != null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoadingOrder ? null : () => _navigateToOrder(context, b.orderId!),
                icon: _isLoadingOrder
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const FlippedIcon(PhosphorIconsBold.package, size: 18),
                label: Text(
                  _isLoadingOrder ? 'جارٍ تحميل الطلب...' : 'عرض تفاصيل الطلب الأصلي #${b.orderId}',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModalRow(String label, String value, Color valueColor, {bool isBold = false, double fontSize = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: const Color(0xFF64748B))),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToOrder(BuildContext context, int orderId) async {
    setState(() => _isLoadingOrder = true);
    try {
      final api = locator<SolApi>();
      final data = await api.getRequest('/Orders/$orderId');
      if (data != null && data is Map<String, dynamic> && context.mounted) {
        final order = OrderModel.fromMap(data);
        Navigator.pop(context); // Close sheet
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailsPage(order)),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل تفاصيل الطلب حالياً')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الطلب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingOrder = false);
    }
  }
}

/// ---------------------------------------------------------------------------
/// Payout Receipt Bottom Sheet (Detailed Settlement Voucher)
/// ---------------------------------------------------------------------------
class PayoutReceiptSheet extends StatelessWidget {
  final PaymentModel payment;
  final VoidCallback? onConfirmReceipt;

  const PayoutReceiptSheet({Key? key, required this.payment, this.onConfirmReceipt}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isReceived = payment.handoverDate != null;
    final formattedAmount = formatPrice(payment.amount);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isReceived ? const Color(0xFFDCFCE7) : const Color(0xFFFFF0E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FlippedIcon(
                      isReceived ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.clock,
                      color: isReceived ? const Color(0xFF16A34A) : kPrimaryOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'إيصال تسوية مالية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const FlippedIcon(PhosphorIconsRegular.x, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount Card (Hero in Sheet)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isReceived
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [const Color(0xFF9A3412), const Color(0xFFC2410C)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'المبلغ المسلّم للمتجر',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formattedAmount,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ل.س',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isReceived ? '✓ تم الاستلام والتوثيق' : '⏳ قيد التسليم للمحل',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Voucher Details Table
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildVoucherRow('رقم طلب / دفعة التسوية:', payment.requestNumber ?? (payment.id != null ? '#${payment.id}' : '')),
                if (payment.method != null && payment.method!.isNotEmpty) ...[
                  const Divider(height: 14, color: Color(0xFFE2E8F0)),
                  _buildVoucherRow('طريقة الصرف:', payment.method!),
                ],
                if (payment.accountDetails != null && payment.accountDetails!.isNotEmpty) ...[
                  const Divider(height: 14, color: Color(0xFFE2E8F0)),
                  _buildVoucherRow('تفاصيل الحساب:', payment.accountDetails!),
                ],
                if (payment.byUser != null && payment.byUser!.isNotEmpty) ...[
                  const Divider(height: 14, color: Color(0xFFE2E8F0)),
                  _buildVoucherRow('المسلّم / الجهة المسؤولة:', payment.byUser!),
                ],
                if (payment.reviewedAt != null) ...[
                  const Divider(height: 14, color: Color(0xFFE2E8F0)),
                  _buildVoucherRow('تاريخ الموافقة والاعتماد:', GlobalVar.dateForamt(payment.reviewedAt, kDateTimeFormat) ?? ""),
                ],
                if (payment.completedAt != null || payment.handoverDate != null) ...[
                  const Divider(height: 14, color: Color(0xFFE2E8F0)),
                  _buildVoucherRow('تاريخ ووقت الاستلام:', GlobalVar.dateForamt(payment.completedAt ?? payment.handoverDate, kDateTimeFormat) ?? ""),
                ],
                if (payment.newBalance != null) ...[
                  const Divider(height: 14, color: Color(0xFFE2E8F0)),
                  _buildVoucherRow('الرصيد بعد الدفعة:', '${formatPrice(payment.newBalance)} ل.س'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Action button
          if (!isReceived && onConfirmReceipt != null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onConfirmReceipt,
                icon: const FlippedIcon(PhosphorIconsBold.check, size: 18),
                label: const Text('تأكيد استلام الدفعة الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  final ref = payment.requestNumber ?? (payment.id != null ? '#${payment.id}' : '');
                  final text = 'إيصال تسوية $ref بمبلغ $formattedAmount ل.س (${isReceived ? "تم الاستلام" : "قيد التسليم"})';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ بيانات الإيصال!'), duration: Duration(seconds: 1)),
                  );
                },
                icon: const FlippedIcon(PhosphorIconsRegular.copy, size: 16),
                label: const Text('نسخ بيانات الإيصال'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoucherRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B))),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Settlement Request Bottom Sheet (Request Payout & Backend Settlement API)
/// ---------------------------------------------------------------------------
class SettlementRequestSheet extends StatefulWidget {
  final double availableBalance;
  const SettlementRequestSheet({Key? key, required this.availableBalance}) : super(key: key);

  @override
  State<SettlementRequestSheet> createState() => _SettlementRequestSheetState();
}

class _SettlementRequestSheetState extends State<SettlementRequestSheet> {
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  // Method-specific controllers
  late TextEditingController _syriatelPhoneController;
  late TextEditingController _alHaramNameController;
  late TextEditingController _alHaramPhoneController;
  late TextEditingController _alHaramCityController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankHolderController;
  late TextEditingController _bankIbanController;
  late TextEditingController _cashPhoneController;
  late TextEditingController _cashNoteController;

  int _selectedMethod = 0;
  bool _isSubmitting = false;

  static const List<Map<String, dynamic>> _methods = [
    {
      'key': 'syriatel_cash',
      'title': 'سيريتل كاش (Syriatel Cash)',
      'subtitle': 'تحويل فوري إلى رقم محفظتك الإلكترونية',
      'icon': PhosphorIconsFill.deviceMobile,
    },
    {
      'key': 'sham_cash',
      'title': 'شام كاش (Sham Cash)',
      'subtitle': 'تحويل إلى رقم محفظة شام كاش المعتمد',
      'icon': PhosphorIconsFill.deviceMobile,
    },
    {
      'key': 'al_haram',
      'title': 'حوالة عبر شركة الهرم / الفؤاد',
      'subtitle': 'استلام فوري نقداً بالهوية الشخصية من أي فرع',
      'icon': PhosphorIconsFill.paperPlaneTilt,
    },
    {
      'key': 'bank_transfer',
      'title': 'حساب بنكي معتمد',
      'subtitle': 'تحويل مصرفي (بيمو / البركة / التجاري)',
      'icon': PhosphorIconsFill.bank,
    },
    {
      'key': 'cash_in_store',
      'title': 'تسليم نقدي في المحل',
      'subtitle': 'تسليم مباشر في المتجر عبر كابتن التوصيل',
      'icon': PhosphorIconsFill.storefront,
    },
  ];

  bool get _hasAvailableBalance => widget.availableBalance > 0;

  @override
  void initState() {
    super.initState();
    final initialAmt = _hasAvailableBalance ? widget.availableBalance.toInt().toString() : '';
    _amountController = TextEditingController(text: initialAmt);
    _amountController.addListener(_onAmountChanged);
    _notesController = TextEditingController();

    final userPhone = locator<AuthenticationService>().user?.phoneNumber ?? '';
    _syriatelPhoneController = TextEditingController(text: userPhone);
    _alHaramNameController = TextEditingController();
    _alHaramPhoneController = TextEditingController(text: userPhone);
    _alHaramCityController = TextEditingController();
    _bankNameController = TextEditingController();
    _bankHolderController = TextEditingController();
    _bankIbanController = TextEditingController();
    _cashPhoneController = TextEditingController(text: userPhone);
    _cashNoteController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant SettlementRequestSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableBalance != widget.availableBalance) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _notesController.dispose();
    _syriatelPhoneController.dispose();
    _alHaramNameController.dispose();
    _alHaramPhoneController.dispose();
    _alHaramCityController.dispose();
    _bankNameController.dispose();
    _bankHolderController.dispose();
    _bankIbanController.dispose();
    _cashPhoneController.dispose();
    _cashNoteController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  int _getPresetAmount(double fraction) {
    if (!_hasAvailableBalance) return 0;
    if (fraction >= 1.0) return widget.availableBalance.round();
    return (widget.availableBalance * fraction).round();
  }

  double get _currentEnteredAmount {
    final cleanText = _amountController.text.trim().replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(cleanText) ?? 0.0;
  }

  bool _isPresetSelected(double fraction) {
    if (!_hasAvailableBalance) return false;
    final current = _currentEnteredAmount;
    if (current <= 0) return false;
    final target = _getPresetAmount(fraction).toDouble();
    return (current - target).abs() < 0.01;
  }

  void _setPresetPercentage(double fraction) {
    if (!_hasAvailableBalance) return;
    HapticFeedback.selectionClick();
    final amt = _getPresetAmount(fraction);
    _amountController.text = amt.toString();
    setState(() {});
  }

  Future<void> _submitSettlementRequest(BuildContext context) async {
    if (_isSubmitting) return;

    if (!_hasAvailableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد رصيد متاح للسحب حالياً'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final amt = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال مبلغ صحيح لطلب التسوية'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (amt > widget.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('المبلغ المطلوب (${formatPrice(amt)} ل.س) يتجاوز رصيدك المتاح (${formatPrice(widget.availableBalance)} ل.س)'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final method = _methods[_selectedMethod];
    final methodKey = method['key'] as String;
    final methodTitle = method['title'] as String;
    String accountDetails = '';

    if (methodKey == 'syriatel_cash' || methodKey == 'sham_cash') {
      final phone = _syriatelPhoneController.text.trim();
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى إدخال رقم هاتف محفظة $methodTitle'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        return;
      }
      accountDetails = '$methodTitle: $phone';
    } else if (methodKey == 'al_haram') {
      final name = _alHaramNameController.text.trim();
      final phone = _alHaramPhoneController.text.trim();
      final city = _alHaramCityController.text.trim();
      if (name.isEmpty || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال اسم المستلم الثلاثي ورقم الهاتف لحوالة الهرم'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
      accountDetails = 'حوالة الهرم/الفؤاد | المستلم: $name | هاتف: $phone${city.isNotEmpty ? ' | المحافظة/الفرع: $city' : ''}';
    } else if (methodKey == 'bank_transfer') {
      final bank = _bankNameController.text.trim();
      final holder = _bankHolderController.text.trim();
      final iban = _bankIbanController.text.trim();
      if (bank.isEmpty || holder.isEmpty || iban.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال اسم المصرف، اسم صاحب الحساب، ورقم الحساب/IBAN'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
      accountDetails = 'حساب بنكي | المصرف: $bank | صاحب الحساب: $holder | رقم الحساب/IBAN: $iban';
    } else if (methodKey == 'cash_in_store') {
      final phone = _cashPhoneController.text.trim();
      final note = _cashNoteController.text.trim();
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال رقم هاتف مسؤول المتجر للتنسيق'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
      accountDetails = 'تسليم نقدي في المحل | هاتف التنسيق: $phone${note.isNotEmpty ? ' | التوقيت: $note' : ''}';
    }

    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);

    try {
      final transProvider = Provider.of<TransactionsProvider>(context, listen: false);
      final extraNotes = _notesController.text.trim();
      await transProvider.submitSettlementRequest(
        amount: amt,
        method: methodKey,
        accountDetails: accountDetails,
        notes: extraNotes.isEmpty ? null : extraNotes,
      );

      if (!mounted) return;
      final navigator = Navigator.of(context);
      final parentContext = navigator.context;
      navigator.pop();
      _showSuccessDialog(parentContext, amt, methodTitle);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(CustomDialog.sanitizeMessage(e.toString())),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _showSuccessDialog(BuildContext context, double amount, String methodTitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: FlippedIcon(PhosphorIconsFill.checkCircle, color: Color(0xFF16A34A), size: 34),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تم إرسال طلب السحب بنجاح',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تم تسجيل طلبك لسحب مبلغ ${formatPrice(amount)} ل.س عبر $methodTitle.\n'
                'يقوم قسم المالية والمحاسبة بمراجعة الطلب وتحويل المبلغ في أقرب وقت. يمكنك متابعة السجل المالي عبر تبويب الحركات.',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'حسناً',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _callAccountingSupport() {
    LunchUrl.canLaunch('tel:$kSupportPhone');
  }

  @override
  Widget build(BuildContext context) {
    final formattedAvailable = formatPrice(widget.availableBalance);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const FlippedIcon(PhosphorIconsFill.handCoins, color: kPrimaryOrange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'طلب تسوية وسحب مستحقات',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const FlippedIcon(PhosphorIconsRegular.x, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Available Balance Banner
            if (_hasAvailableBalance)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الرصيد المتاح للسحب الآن',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formattedAvailable,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ل.س',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'متاح للسحب',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(PhosphorIconsFill.warningCircle, color: Color(0xFFD97706), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الرصيد المتاح للسحب الآن',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF78350F)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDE68A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'لا يوجد رصيد متاح',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '0 ل.س',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (!_hasAvailableBalance) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(PhosphorIconsRegular.info, color: Color(0xFF64748B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لا يمكنك إنشاء طلب تسوية حالياً لعدم وجود رصيد متاح في المحفظة. تضاف أرباحك تلقائياً فور اكتمال تسليم الطلبات للزبائن.',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Amount Input Field
            Text(
              'المبلغ المطلوب سحبه (ل.س)',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              enabled: _hasAvailableBalance && !_isSubmitting,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: _hasAvailableBalance ? 'أدخل المبلغ المطلوب' : 'لا يوجد رصيد متاح',
                prefixIcon: const FlippedIcon(PhosphorIconsBold.money, color: kPrimaryOrange, size: 20),
                suffixText: 'ل.س',
                suffixStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                filled: true,
                fillColor: _hasAvailableBalance ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5)),
                disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 10),

            // Preset Quick Amount Chips (only interactive if balance > 0)
            if (_hasAvailableBalance)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildQuickChip('25%', 0.25),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: _buildQuickChip('50%', 0.50),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: _buildQuickChip('75%', 0.75),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: _buildQuickChip('كامل الرصيد (100%)', 1.0),
                  ),
                ],
              ),
            const SizedBox(height: 18),

            // Preferred Method Selector
            Text(
              'طريقة استلام المبلغ المفضلة',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            ...List.generate(_methods.length, (index) {
              final method = _methods[index];
              final isSelected = _selectedMethod == index;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFF0E8) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? kPrimaryOrange : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFECE0) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FlippedIcon(
                        method['icon'] as IconData,
                        color: isSelected ? kPrimaryOrange : const Color(0xFF64748B),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      method['title'] as String,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF9A3412) : const Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: Text(
                      method['subtitle'] as String,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? const Color(0xFFC2410C) : const Color(0xFF64748B),
                      ),
                    ),
                    trailing: FlippedIcon(
                      isSelected ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
                      color: isSelected ? kPrimaryOrange : const Color(0xFFCBD5E1),
                      size: 20,
                    ),
                    onTap: _isSubmitting ? null : () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedMethod = index);
                    },
                  ),
                ),
              );
            }),

            const SizedBox(height: 14),

            // Dynamic Method Input Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const FlippedIcon(PhosphorIconsRegular.identificationCard, color: kPrimaryOrange, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'بيانات التحويل المطلوبة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_methods[_selectedMethod]['key'] == 'syriatel_cash' || _methods[_selectedMethod]['key'] == 'sham_cash') ...[
                    _buildField(
                      controller: _syriatelPhoneController,
                      label: 'رقم هاتف حساب ${_methods[_selectedMethod]['title']} *',
                      hint: '9xxxxxxxx',
                      icon: PhosphorIconsRegular.phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [SyrianPhoneInputFormatter()],
                    ),
                  ] else if (_methods[_selectedMethod]['key'] == 'al_haram') ...[
                    _buildField(
                      controller: _alHaramNameController,
                      label: 'اسم المستلم الثلاثي (كما في الهوية) *',
                      hint: 'الاسم الكامل للمستلم',
                      icon: PhosphorIconsRegular.user,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _alHaramPhoneController,
                      label: 'رقم هاتف المستلم *',
                      hint: '9xxxxxxxx',
                      icon: PhosphorIconsRegular.phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [SyrianPhoneInputFormatter()],
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _alHaramCityController,
                      label: 'المحافظة / المدينة والفرع المفضل',
                      hint: 'مثال: دمشق - فرع الحلبوني',
                      icon: PhosphorIconsRegular.mapPin,
                    ),
                  ] else if (_methods[_selectedMethod]['key'] == 'bank_transfer') ...[
                    _buildField(
                      controller: _bankNameController,
                      label: 'اسم المصرف / البنك *',
                      hint: 'مثال: بنك بيمو السعودي الفرنسي / بنك البركة',
                      icon: PhosphorIconsRegular.bank,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _bankHolderController,
                      label: 'اسم صاحب الحساب الثلاثي *',
                      hint: 'الاسم مطابق للحساب البنكي',
                      icon: PhosphorIconsRegular.user,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _bankIbanController,
                      label: 'رقم الحساب أو الآيبان (IBAN) *',
                      hint: 'رقم الحساب المصرفي',
                      icon: PhosphorIconsRegular.creditCard,
                    ),
                  ] else if (_methods[_selectedMethod]['key'] == 'cash_in_store') ...[
                    _buildField(
                      controller: _cashPhoneController,
                      label: 'رقم هاتف المسؤول في المحل للتنسيق *',
                      hint: '9xxxxxxxx',
                      icon: PhosphorIconsRegular.phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [SyrianPhoneInputFormatter()],
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _cashNoteController,
                      label: 'أوقات التواجد المفضلة في المحل (اختياري)',
                      hint: 'مثال: يومياً من 11 صباحاً حتى 5 مساءً',
                      icon: PhosphorIconsRegular.clock,
                    ),
                  ],

                  const SizedBox(height: 10),
                  _buildField(
                    controller: _notesController,
                    label: 'ملاحظات إضافية للمحاسبة (اختياري)',
                    hint: 'أي تفاصيل أخرى تود إضافتها مع الطلب',
                    icon: PhosphorIconsRegular.notePencil,
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Main Action Button (In-app submission, NO WhatsApp)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (!_hasAvailableBalance || _isSubmitting) ? null : () => _submitSettlementRequest(context),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const FlippedIcon(PhosphorIconsFill.checkCircle, size: 20, color: Colors.white),
                label: Text(
                  _isSubmitting
                      ? 'جارٍ إرسال الطلب...'
                      : (_hasAvailableBalance ? 'تأكيد وإرسال طلب السحب' : 'لا يوجد رصيد متاح للسحب'),
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  disabledForegroundColor: const Color(0xFF64748B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Direct Call Support Option
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton.icon(
                onPressed: _callAccountingSupport,
                icon: const FlippedIcon(PhosphorIconsRegular.phoneCall, size: 16, color: Color(0xFF64748B)),
                label: Text(
                  'للاستفسار تواصل مباشرة مع قسم المحاسبة',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: !_isSubmitting && _hasAvailableBalance,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF94A3B8)),
            prefixIcon: FlippedIcon(icon, color: kPrimaryOrange, size: 18),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickChip(String label, double fraction) {
    final isSelected = _isPresetSelected(fraction);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Harmonized with selected payout method card visual styling
    final selectedBg = isDark ? const Color(0xFF2C1810) : const Color(0xFFFFF0E8);
    final unselectedBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    const selectedBorder = kPrimaryOrange;
    final unselectedBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final selectedTextColor = isDark ? const Color(0xFFFF8A65) : const Color(0xFF9A3412);
    final unselectedTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return InkWell(
      onTap: _isSubmitting ? null : () => _setPresetPercentage(fraction),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedBorder : unselectedBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              FlippedIcon(
                PhosphorIconsBold.check,
                size: 13,
                color: selectedTextColor,
              ),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Settlement Policy Bottom Sheet (Educational & Contact Modal)
/// ---------------------------------------------------------------------------
class SettlementPolicySheet extends StatelessWidget {
  const SettlementPolicySheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FlippedIcon(PhosphorIconsFill.info, color: kPrimaryOrange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'آلية التسوية والتحويل المالي',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const FlippedIcon(PhosphorIconsRegular.x, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildPolicyStep(
            icon: PhosphorIconsFill.calendarCheck,
            title: 'دورة التسوية الأسبوعية',
            desc: 'تتم تسوية الحسابات دورياً بشكل أسبوعي، كما يحق للتاجر طلب تسوية استثنائية عند وصول الرصيد للحد الأدنى.',
          ),
          const SizedBox(height: 12),
          _buildPolicyStep(
            icon: PhosphorIconsFill.money,
            title: 'التسليم النقدي في المحل',
            desc: 'يقوم مناديب جيتك بتسليم الدفعات النقدية مباشرة إلى إدارة المحل مع توثيق إيصال استلام داخل التطبيق.',
          ),
          const SizedBox(height: 12),
          _buildPolicyStep(
            icon: PhosphorIconsFill.deviceMobileSpeaker,
            title: 'التحويل الإلكتروني والمحافظ',
            desc: 'يمكن تحويل المستحقات إلى حساب شام كاش أو سيريتل كاش المعتمد للمتجر، أو عبر الحساب البنكي.',
          ),
          const SizedBox(height: 12),
          _buildPolicyStep(
            icon: PhosphorIconsFill.clockAfternoon,
            title: 'الرصيد المعلق',
            desc: 'الأموال المعلقة هي مستحقات الطلبات الجارية أو المسلمة اليوم وتصبح متاحة للتسوية فور التدقيق النهائي بنهاية اليوم.',
          ),
          const SizedBox(height: 20),

          // Contact Support Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                final cleanPhone = kSupportWhatsApp.replaceAll('+', '').replaceAll(' ', '');
                final msg = Uri.encodeComponent('مرحباً إدارة جيتك، لدي استفسار مالي بخصوص تسوية الحسابات.');
                LunchUrl.canLaunch('https://wa.me/$cleanPhone?text=$msg');
                Navigator.pop(context);
              },
              icon: const FlippedIcon(PhosphorIconsFill.whatsappLogo, size: 18, color: Colors.white),
              label: Text(
                'تواصل مع قسم المحاسبة عبر واتساب',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyStep({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FlippedIcon(icon, size: 18, color: const Color(0xFF475569)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

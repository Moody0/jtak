import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../config/constants/constants.dart';
import '../../../config/themes/colors.dart';
import '../../../core/enums/payment_method_enum.dart';
import '../../../core/models/bill_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../ui/widgets/app_widgets.dart';
import '../../../ui/widgets/price_widgets.dart';
import '../../../utils/utilities/global_var.dart';

class PaymentSingleItem extends StatelessWidget {
  final PaymentModel item;
  const PaymentSingleItem(this.item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isHandedOver = item.handoverDate != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : kCardBorderColor,
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${item.id}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kPrimaryOrange,
                  ),
                ),
              ),
              PriceTextWidget.small(
                price: item.amount ?? 0.0,
                currencyString: isArabic ? 'ل.س' : 'SYP',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : kBorderColor),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AppIcon(PhosphorIcons.calendarBlankBold, size: 14, color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
                  const SizedBox(width: 4),
                  Text(
                    GlobalVar.dateForamt(item.handoverDate, kDateTimeFormat) ?? (isArabic ? 'قيد المعالجة' : 'Processing'),
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHandedOver
                      ? (isDark ? const Color(0xFF064E3B) : kGreenLight)
                      : (isDark ? const Color(0xFF334155) : kSurfaceWarm),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isHandedOver
                      ? (isArabic ? 'تم التسليم لـ ${item.toUser ?? ''}' : 'Delivered to ${item.toUser ?? ''}')
                      : (isArabic ? 'جاري تسليم ${item.toUser ?? ''}' : 'Delivering to ${item.toUser ?? ''}'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isHandedOver
                        ? (isDark ? const Color(0xFF34D399) : kGreen)
                        : kPrimaryOrange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BillSingleItem extends StatelessWidget {
  final BillModel item;
  const BillSingleItem(this.item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : kCardBorderColor,
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : kGreyBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${item.id}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                ),
              ),
              PriceTextWidget.small(
                price: item.totalAmount ?? 0.0,
                currencyString: isArabic ? 'ل.س' : 'SYP',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : kBorderColor),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                GlobalVar.dateForamt(item.dueDate, kDateTimeFormat) ?? '',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
              ),
              _paymentMethodBadge(isDark, isArabic),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodBadge(bool isDark, bool isArabic) {
    String label = isArabic
        ? (item.paymentMethod?.value ?? 'الدفع نقداً')
        : (item.paymentMethod == PaymentMethod.creditCardPayment ? 'Credit Card' : 'Cash');
    IconData icon = PhosphorIcons.moneyBold;

    if (item.paymentMethod == PaymentMethod.creditCardPayment) {
      icon = PhosphorIcons.creditCardBold;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : kCharcoalMedium),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : kCharcoalMedium,
          ),
        ),
      ],
    );
  }
}

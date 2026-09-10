import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/transactions_provider.dart';
import '../../../ui/widgets/app_widgets.dart';
import '../../../ui/widgets/price_widgets.dart';
import 'payment_page.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({Key? key}) : super(key: key);

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  late TransactionsProvider provider;

  @override
  void initState() {
    Future.microtask(() => Provider.of<TransactionsProvider>(context, listen: false).loadBalances());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<TransactionsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      body: Column(
        children: [
          // 1. Balance Hero Card
          _buildBalanceHero(context, isDark, isArabic),

          // 2. Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const AppIcon(PhosphorIcons.receiptBold, size: 18, color: kPrimaryOrange),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'سجل الدفعات والتحويلات' : 'Payment & Transfer History',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                ),
              ],
            ),
          ),

          // 3. Transactions List
          Expanded(
            child: PaymentPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHero(BuildContext context, bool isDark, bool isArabic) {
    final balance = provider.balances.amount ?? 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : kCardBorderColor,
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF475569) : kPrimaryOrange.withOpacity(0.25),
                width: 1.2,
              ),
            ),
            child: const Center(
              child: AppIcon(
                PhosphorIcons.walletBold,
                size: 26,
                color: kPrimaryOrange,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'الرصيد المستحق للسائق' : 'Driver Balance Due',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                  ),
                ),
                const SizedBox(height: 4),
                PriceTextWidget.large(
                  price: balance,
                  currencyString: isArabic ? 'ل.س' : 'SYP',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/transactions_provider.dart';
import '../../../core/services/settlement_update_events.dart';
import '../../../ui/widgets/app_widgets.dart';
import '../../../ui/widgets/price_widgets.dart';
import '../../../utils/utilities/global_var.dart';
import 'payment_page.dart';
import 'earnings_wallet_card.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({Key? key}) : super(key: key);

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage>
    with WidgetsBindingObserver {
  late TransactionsProvider provider;
  bool _requestingSettlement = false;
  bool _requestingEarnings = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshBalances();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      Provider.of<TransactionsProvider>(context, listen: false)
          .loadBalances()
          .catchError((_) {});
      SettlementUpdateEvents.notifyChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<TransactionsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      body: RefreshIndicator(
        color: kPrimaryOrange,
        onRefresh: _refreshBalances,
        child: NestedScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
                child: Column(children: [
              EarningsWalletCard(
                  wallet: provider.balances.earnings,
                  requesting: _requestingEarnings,
                  onRequest: () => _requestEarningsPayout(isArabic)),
              // 1. Balance Hero Card
              _buildBalanceHero(context, isDark, isArabic),

              // 2. Section Header with Refresh Action
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const AppIcon(PhosphorIcons.receiptBold,
                            size: 18, color: kPrimaryOrange),
                        const SizedBox(width: 8),
                        Text(
                          isArabic
                              ? 'سجل الدفعات والتحويلات'
                              : 'Payment & Transfer History',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : kCharcoalDark,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _isRefreshing
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _refreshBalances();
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            if (_isRefreshing)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kPrimaryOrange,
                                ),
                              )
                            else
                              AppIcon(PhosphorIcons.arrowsClockwiseBold,
                                  size: 14,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : kCharcoalMuted),
                            const SizedBox(width: 4),
                            Text(
                              _isRefreshing
                                  ? (isArabic ? 'جاري التحديث...' : 'Refreshing...')
                                  : (isArabic ? 'تحديث' : 'Refresh'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _isRefreshing
                                    ? kPrimaryOrange
                                    : (isDark
                                        ? const Color(0xFF94A3B8)
                                        : kCharcoalMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ])),
          ],
          body: PaymentPage(onRefreshBalances: () => provider.loadBalances()),
        ),
      ),
    );
  }

  Widget _buildBalanceHero(BuildContext context, bool isDark, bool isArabic) {
    final balance = provider.balances.amount ?? 0.0;
    final pendingAmount = provider.balances.pendingAmount ?? 0.0;
    final availableAmount = provider.balances.availableAmount ??
        (balance - pendingAmount).clamp(0.0, double.infinity);
    final double maxCashFloat =
        provider.balances.maxCashFloat ?? 5000.0; // 5k SYP custody limit (#27)
    final rawRatio = maxCashFloat > 0 ? (balance.abs() / maxCashFloat) : 0.0;
    final floatRatio = rawRatio.clamp(0.0, 1.0);
    final percent = rawRatio > 0 && rawRatio < 0.01 ? '<1' : (rawRatio * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    final isWarning = rawRatio >= 0.8 && rawRatio < 1.0;
    final isCritical = rawRatio >= 1.0;
    final statusColor = isCritical ? kRed : (isWarning ? kAmber : kGreen);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCritical
              ? kRed
              : (isWarning
                  ? kAmber
                  : (isDark ? const Color(0xFF334155) : kCardBorderColor)),
          width: (isCritical || isWarning) ? 1.5 : 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF475569)
                        : kPrimaryOrange.withValues(alpha: 0.25),
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
                      isArabic
                          ? 'رصيد العهدة المسجل'
                          : 'Recorded custody balance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
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

          const SizedBox(height: 16),
          Divider(
              height: 1,
              color: isDark ? const Color(0xFF334155) : kBorderColor),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _balanceBreakdown(
                isArabic ? 'المتاح للتسوية' : 'Available to settle',
                availableAmount,
                isDark,
                isArabic,
              ),
              if (pendingAmount > 0)
                _balanceBreakdown(
                  isArabic ? 'قيد المراجعة' : 'Pending review',
                  pendingAmount,
                  isDark,
                  isArabic,
                ),
            ],
          ),
          if (provider.balances.reservedPurchaseAmount > 0)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(
              '${isArabic ? 'محجوز لشراء الطلبات' : 'Reserved for purchases'}: ${GlobalVar.priceForamt(provider.balances.reservedPurchaseAmount)} ${isArabic ? 'ل.س' : 'SYP'}')),
          if (provider.balances.hasPendingAccountingOrders)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(isArabic
              ? 'التسوية معلّقة حتى اكتمال محاسبة الطلبات. تواصل مع الإدارة.'
              : 'Settlement is paused until order accounting is complete. Contact admin.')),
          if (provider.balances.isSalariedEmployee) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 20, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'حساب كابتن براتب شهري (موظف) — كامل العهدة النقدية واجبة التسليم للشركة بدون اقتطاع أرباح.'
                          : 'Salaried Captain Account — full cash custody must be remitted to company without wage offsets.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (provider.balances.wagesOffset > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F2E1E).withValues(alpha: 0.6)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF166534)
                      : const Color(0xFFBBF7D0),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppIcon(PhosphorIcons.arrowsLeftRightBold,
                          size: 16, color: kGreen),
                      const SizedBox(width: 6),
                      Text(
                        isArabic
                            ? 'المقاصة الذكية للمستحقات'
                            : 'Smart Netting Breakdown',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic
                            ? 'إجمالي العهدة النقدية:'
                            : 'Gross cash custody:',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                        ),
                      ),
                      Text(
                        '${GlobalVar.priceForamt(balance)} ${isArabic ? 'ل.س' : 'SYP'}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic
                            ? 'مستحقاتك المقتطعة نقداً:'
                            : 'Wages retained by you:',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                        ),
                      ),
                      Text(
                        '- ${GlobalVar.priceForamt(provider.balances.wagesOffset)} ${isArabic ? 'ل.س' : 'SYP'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kGreen,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic
                            ? 'صافي المبلغ الواجب تسليمه:'
                            : 'Net cash due to admin:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : kCharcoalDark,
                        ),
                      ),
                      Text(
                        '${GlobalVar.priceForamt(provider.balances.netCashDue)} ${isArabic ? 'ل.س' : 'SYP'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kPrimaryOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Cash Float Limit Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AppIcon(
                    PhosphorIcons.moneyBold,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isArabic
                        ? 'الحد الأقصى للعهدة النقدية (COD)'
                        : 'Cash Float Limit (COD)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : kCharcoalDark,
                    ),
                  ),
                ],
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: floatRatio,
              minHeight: 7,
              backgroundColor:
                  isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${GlobalVar.priceForamt(balance.abs())} ${isArabic ? 'ل.س' : 'SYP'}',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
              ),
              Text(
                '${isArabic ? 'الحد:' : 'Max:'} ${GlobalVar.priceForamt(maxCashFloat)} ${isArabic ? 'ل.س' : 'SYP'}',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
              ),
            ],
          ),

          if (isCritical) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kRed.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const AppIcon(PhosphorIcons.warningCircleBold,
                      size: 18, color: kRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'تحذير: وصلت إلى الحد الأقصى للعهدة النقدية (${GlobalVar.priceForamt(maxCashFloat)} ل.س) أو تجاوزته. يرجى تسليم المبالغ المحصلة إلى المحاسب فوراً.'
                          : 'Alert: Maximum cash float limit (${GlobalVar.priceForamt(maxCashFloat)} SYP) reached or exceeded. Please deposit collected cash at the cashier immediately.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isWarning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF78350F).withValues(alpha: 0.3)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAmber.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const AppIcon(PhosphorIcons.warningBold,
                      size: 18, color: kAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'تنبيه: اقتربت من الحد الأقصى للعهدة النقدية ($percent%). يرجى الاستعداد لتسليم المبالغ المحصلة إلى المحاسب.'
                          : 'Warning: Approaching cash float limit ($percent%). Please prepare to deposit collected funds at the central cashier.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: availableAmount <= 0 ||
                      provider.balances.hasPendingAccountingOrders ||
                      provider.balances.hasPendingSettlement ||
                      _requestingSettlement
                  ? null
                  : () => _requestFullSettlement(isArabic),
              icon: _requestingSettlement
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const AppIcon(PhosphorIcons.handCoinsBold,
                      size: 19, color: Colors.white),
              label: Text(
                provider.balances.hasPendingSettlement
                    ? (isArabic
                        ? 'طلب التسوية قيد مراجعة الإدارة'
                        : 'Settlement request is under review')
                    : (provider.balances.wagesOffset > 0
                        ? (isArabic
                            ? 'طلب تسليم صافي العهدة (${GlobalVar.priceForamt(provider.balances.netCashDue)} ل.س)'
                            : 'Request net custody handover (${GlobalVar.priceForamt(provider.balances.netCashDue)} SYP)')
                        : (isArabic
                            ? 'طلب تسليم العهدة للإدارة'
                            : 'Request cash custody handover')),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceBreakdown(
      String label, double amount, bool isDark, bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
        ),
        const SizedBox(height: 3),
        PriceTextWidget.small(
          price: amount,
          currencyString: isArabic ? 'ل.س' : 'SYP',
        ),
      ],
    );
  }

  Future<void> _requestFullSettlement(bool isArabic) async {
    final isNet = provider.balances.wagesOffset > 0;
    final netAmount = provider.balances.netCashDue;
    final wagesOffset = provider.balances.wagesOffset;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic
            ? (isNet ? 'تأكيد تسليم صافي العهدة' : 'تأكيد طلب التسوية')
            : (isNet
                ? 'Confirm Net Custody Handover'
                : 'Confirm settlement request')),
        content: Text(isArabic
            ? (isNet
                ? 'ستسلّم للإدارة صافي المبلغ (${GlobalVar.priceForamt(netAmount)} ل.س) مع احتفاظك بمستحقاتك البالغة (${GlobalVar.priceForamt(wagesOffset)} ل.س) نقداً. بعد تأكيد الإدارة، سيتم إغلاق العهدة ومستحقاتك معاً.'
                : 'سيُرسل الطلب إلى الإدارة. بعد تأكيد استلام كامل المبلغ، سيصبح رصيد عهدتك صفراً.')
            : (isNet
                ? 'You will remit the net amount (${GlobalVar.priceForamt(netAmount)} SYP) to admin while retaining your earned wages (${GlobalVar.priceForamt(wagesOffset)} SYP) in cash. After admin approval, both custody and wages will be settled.'
                : 'The request will be sent to admin. Your cash custody becomes zero after admin confirms receiving the full amount.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isArabic ? 'إرسال الطلب' : 'Send request')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _requestingSettlement = true);
    try {
      final ok = await provider.requestSettlement();
      if (mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isArabic
              ? 'تم إرسال طلب التسوية إلى الإدارة'
              : 'Settlement request sent to admin'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _requestingSettlement = false);
    }
  }

  Future<void> _refreshBalances() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);
    try {
      await Provider.of<TransactionsProvider>(context, listen: false)
          .loadBalances();
      SettlementUpdateEvents.notifyChanged();
    } catch (_) {/* The API connectivity gate owns network/server errors. */}
    finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _requestEarningsPayout(bool isArabic) async {
    if (_requestingEarnings) return;
    final wallet = provider.balances.earnings;
    if (wallet == null || !wallet.canRequestPayout) return;
    final amount = await showDialog<double>(
        context: context,
        builder: (_) =>
            EarningsPayoutDialog(availableAmount: wallet.claimablePayoutAmount));
    if (amount == null || !mounted) return;
    setState(() => _requestingEarnings = true);
    try {
      final ok = await provider.requestEarningsPayout(amount);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok
                ? (isArabic
                    ? 'تم إرسال طلب صرف مستحقاتك إلى الإدارة'
                    : 'Earnings payout request sent')
                : (isArabic
                    ? 'تعذر إرسال الطلب. حدّث رصيدك وحاول مجدداً.'
                    : 'Unable to submit. Refresh your balance and retry.'))));
    } catch (_) {
      /* The API gate handles failures without a duplicate dialog. */
    } finally {
      if (mounted) setState(() => _requestingEarnings = false);
    }
  }
}

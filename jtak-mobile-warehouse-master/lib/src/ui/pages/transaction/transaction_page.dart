import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/app/merchant_state_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/transactions_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/balances_model.dart';
import 'package:app_jtak_warehouse/src/ui/pages/transaction/bills_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/transaction/payment_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/transaction/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

/// ---------------------------------------------------------------------------
/// JTAK Merchant Financials, Payouts & Store Performance Hub
/// ---------------------------------------------------------------------------
class TransactionPage extends StatefulWidget {
  static const String routeName = '/TransactionPage';
  const TransactionPage({Key? key}) : super(key: key);

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBalances();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBalances() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      await Provider.of<TransactionsProvider>(context, listen: false).loadBalances();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _openSettlementRequestSheet(double available) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettlementRequestSheet(availableBalance: available),
    );
  }

  void _openSettlementPolicySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SettlementPolicySheet(),
    );
  }

  void _showPendingBalanceInfo(double pending) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const FlippedIcon(PhosphorIconsFill.clock, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'ما هو الرصيد المعلق؟',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
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
              'الرصيد المعلق هو مبلغ محجوز داخل طلبات تسوية أرسلتها للإدارة ولم تُغلق بعد.',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                height: 1.5,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'عند الرفض يعود المبلغ فوراً إلى الرصيد المتاح. وعند تأكيد استلامك للدفعة تُغلق التسوية ويُخصم المبلغ من مستحقات جيتك لك.',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                height: 1.4,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الرصيد المعلق الحالي:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B))),
                  Text(
                    '${formatPrice(pending)} ل.س',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'حسناً، فهمت',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Section Header Bar
            _buildTopHeader(),

            // 2. Modern Pill Segmented Tab Bar (Zero truncation, zero bottom line)
            _buildTabBar(),

            // 3. Tab Views (Overview / Bills / Payouts)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(provider),
                  const BillsPage(),
                  const PaymentPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top Screen Header
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
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
                child: const FlippedIcon(PhosphorIconsFill.wallet, color: kPrimaryOrange, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المالية والأرباح',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'مستحقات المتجر، المبيعات وسجل التسويات',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryOrange),
                  )
                : const FlippedIcon(PhosphorIconsRegular.arrowsClockwise, color: Color(0xFF64748B), size: 20),
            tooltip: 'تحديث الحسابات',
            onPressed: _isRefreshing
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _loadBalances();
                  },
          ),
        ],
      ),
    );
  }

  /// Modern Segmented Tab Bar (Fixed width clipping and black divider artifact)
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent, // Fix: eliminates the dark horizontal line
          indicatorSize: TabBarIndicatorSize.tab, // Fix: crisp pill fitting
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4), // Fix: prevents label overflow
          labelColor: kPrimaryOrange,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('ملخص الأداء'),
              ),
            ),
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('سجل الفواتير'),
              ),
            ),
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('الدفعات المستلمة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Overview & KPIs Tab
  Widget _buildOverviewTab(TransactionsProvider provider) {
    final b = provider.balances;

    return RefreshIndicator(
      color: kPrimaryOrange,
      onRefresh: _loadBalances,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // 1. Hero Wallet Balance Card
          _buildHeroWalletCard(b),

          if (provider.settlementRequests.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSettlementRequestsCard(provider.settlementRequests),
          ],

          const SizedBox(height: 18),

          // 2. Today's Real-time Performance KPIs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أداء المتجر اليوم',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              InkWell(
                onTap: () => _tabController.animateTo(1),
                child: Text(
                  'عرض الفواتير',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kPrimaryOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTodayMetricsGrid(b),

          const SizedBox(height: 20),

          // 3. Month Summary
          Text(
            'ملخص الشهر الحالي',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          _buildMonthlySummaryCard(b),

          const SizedBox(height: 20),

          // 4. Transparent Settlement Policy Banner
          _buildSettlementInfoCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSettlementRequestsCard(List<Map<String, dynamic>> requests) {
    final recent = requests.take(3).toList();
    const statusLabels = ['قيد مراجعة الإدارة', 'مقبول — بانتظار الاستلام', 'مرفوض', 'مكتمل'];
    const statusColors = [Color(0xFFD97706), Color(0xFF2563EB), Color(0xFFDC2626), Color(0xFF16A34A)];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('آخر طلبات التسوية', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...recent.map((request) {
            final status = (request['status'] as num?)?.toInt() ?? 0;
            final safeStatus = status.clamp(0, 3);
            final amount = (request['amount'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request['requestNumber']?.toString() ?? '-', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        Text('${formatPrice(amount)} ل.س', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF64748B))),
                        if ((request['rejectionReason']?.toString() ?? '').isNotEmpty)
                          Text('سبب الرفض: ${request['rejectionReason']}', style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: const Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                  Text(statusLabels[safeStatus], style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColors[safeStatus])),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Hero Wallet Card (With Syrian Currency Thousands Formatting & Direct Settlement Request)
  Widget _buildHeroWalletCard(BalancesModel balances) {
    final amountFormatted = formatPrice(balances.amount);
    final pendingFormatted = formatPrice(balances.pendingAmount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF1E293B), // Slate 800
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Wallet title & status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const FlippedIcon(PhosphorIconsFill.wallet, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'الرصيد المتاح للتسوية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF15803D).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'مستحق الدفع',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4ADE80),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Balance Amount Row & Quick Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    amountFormatted,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ل.س',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryOrange,
                    ),
                  ),
                ],
              ),

              // Request Payout Button
              ElevatedButton.icon(
                onPressed: () => _openSettlementRequestSheet(balances.amount),
                icon: const FlippedIcon(PhosphorIconsBold.handCoins, size: 14),
                label: const Text('طلب تسوية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFF334155)),
          const SizedBox(height: 12),

          // Sub-row: Pending balance & auto settlement frequency
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _showPendingBalanceInfo(balances.pendingAmount),
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    const FlippedIcon(PhosphorIconsRegular.clock, color: Color(0xFF94A3B8), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'الرصيد المعلق: $pendingFormatted ل.س',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const FlippedIcon(PhosphorIconsRegular.info, size: 12, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
              InkWell(
                onTap: _openSettlementPolicySheet,
                child: Row(
                  children: [
                    Text(
                      'تسوية دورية أسبوعية',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const FlippedIcon(PhosphorIconsBold.caretLeft, size: 10, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Today's Performance 3-KPI Grid
  Widget _buildTodayMetricsGrid(BalancesModel balances) {
    final todayGross = formatPrice(balances.todayGrossSales);
    final todayNet = formatPrice(balances.todayNetEarnings);
    final todayOrders = balances.todayOrdersCount;

    return Row(
      children: [
        // 1. Today's Gross Sales -> Jumps to Invoices tab
        Expanded(
          child: _buildMetricCard(
            title: 'مبيعات اليوم',
            value: todayGross,
            unit: 'ل.س',
            icon: PhosphorIconsBold.chartLineUp,
            iconColor: kPrimaryOrange,
            iconBgColor: const Color(0xFFFFF0E8),
            onTap: () => _tabController.animateTo(1),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Today's Net Earnings
        Expanded(
          child: _buildMetricCard(
            title: 'أرباح اليوم',
            value: todayNet,
            unit: 'ل.س',
            icon: PhosphorIconsBold.trendUp,
            iconColor: const Color(0xFF16A34A),
            iconBgColor: const Color(0xFFDCFCE7),
            onTap: () => _tabController.animateTo(1),
          ),
        ),
        const SizedBox(width: 8),

        // 3. Today's Completed Orders -> Navigates to Orders tab in MainPage!
        Expanded(
          child: _buildMetricCard(
            title: 'طلبات اليوم',
            value: '$todayOrders',
            unit: 'طلب',
            icon: PhosphorIconsBold.checkCircle,
            iconColor: const Color(0xFF2563EB),
            iconBgColor: const Color(0xFFEFF6FF),
            onTap: () {
              try {
                Provider.of<MerchantStateProvider>(context, listen: false).setIndex(0);
              } catch (_) {}
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FlippedIcon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Monthly Summary Card
  Widget _buildMonthlySummaryCard(BalancesModel balances) {
    final monthGross = formatPrice(balances.monthGrossSales);
    final monthNet = formatPrice(balances.monthNetEarnings);
    final monthOrders = balances.monthOrdersCount;
    final totalPayouts = formatPrice(balances.totalPayoutsReceived);
    final payoutsCount = balances.totalPayoutsCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            label: 'إجمالي مبيعات الشهر',
            value: '$monthGross ل.س',
            icon: PhosphorIconsRegular.receipt,
            color: const Color(0xFF0F172A),
            onTap: () => _tabController.animateTo(1),
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildSummaryRow(
            label: 'صافي أرباح المتجر بالشهر',
            value: '$monthNet ل.س',
            icon: PhosphorIconsRegular.trendUp,
            color: const Color(0xFF16A34A),
            onTap: () => _tabController.animateTo(1),
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildSummaryRow(
            label: 'عدد الطلبات المكتملة',
            value: '$monthOrders طلب',
            icon: PhosphorIconsRegular.package,
            color: const Color(0xFF2563EB),
            onTap: () {
              try {
                Provider.of<MerchantStateProvider>(context, listen: false).setIndex(0);
              } catch (_) {}
            },
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildSummaryRow(
            label: 'إجمالي الدفعات المسلمة',
            value: '$totalPayouts ل.س ($payoutsCount دفعة)',
            icon: PhosphorIconsRegular.handCoins,
            color: kPrimaryOrange,
            onTap: () => _tabController.animateTo(2),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              FlippedIcon(icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const FlippedIcon(PhosphorIconsBold.caretLeft, size: 12, color: Color(0xFF94A3B8)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Settlement Info & Support Note
  Widget _buildSettlementInfoCard() {
    return InkWell(
      onTap: _openSettlementPolicySheet,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FlippedIcon(PhosphorIconsFill.info, size: 20, color: kPrimaryOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'آلية تحويل وتسوية المستحقات',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'التفاصيل',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kPrimaryOrange,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const FlippedIcon(PhosphorIconsBold.caretLeft, size: 10, color: kPrimaryOrange),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تتم تسوية مستحقات المتجر أسبوعياً أو عند الطلب، حيث يتم تسليم المبالغ نقداً إلى المحل مباشرة أو تحويلها عبر شام كاش / سيريتل كاش / حساب بنكي معتمد.',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      height: 1.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

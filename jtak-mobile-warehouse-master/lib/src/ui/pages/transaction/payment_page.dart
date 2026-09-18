import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/payment_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/transactions_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/payment_model.dart';
import 'package:app_jtak_warehouse/src/ui/pages/transaction/widget.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/base_view.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({Key? key}) : super(key: key);

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> with AutomaticKeepAliveClientMixin {
  late final PaymentProvider _paymentProvider;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Pending Handover, 2: Received

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _paymentProvider = PaymentProvider();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PaymentModel> _filterPayments(List<PaymentModel> payments) {
    return payments.where((p) {
      final isReceived = p.isReceived;

      // 1. Filter by status
      // 0: الكل
      // 1: قيد التسليم (تحتاج تأكيد) - Approved settlements waiting for merchant receipt, or unreceived legacy payments
      // 2: تم الاستلام - Completed settlements and confirmed payments
      if (_selectedFilterIndex == 1) {
        if (isReceived) return false;
        if (p.isSettlementRequest && !p.isApprovedPendingReceipt) return false;
      }
      if (_selectedFilterIndex == 2) {
        if (!isReceived) return false;
      }

      // 2. Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.replaceAll('#', '').toLowerCase();
        final idMatches = (p.id?.toString().toLowerCase().contains(q) ?? false);
        final reqMatches = (p.requestNumber?.toLowerCase().contains(q) ?? false);
        final userMatches = (p.byUser?.toLowerCase().contains(q) ?? false);
        final methodMatches = (p.method?.toLowerCase().contains(q) ?? false);
        return idMatches || reqMatches || userMatches || methodMatches;
      }

      return true;
    }).toList();
  }

  void _openSettlementRequest(BuildContext context) {
    final balance = Provider.of<TransactionsProvider>(context, listen: false).balances.amount;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettlementRequestSheet(availableBalance: balance),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BaseView<PaymentProvider>(
      modelProvider: _paymentProvider,
      onModelReady: (modelProvider) => modelProvider.loadPayments(),
      builder: (context, modelProvider) {
        final allPayments = modelProvider.dataList;
        final filteredPayments = _filterPayments(allPayments);
        final isBusy = modelProvider.isBusy && allPayments.isEmpty;

        return Column(
          children: [
            // Top Settlement Action & Filter Header
            _buildTopHeader(),

            // List or Empty / Loading State
            Expanded(
              child: RefreshIndicator(
                color: kPrimaryOrange,
                onRefresh: () {
                  modelProvider.page = 0;
                  return modelProvider.loadPayments();
                },
                child: isBusy
                    ? const Center(
                        child: CircularProgressIndicator(color: kPrimaryOrange),
                      )
                    : filteredPayments.isEmpty
                        ? _buildEmptyState(modelProvider)
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 6, bottom: 24),
                            itemCount: filteredPayments.length + 1,
                            itemBuilder: (ctx, index) {
                              // Load more trigger
                              if (index == filteredPayments.length - 2 &&
                                  modelProvider.isMoreAvailable &&
                                  !modelProvider.isBusy) {
                                modelProvider.loadPayments();
                              }

                              if (index == filteredPayments.length) {
                                if (modelProvider.isBusy) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryOrange),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox(height: 20);
                              }

                              return PaymentSingleItem(
                                filteredPayments[index],
                                onReceiptConfirmed: () {
                                  setState(() {});
                                },
                              );
                            },
                          ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          // Quick Request Payout Banner Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const FlippedIcon(PhosphorIconsFill.handCoins, size: 16, color: kPrimaryOrange),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'سجل دفعات التسوية المستلمة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _openSettlementRequest(context),
                icon: const FlippedIcon(PhosphorIconsBold.plus, size: 13),
                label: const Text('طلب تسوية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Field
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'بحث برقم الدفعة أو اسم المندوب...',
                hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF94A3B8)),
                prefixIcon: const FlippedIcon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const FlippedIcon(PhosphorIconsRegular.xCircle, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Filter Chips Row
          Row(
            children: [
              _buildFilterChip(0, 'الكل'),
              const SizedBox(width: 8),
              _buildFilterChip(1, 'قيد التسليم (تحتاج تأكيد)'),
              const SizedBox(width: 8),
              _buildFilterChip(2, 'تم الاستلام'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF0E8) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? kPrimaryOrange : const Color(0xFFE2E8F0),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? kPrimaryOrange : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(PaymentProvider provider) {
    final hasFilters = _searchQuery.isNotEmpty || _selectedFilterIndex != 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const FlippedIcon(PhosphorIconsRegular.wallet, size: 40, color: Color(0xFF94A3B8)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            hasFilters ? 'لا توجد دفعات مطابقة للتصفية' : 'لا توجد دفعات تسوية مسجلة بعد',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            hasFilters
                ? 'جرب البحث برقم دفعة آخر أو قم بإلغاء التصفية'
                : 'عند قيام إدارة جيتك أو المناديب بتسليم دفعات نقدية إلى متجرك ستظهر هنا لتأكيد استلامها.',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (hasFilters)
          Center(
            child: TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedFilterIndex = 0;
                });
              },
              icon: const FlippedIcon(PhosphorIconsRegular.arrowCounterClockwise, size: 16, color: kPrimaryOrange),
              label: Text(
                'إعادة ضبط البحث',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kPrimaryOrange,
                ),
              ),
            ),
          )
        else
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _openSettlementRequest(context),
              icon: const FlippedIcon(PhosphorIconsBold.handCoins, size: 16),
              label: Text(
                'طلب تسوية رصيد جديد',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
      ],
    );
  }
}

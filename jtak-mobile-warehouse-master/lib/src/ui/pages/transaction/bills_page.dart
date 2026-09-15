import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/bill_provider.dart';
import 'package:app_jtak_warehouse/src/core/enums/payment_method_enum.dart';
import 'package:app_jtak_warehouse/src/core/models/bill_model.dart';
import 'package:app_jtak_warehouse/src/ui/pages/transaction/widget.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/base_view.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({Key? key}) : super(key: key);

  @override
  _BillsPageState createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> with AutomaticKeepAliveClientMixin {
  late final BillProvider _billProvider;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Cash, 2: Electronic

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _billProvider = BillProvider();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BillModel> _filterBills(List<BillModel> bills) {
    return bills.where((b) {
      // 1. Payment method filter
      if (_selectedFilterIndex == 1 && b.paymentMethod != PaymentMethod.payOnDelivery) {
        return false;
      }
      if (_selectedFilterIndex == 2 && b.paymentMethod != PaymentMethod.creditCardPayment) {
        return false;
      }

      // 2. Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.replaceAll('#', '').toLowerCase();
        final orderMatches = (b.orderId?.toString().toLowerCase().contains(q) ?? false);
        final billMatches = (b.id?.toString().toLowerCase().contains(q) ?? false);
        return orderMatches || billMatches;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BaseView<BillProvider>(
      modelProvider: _billProvider,
      onModelReady: (modelProvider) => modelProvider.loadBills(),
      builder: (context, modelProvider) {
        final allBills = modelProvider.dataList;
        final filteredBills = _filterBills(allBills);
        final isBusy = modelProvider.isBusy && allBills.isEmpty;

        return Column(
          children: [
            // Search and Filter Header
            _buildSearchAndFilters(),

            // List or Empty / Loading State
            Expanded(
              child: RefreshIndicator(
                color: kPrimaryOrange,
                onRefresh: () {
                  modelProvider.page = 0;
                  return modelProvider.loadBills();
                },
                child: isBusy
                    ? const Center(
                        child: CircularProgressIndicator(color: kPrimaryOrange),
                      )
                    : filteredBills.isEmpty
                        ? _buildEmptyState(modelProvider)
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 6, bottom: 24),
                            itemCount: filteredBills.length + 1,
                            itemBuilder: (ctx, index) {
                              // Load more pagination trigger
                              if (index == filteredBills.length - 2 &&
                                  modelProvider.isMoreAvailable &&
                                  !modelProvider.isBusy) {
                                modelProvider.loadBills();
                              }

                              if (index == filteredBills.length) {
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

                              return BillSingleItem(filteredBills[index]);
                            },
                          ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
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
                hintText: 'بحث برقم الطلب أو رقم الفاتورة...',
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
              _buildFilterChip(1, 'نقداً عند الاستلام'),
              const SizedBox(width: 8),
              _buildFilterChip(2, 'إلكتروني / سيريتل'),
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

  Widget _buildEmptyState(BillProvider provider) {
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
            child: const FlippedIcon(PhosphorIconsRegular.receipt, size: 40, color: Color(0xFF94A3B8)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            hasFilters ? 'لا توجد فواتير مطابقة للبحث' : 'لا يوجد سجل فواتير مسجل حالياً',
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
                ? 'جرب البحث برقم طلب مختلف أو قم بإلغاء التصفية'
                : 'ستظهر هنا جميع فواتير الطلبات ومستحقات المتجر تلقائياً عند تسليم الطلبات.',
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
            child: TextButton.icon(
              onPressed: () {
                provider.page = 0;
                provider.loadBills();
              },
              icon: const FlippedIcon(PhosphorIconsRegular.arrowsClockwise, size: 16, color: kPrimaryOrange),
              label: Text(
                'تحديث الفواتير',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kPrimaryOrange,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

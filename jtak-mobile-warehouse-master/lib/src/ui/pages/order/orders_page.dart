import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app/merchant_state_provider.dart';
import '../../../core/controllers/merchant_profile_provider.dart';
import '../../../core/controllers/order_provider.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/custom_widgets/opposite_icon.dart';
import 'order_widgets.dart';

/// ---------------------------------------------------------------------------
/// JTAK Merchant Orders Hub (Kanban Pipeline, Live Radar, Search & Instant Actions)
/// ---------------------------------------------------------------------------

class OrdersPage extends StatefulWidget {
  static const String routeName = '/OrdersPage';
  const OrdersPage({Key? key}) : super(key: key);

  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  Timer? _refreshTimer;
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final model = Provider.of<OrderProvider>(context, listen: false);
      model.refreshData();
    });

    // Background silent refresh every 6 seconds: causes zero screen flicker or scroll drops
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      final model = Provider.of<OrderProvider>(context, listen: false);
      model.silentRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 220), () {
      final model = Provider.of<OrderProvider>(context, listen: false);
      model.setSearchQuery(val);
    });
    setState(() {}); // Immediate update for clear icon visibility
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final merchantState = Provider.of<MerchantStateProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(provider),
            _buildFilterChipsRow(provider),
            _buildKanbanTabs(provider),
            _buildLiveStatusBar(provider, merchantState),
            Expanded(
              child: RefreshIndicator(
                color: kPrimaryOrange,
                backgroundColor: Colors.white,
                onRefresh: () async => await provider.refreshData(isUserInitiated: true),
                child: _buildTabList(provider, merchantState),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Search Bar (Matches Screenshot Style with Clear & Debounce)
  // ---------------------------------------------------------------------------
  Widget _buildSearchHeader(OrderProvider provider) {
    final hasText = _searchController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.white,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasText ? kPrimaryOrange.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: kCharcoalDark,
          ),
          decoration: InputDecoration(
            hintText: 'ابحث برقم الطلب، العميل، أو العنوان...',
            hintStyle: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF94A3B8),
            ),
            prefixIcon: const OppositeIcon(
              PhosphorIconsRegular.magnifyingGlass,
              color: Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: hasText
                ? IconButton(
                    icon: const OppositeIcon(
                      PhosphorIconsFill.xCircle,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      provider.setSearchQuery('');
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Quick Filter Chips Row (All, Today, Cash, Electronic)
  // ---------------------------------------------------------------------------
  Widget _buildFilterChipsRow(OrderProvider provider) {
    final activeFilter = provider.activeQuickFilter;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildFilterChip(
              label: 'الكل',
              count: provider.allOrdersCount,
              icon: PhosphorIconsRegular.funnel,
              isActive: activeFilter == 0,
              onTap: () {
                HapticFeedback.selectionClick();
                provider.setQuickFilter(0);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'طلبات اليوم',
              count: provider.todayOrdersCount,
              icon: PhosphorIconsRegular.calendarCheck,
              isActive: activeFilter == 1,
              onTap: () {
                HapticFeedback.selectionClick();
                provider.setQuickFilter(activeFilter == 1 ? 0 : 1);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'الدفع نقداً (كاش)',
              count: provider.cashOrdersCount,
              icon: PhosphorIconsRegular.money,
              isActive: activeFilter == 2,
              onTap: () {
                HapticFeedback.selectionClick();
                provider.setQuickFilter(activeFilter == 2 ? 0 : 2);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'دفع إلكتروني',
              count: provider.electronicOrdersCount,
              icon: PhosphorIconsRegular.creditCard,
              isActive: activeFilter == 3,
              onTap: () {
                HapticFeedback.selectionClick();
                provider.setQuickFilter(activeFilter == 3 ? 0 : 3);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    int? count,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFF0E8) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? kPrimaryOrange : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OppositeIcon(
              icon,
              size: 13,
              color: isActive ? kPrimaryOrange : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? kPrimaryOrange : const Color(0xFF475569),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive ? kPrimaryOrange : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.white : const Color(0xFF64748B),
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Modern Kanban Pipeline Tabs ("جديدة", "قيد التحضير", "مع المندوب", "السجل")
  // ---------------------------------------------------------------------------
  Widget _buildKanbanTabs(OrderProvider provider) {
    final tabs = [
      {'label': 'جديدة', 'count': provider.filteredNewOrders.length, 'color': kPrimaryOrange},
      {'label': 'قيد التحضير', 'count': provider.filteredPreparingOrders.length, 'color': const Color(0xFF2563EB)},
      {'label': 'مع المندوب', 'count': provider.filteredReadyOrders.length, 'color': const Color(0xFFD97706)},
      {'label': 'السجل', 'count': provider.filteredPastOrders.length, 'color': const Color(0xFF475569)},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = provider.activeTabIndex == index;
          final count = tab['count'] as int;
          final color = tab['color'] as Color;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  provider.setActiveTab(index);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tab Label
                      Text(
                        tab['label'] as String,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Pill Counter with Dynamic Glow for Urgent Pending Orders
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : (count > 0 ? color.withValues(alpha: 0.14) : Colors.transparent),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : (count > 0 ? color : const Color(0xFF94A3B8)),
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Live Sync & Real-time Status Strip
  // ---------------------------------------------------------------------------
  Widget _buildLiveStatusBar(OrderProvider provider, MerchantStateProvider merchantState) {
    final isOpen = merchantState.isStoreOpen;
    final isRefreshing = provider.isSilentRefreshing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          // Live status dot
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'نظام الاستقبال المباشر نشط' : 'المتجر مغلق حالياً',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isOpen ? const Color(0xFF065F46) : const Color(0xFF991B1B),
            ),
          ),
          const Spacer(),

          // Last Sync Time / Auto Refresh Indicator
          Text(
            provider.lastSyncTime != null
                ? 'محدّث ${_formatLastSync(provider.lastSyncTime!)}'
                : 'محدّث تلقائياً',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10.5,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),

          // Spin-on-refresh quick action button
          InkWell(
            onTap: isRefreshing
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    provider.silentRefresh();
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: AnimatedRotation(
                turns: isRefreshing ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 700),
                child: OppositeIcon(
                  PhosphorIconsRegular.arrowsClockwise,
                  size: 13,
                  color: isRefreshing ? kPrimaryOrange : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    return 'منذ فترة';
  }

  // ---------------------------------------------------------------------------
  // 5. Orders Tab List
  // ---------------------------------------------------------------------------
  Widget _buildTabList(OrderProvider provider, MerchantStateProvider merchantState) {
    // Initial loading indicator only if we have zero data in memory
    if (provider.isBusy && provider.dataList.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimaryOrange),
      );
    }

    final orders = provider.currentTabFilteredOrders;

    if (orders.isEmpty) {
      return _buildEmptyState(provider, merchantState);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return OrderSingleItem(orders[index], key: ValueKey(orders[index].id));
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Dynamic Empty State (Exact Match to Screenshot + Interactive Radar)
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(OrderProvider provider, MerchantStateProvider merchantState) {
    final isSearching = provider.searchQuery.isNotEmpty || provider.activeQuickFilter != 0;
    final isOpen = merchantState.isStoreOpen;
    final tabIndex = provider.activeTabIndex;

    final tabOptions = [
      {'index': 0, 'label': 'جديدة', 'count': provider.filteredNewOrders.length, 'color': kPrimaryOrange},
      {'index': 1, 'label': 'قيد التحضير', 'count': provider.filteredPreparingOrders.length, 'color': const Color(0xFF2563EB)},
      {'index': 2, 'label': 'مع المندوب', 'count': provider.filteredReadyOrders.length, 'color': const Color(0xFFD97706)},
      {'index': 3, 'label': 'السجل', 'count': provider.filteredPastOrders.length, 'color': const Color(0xFF475569)},
    ];
    final otherTabsWithMatches = tabOptions
        .where((t) => (t['index'] as int) != tabIndex && (t['count'] as int) > 0)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- CASE 1: Store is Closed Warning ---
                  if (!isOpen) ...[
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: OppositeIcon(
                          PhosphorIconsFill.storefront,
                          size: 40,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'المتجر مغلق حالياً 🔴',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لن يتم استقبال أي طلبات جديدة حتى تقوم بفتح المتجر للزبائن عبر الزر أدناه.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const OppositeIcon(PhosphorIconsFill.power, size: 18, color: Colors.white),
                      label: Text(
                        'فتح المتجر واستقبال الطلبات الآن 🟢',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        merchantState.setStoreOpen(true);
                        locator<MerchantProfileProvider>().toggleStoreStatus(true);
                        SnackBarWidget.showCustomSnackBar(
                          context,
                          'المتجر متاح ويستقبل الطلبات الآن 🟢',
                          backgroundColor: const Color(0xFF064E3B),
                        );
                      },
                    ),
                  ]

                  // --- CASE 2: Searching with zero results ---
                  else if (isSearching) ...[
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: OppositeIcon(
                          PhosphorIconsRegular.magnifyingGlass,
                          size: 34,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد نتائج مطابقة لبحثك',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      otherTabsWithMatches.isNotEmpty
                          ? 'لا توجد طلبات في هذا القسم، ولكن توجد نتائج في أقسام أخرى:'
                          : 'لم نجد أي طلبات تتوافق مع معايير البحث أو الفلاتر المختارة.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    if (otherTabsWithMatches.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: otherTabsWithMatches.map((tab) {
                          final idx = tab['index'] as int;
                          final label = tab['label'] as String;
                          final count = tab['count'] as int;
                          final color = tab['color'] as Color;
                          return ActionChip(
                            backgroundColor: color.withValues(alpha: 0.1),
                            side: BorderSide(color: color.withValues(alpha: 0.4)),
                            label: Text(
                              'الانتقال إلى $label ($count)',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              provider.setActiveTab(idx);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      icon: const OppositeIcon(PhosphorIconsRegular.backspace, size: 16),
                      label: Text(
                        'مسح الفلاتر والبحث',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryOrange,
                        side: const BorderSide(color: kPrimaryOrange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        provider.clearAllFilters();
                      },
                    ),
                  ]

                  // --- CASE 3: Tab 0 (جديدة) Empty State ---
                  else if (tabIndex == 0) ...[
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD6C2), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryOrange.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: OppositeIcon(
                          PhosphorIconsRegular.bell,
                          size: 36,
                          color: kPrimaryOrange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'لا توجد طلبات جديدة حالياً',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'ستتلقى تنبيهاً صوتياً فور إرسال عميل لطلب جديد',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        color: const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                    if (otherTabsWithMatches.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'لديك طلبات في الأقسام الأخرى:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: otherTabsWithMatches.map((tab) {
                          final idx = tab['index'] as int;
                          final label = tab['label'] as String;
                          final count = tab['count'] as int;
                          final color = tab['color'] as Color;
                          return ActionChip(
                            backgroundColor: color.withValues(alpha: 0.1),
                            side: BorderSide(color: color.withValues(alpha: 0.4)),
                            label: Text(
                              'عرض $label ($count)',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              provider.setActiveTab(idx);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Sound Alert Status Capsule (Interactive Toggle)
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        merchantState.toggleSoundAlert();
                        SnackBarWidget.showCustomSnackBar(
                          context,
                          merchantState.isSoundAlertEnabled
                              ? 'تم تفعيل نغمة تنبيه الطلبات 🔔'
                              : 'تم كتم نغمة التنبيه 🔕',
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: merchantState.isSoundAlertEnabled
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: merchantState.isSoundAlertEnabled
                                ? const Color(0xFFFFD8BF)
                                : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OppositeIcon(
                              merchantState.isSoundAlertEnabled
                                  ? PhosphorIconsFill.bellRinging
                                  : PhosphorIconsRegular.bellSlash,
                              size: 15,
                              color: merchantState.isSoundAlertEnabled
                                  ? kPrimaryOrange
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              merchantState.isSoundAlertEnabled
                                  ? 'التنبيه الصوتي مفعل (اضغط للكتم)'
                                  : 'التنبيه الصوتي معطل (اضغط للتفعيل)',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: merchantState.isSoundAlertEnabled
                                  ? kPrimaryOrangeDark
                                  : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Manual Instant Refresh Button
                    ElevatedButton.icon(
                      icon: const OppositeIcon(PhosphorIconsRegular.arrowsClockwise, size: 16, color: Colors.white),
                      label: Text(
                        'تحديث فوري للطلبات',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryOrange,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        provider.silentRefresh();
                      },
                    ),
                  ]

                  // --- CASE 4: Tab 1 (قيد التحضير) Kitchen Empty State ---
                  else if (tabIndex == 1) ...[
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: OppositeIcon(
                          PhosphorIconsFill.cookingPot,
                          size: 36,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'المطبخ هادئ حالياً',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'لا توجد طلبات قيد التحضير والتجهيز حالياً.\nالطلبات المقبولة تظهر هنا لمتابعة وقت الطهي.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: () => provider.setActiveTab(0),
                      child: Text(
                        'عرض الطلبات الجديدة',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]

                  // --- CASE 5: Tab 2 (مع المندوب) Delivery Empty State ---
                  else if (tabIndex == 2) ...[
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFFBEB),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: OppositeIcon(
                          PhosphorIconsFill.moped,
                          size: 36,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد طلبات مع المناديب',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الطلبات الجاهزة التي تم تسليمها للمناديب ستظهر هنا لمتابعة مسار التوصيل المباشر.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ]

                  // --- CASE 6: Tab 3 (السجل) History Empty State ---
                  else ...[
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: OppositeIcon(
                          PhosphorIconsFill.clockCounterClockwise,
                          size: 36,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'سجل الطلبات فارغ',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ستجد هنا أرشيف كافة الطلبات المكتملة أو الملغاة للرجوع إليها في أي وقت.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


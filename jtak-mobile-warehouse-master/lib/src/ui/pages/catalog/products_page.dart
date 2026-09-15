import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/products_provider.dart';
import 'package:app_jtak_warehouse/src/ui/pages/catalog/product_edit_page.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/product_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

/// Alias for backwards compatibility
typedef ProductsPage = SearchPage;

/// ---------------------------------------------------------------------------
/// JTAK Merchant Catalog / Menu Management Page
/// (Horizontal Category Pills, Live Search, Operational Quick Filters, FAB & In-Stock Management)
/// ---------------------------------------------------------------------------
class SearchPage extends StatefulWidget {
  static const String routeName = '/SearchPage';
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await Provider.of<ProductsProvider>(context, listen: false).loadData();
    } catch (err) {
      if (mounted) {
        showDialog(context: context, builder: (_) => CustomDialog(message: err.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductsProvider>(context);
    final hasProducts = provider.productList.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar & Operational Quick Filters Header
            _buildSearchAndFiltersHeader(provider),

            // 2. Horizontal Scrollable Sticky Category Pills
            _buildCategoryPills(provider),

            const SizedBox(height: 4),

            // 3. Products List / Shimmer Loading / Empty State
            Expanded(
              child: RefreshIndicator(
                color: kPrimaryOrange,
                onRefresh: _loadData,
                child: provider.isBusy && provider.dataList.isEmpty
                    ? _buildLoadingSkeleton()
                    : _buildProductsList(provider),
              ),
            ),
          ],
        ),
      ),

      // 4. Floating Action Button: Shown ONLY when products exist to prevent duplicate CTA clutter in empty states
      floatingActionButton: hasProducts
          ? FloatingActionButton.extended(
              backgroundColor: kPrimaryOrange,
              elevation: 4,
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(
                  context,
                  ProductEditPage.routeName,
                  arguments: {
                    'initialCategoryId': provider.selectedCategoryId,
                  },
                );
              },
              icon: const OppositeIcon(PhosphorIconsBold.plus, color: Colors.white, size: 18),
              label: Text(
                'إضافة صنف جديد',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  /// Modern Search Bar with Full Width and Operational Quick Filter Badges
  Widget _buildSearchAndFiltersHeader(ProductsProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Full-Width Search Bar with Flipped Magnifying Glass
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => provider.setSearch(val),
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                color: const Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الوجبة، الوصف، أو القسم...',
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const OppositeIcon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const OppositeIcon(PhosphorIconsBold.x, size: 16, color: Color(0xFF64748B)),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _searchController.clear();
                          provider.setSearch(null);
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 2. Operational Stock Filter Pills Strip (All, Available, Out of Stock)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusFilterPill(
                  label: 'الكل',
                  count: provider.totalProductsCount,
                  isSelected: provider.stockFilter == ProductStockFilter.all,
                  onTap: () => provider.setStockFilter(ProductStockFilter.all),
                ),
                const SizedBox(width: 8),
                _buildStatusFilterPill(
                  label: 'المتوفر للطلب',
                  icon: PhosphorIconsFill.checkCircle,
                  iconColor: const Color(0xFF16A34A),
                  count: provider.inStockCount,
                  isSelected: provider.stockFilter == ProductStockFilter.inStock,
                  onTap: () => provider.setStockFilter(ProductStockFilter.inStock),
                ),
                const SizedBox(width: 8),
                _buildStatusFilterPill(
                  label: 'النافد / غير متوفر',
                  icon: PhosphorIconsRegular.prohibit,
                  iconColor: const Color(0xFF94A3B8),
                  count: provider.outOfStockCount,
                  isSelected: provider.stockFilter == ProductStockFilter.outOfStock,
                  onTap: () => provider.setStockFilter(ProductStockFilter.outOfStock),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Small Status Filter Pill
  Widget _buildStatusFilterPill({
    required String label,
    IconData? icon,
    Color? iconColor,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD6C2) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              OppositeIcon(icon, size: 14, color: isSelected ? kPrimaryOrange : (iconColor ?? const Color(0xFF64748B))),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFFC2410C) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryOrange : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Horizontal Scrollable Category Pills Bar
  Widget _buildCategoryPills(ProductsProvider provider) {
    // Only display categories that actually have products in this restaurant
    final availableCategories = provider.categories.where((cat) => provider.countForCategory(cat.id) > 0).toList();
    if (availableCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // "All" Pill
            _buildCategoryChip(
              title: 'الكل',
              count: provider.countForCategory(null),
              isSelected: provider.selectedCategoryId == null,
              onTap: () => provider.setSelectedCategory(null),
            ),
            const SizedBox(width: 8),

            // Dynamic Category Pills for categories the restaurant actually has
            ...availableCategories.map((cat) {
              final isSelected = provider.selectedCategoryId == cat.id;
              final count = provider.countForCategory(cat.id);
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildCategoryChip(
                  title: cat.title,
                  count: count,
                  isSelected: isSelected,
                  onTap: () => provider.setSelectedCategory(cat.id),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryOrange : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kPrimaryOrange : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kPrimaryOrange.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shimmer skeleton loader when first opening page or pulling fresh data
  Widget _buildLoadingSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 84),
      children: const [
        ProductCardSkeleton(),
        ProductCardSkeleton(),
        ProductCardSkeleton(),
        ProductCardSkeleton(),
      ],
    );
  }

  /// Intelligent Products List / Context-Aware Empty State Handler
  Widget _buildProductsList(ProductsProvider provider) {
    final list = provider.productList;

    if (list.isEmpty) {
      final isSearching = provider.search != null && provider.search!.trim().isNotEmpty;
      final isFilteredCategory = provider.selectedCategoryId != null;
      final isFilteredStock = provider.stockFilter != ProductStockFilter.all;

      // Find category title if selected
      String? currentCategoryTitle;
      if (isFilteredCategory) {
        final cat = provider.categories
            .cast<dynamic>()
            .firstWhere((c) => c.id == provider.selectedCategoryId, orElse: () => null);
        currentCategoryTitle = cat?.title;
      }

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Capsule with Opposite Direction Icon
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isSearching
                          ? const Color(0xFFF1F5F9)
                          : (isFilteredStock && provider.stockFilter == ProductStockFilter.outOfStock
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFFF0E8)),
                      shape: BoxShape.circle,
                    ),
                    child: OppositeIcon(
                      isSearching
                          ? PhosphorIconsRegular.magnifyingGlass
                          : (isFilteredStock && provider.stockFilter == ProductStockFilter.outOfStock
                              ? PhosphorIconsFill.checkCircle
                              : PhosphorIconsRegular.forkKnife),
                      size: 46,
                      color: isSearching
                          ? const Color(0xFF64748B)
                          : (isFilteredStock && provider.stockFilter == ProductStockFilter.outOfStock
                              ? const Color(0xFF16A34A)
                              : kPrimaryOrange),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title Text
                  Text(
                    isSearching
                        ? 'لا توجد نتائج مطابقة لبحثك'
                        : (isFilteredStock && provider.stockFilter == ProductStockFilter.outOfStock
                            ? 'رائع! جميع أصنافك متوفرة للطلب'
                            : (isFilteredCategory
                                ? 'لا توجد أصناف في قسم "${currentCategoryTitle ?? ''}"'
                                : 'قائمتك فارغة حتى الآن')),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle Text
                  Text(
                    isSearching
                        ? 'تأكد من كتابة الاسم بشكل صحيح أو قم بمسح نص البحث'
                        : (isFilteredStock && provider.stockFilter == ProductStockFilter.outOfStock
                            ? 'لا توجد أي وجبات نفدت أو غير متاحة في قائمتك حالياً'
                            : (isFilteredCategory
                                ? 'أضف وجبة جديدة لهذا القسم لتظهر مباشرة لزبائنك'
                                : 'أضف أول وجبة أو صنف لمتجرك لتظهر في تطبيق الزبائن وتبدأ باستقبال الطلبات')),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Context Action Button with Opposite Direction Icon
                  if (isSearching || (isFilteredStock && provider.stockFilter == ProductStockFilter.outOfStock))
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _searchController.clear();
                        provider.resetFilters();
                      },
                      icon: const OppositeIcon(PhosphorIconsRegular.arrowCounterClockwise, size: 18),
                      label: Text(
                        'إعادة تعيين الفلاتر والبحث',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryOrange,
                        side: const BorderSide(color: kPrimaryOrange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(
                          context,
                          ProductEditPage.routeName,
                          arguments: {
                            'initialCategoryId': provider.selectedCategoryId,
                          },
                        );
                      },
                      icon: const OppositeIcon(PhosphorIconsBold.plus, size: 18, color: Colors.white),
                      label: Text(
                        isFilteredCategory
                            ? 'إضافة صنف لقسم ${currentCategoryTitle ?? ''}'
                            : 'إضافة أول صنف للقائمة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryOrange,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                      ),
                    ),

                  // If category filter is active, provide secondary shortcut to view all items
                  if (isFilteredCategory) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        provider.setSelectedCategory(null);
                      },
                      child: Text(
                        'عرض جميع الأصناف في القائمة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 94), // Extra bottom padding for FAB & BottomNavBar
      itemCount: list.length,
      itemBuilder: (context, index) {
        return ProductSingleItem(list[index], key: ValueKey(list[index].productId));
      },
    );
  }
}

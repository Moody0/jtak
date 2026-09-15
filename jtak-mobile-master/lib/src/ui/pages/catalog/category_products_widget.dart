import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/category_products_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../../utils/custom_widgets/custom_scroll_behavior.dart';
import '../../sections/bottom_navigation.dart';
import '../../widgets/catalog/restaurant_card_widget.dart';
import '../../widgets/clean_shimmer_skeletons.dart';
import 'market_page.dart';
import 'restaurant_menu_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Category Products & Merchants Discovery Widget
/// Clean Layout • Enlarged Category Title • Direct Filtered Merchants Stream
/// ---------------------------------------------------------------------------

class CategoryProductsWidget extends StatefulWidget {
  final String categoryTitle;
  final String? assetPath;

  const CategoryProductsWidget({
    super.key,
    required this.categoryTitle,
    this.assetPath,
  });

  @override
  State<CategoryProductsWidget> createState() => _CategoryProductsWidgetState();
}

class _CategoryProductsWidgetState extends State<CategoryProductsWidget> {
  String _selectedMerchantFilter = 'الكل'; // 'الكل', 'مطاعم فقط', 'متاجر وسوبرماركت', 'توصيل مجاني', 'الأعلى تقييماً'

  void _handleMerchantTap(BuildContext context, MockRestaurantData merchant) {
    HapticFeedback.lightImpact();
    if (merchant.isMarket) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MarketPage(
            marketId: merchant.id,
            marketName: merchant.name,
            coverUrl: merchant.coverUrl,
            logoUrl: merchant.logoUrl,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RestaurantMenuPage(
            restaurantId: merchant.id,
            restaurantName: merchant.name,
            coverUrl: merchant.coverUrl,
            logoUrl: merchant.logoUrl,
          ),
        ),
      );
    }
  }

  List<MockRestaurantData> _getFilteredMerchants(List<MockRestaurantData> allMerchants) {
    if (_selectedMerchantFilter == 'مطاعم فقط') {
      return allMerchants.where((m) => !m.isMarket).toList();
    }
    if (_selectedMerchantFilter == 'متاجر وسوبرماركت') {
      return allMerchants.where((m) => m.isMarket).toList();
    }
    if (_selectedMerchantFilter == 'توصيل مجاني') {
      return allMerchants.where((m) => m.deliveryFee == 'مجاني').toList();
    }
    if (_selectedMerchantFilter == 'الأعلى تقييماً') {
      final sorted = List<MockRestaurantData>.from(allMerchants);
      sorted.sort((a, b) => b.rating.compareTo(a.rating));
      return sorted;
    }
    return allMerchants;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CategoryProductsProvider>(context);

    final merchants = provider.matchedMerchants;

    return ScrollConfiguration(
      behavior: CustomScrollBehavior(),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Large Bold Category Title Header (الفطور)
            _buildCategoryHeroBanner(widget.categoryTitle),

            // 2. Dedicated Merchants & Category Content Feed with Filter Chips
            if (provider.isBusy && merchants.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: RestaurantsListSkeleton(count: 3),
              )
            else
              _buildDedicatedMerchantsView(context, merchants),

            const SizedBox(height: BottomNavigation.height + 24),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Large Bold Category Title Header
  // ---------------------------------------------------------------------------
  Widget _buildCategoryHeroBanner(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.0)),
      ),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(
          color: kCharcoalDark,
          fontSize: 27,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Dedicated Merchants Tab View (Filter Chips & Restaurant Cards)
  // ---------------------------------------------------------------------------
  Widget _buildDedicatedMerchantsView(BuildContext context, List<MockRestaurantData> allMerchants) {
    final filterOptions = ['الكل', 'مطاعم فقط', 'متاجر وسوبرماركت', 'توصيل مجاني', 'الأعلى تقييماً'];
    final filteredMerchants = _getFilteredMerchants(allMerchants);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-filter chips row
        Container(
          height: 42,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filterOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final opt = filterOptions[index];
              final isSelected = opt == _selectedMerchantFilter;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedMerchantFilter = opt;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFF0E8) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? kPrimaryOrange : const Color(0xFFE5E7EB),
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: isSelected ? kPrimaryOrange : const Color(0xFF4B5563),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Merchants List
        if (filteredMerchants.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'لا توجد متاجر تطابق هذا الفلتر',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredMerchants.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final merchant = filteredMerchants[index];
              final itemData = merchant.toRestaurantItemData();

              return JtakRestaurantCard(
                data: itemData,
                onTap: () => _handleMerchantTap(context, merchant),
              );
            },
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/catalog/markets_provider.dart';
import '../../core/data/mock_catalog_data.dart';
import 'catalog/restaurant_card_widget.dart';
import 'clean_shimmer_skeletons.dart';

/// ---------------------------------------------------------------------------
/// JTAK Nearby Restaurants Section (مطاعم بالقرب منك)
///
/// Section 4 on Home Page:
/// - Header Row: "مطاعم بالقرب منك" with "عرض الكل >" action link
/// - Horizontal scrolling list of Standard Restaurant Cards (Component #2)
/// ---------------------------------------------------------------------------

class JtakNearbyRestaurantsSection extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAllTap;
  final ValueChanged<RestaurantItemData>? onRestaurantTap;

  const JtakNearbyRestaurantsSection({
    super.key,
    this.title = 'مطاعم بالقرب منك',
    this.onViewAllTap,
    this.onRestaurantTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Row (21px Bold Title & "عرض الكل <")
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: onViewAllTap,
                behavior: HitTestBehavior.opaque,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        PhosphorIconsRegular.caretLeft,
                        color: kPrimaryOrange,
                        size: 18,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'عرض الكل',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kPrimaryOrange,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Horizontal Scrollable List of Restaurant Cards
        SizedBox(
          height: 270,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(overscroll: false),
            child: Builder(
              builder: (context) {
                final marketsProv = Provider.of<MarketsProvider>(context);
                if (marketsProv.isLoading && marketsProv.restaurants.isEmpty) {
                  return _buildLoadingCards();
                }
                final restaurants = marketsProv.restaurants
                    .map((r) => r.toRestaurantItemData())
                    .toList();
                if (restaurants.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'لا توجد مطاعم متاحة حالياً',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: restaurants.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final item = restaurants[index];
                    return JtakHomeRestaurantCard(
                      data: item,
                      onTap: () {
                        if (onRestaurantTap != null) {
                          onRestaurantTap!(item);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildLoadingCards() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        return CleanShimmer(
          child: Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEBEBEF), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 130,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 90,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 160,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// Sliver wrapper for smooth use in CustomScrollView
/// ---------------------------------------------------------------------------
class SliverJtakNearbyRestaurantsSection extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAllTap;
  final ValueChanged<RestaurantItemData>? onRestaurantTap;

  const SliverJtakNearbyRestaurantsSection({
    super.key,
    this.title = 'مطاعم بالقرب منك',
    this.onViewAllTap,
    this.onRestaurantTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: JtakNearbyRestaurantsSection(
        title: title,
        onViewAllTap: onViewAllTap,
        onRestaurantTap: onRestaurantTap,
      ),
    );
  }
}

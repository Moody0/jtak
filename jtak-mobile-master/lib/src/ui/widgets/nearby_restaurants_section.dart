import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/catalog/markets_provider.dart';
import '../../core/data/mock_catalog_data.dart';
import 'catalog/restaurant_card_widget.dart';

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
                final restaurants = marketsProv.restaurants.isNotEmpty
                    ? marketsProv.restaurants
                        .map((r) => r.toRestaurantItemData())
                        .toList()
                    : MockCatalogData.restaurants
                        .map((r) => r.toRestaurantItemData())
                        .toList();
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

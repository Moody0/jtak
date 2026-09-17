import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/catalog/markets_provider.dart';
import '../../core/models/catalog/restaurant_category_model.dart';
import '../../core/services/locator.dart';
import '../../utils/providers/sol_api.dart';

/// ---------------------------------------------------------------------------
/// JTAK "browse by kind" strip on Home.
///
/// Entirely driven by the restaurant categories the administrator maintains in
/// the dashboard: the heading, the entries, their order and their artwork all
/// come from the backend. Entries with no merchant behind them are left out by
/// the backend, so the strip never offers a category that opens an empty list,
/// and the whole section hides itself when nothing is left to show.
/// ---------------------------------------------------------------------------

class CuisineCategoryItem {
  final int id;
  final String title;
  final String imageUrl;
  final int? productCategoryId;
  final String filterTag;
  final IconData fallbackIcon;

  const CuisineCategoryItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.productCategoryId,
    this.filterTag = '',
    this.fallbackIcon = Icons.restaurant_rounded,
  });

  factory CuisineCategoryItem.fromCategory(RestaurantCategoryModel category) {
    return CuisineCategoryItem(
      id: category.id,
      title: category.title,
      imageUrl: category.image,
      productCategoryId: category.productCategoryId,
      filterTag: category.filterTag,
    );
  }
}

class JtakVariousCuisinesSection extends StatefulWidget {
  /// Optional override. Left null, the heading comes from the dashboard.
  final String? title;
  final ValueChanged<CuisineCategoryItem>? onCategoryTap;

  const JtakVariousCuisinesSection({
    super.key,
    this.title,
    this.onCategoryTap,
  });

  @override
  State<JtakVariousCuisinesSection> createState() => _JtakVariousCuisinesSectionState();
}

class _JtakVariousCuisinesSectionState extends State<JtakVariousCuisinesSection> {
  double _scrollProgress = 0.0;
  List<CuisineCategoryItem> _items = const [];
  String _title = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await locator<SolApi>().getRequest('/RestaurantCategories');
      if (res is Map) {
        final config =
            RestaurantCategoriesConfigModel.fromMap(Map<String, dynamic>.from(res));
        if (!mounted) return;

        var sectionTitle = config.homeSectionTitle.trim();
        if (sectionTitle.isEmpty ||
            sectionTitle == 'مطابخ متنوعة' ||
            sectionTitle == 'أصناف متنوعة') {
          sectionTitle = 'أنواع المطاعم';
        }

        final activeRestaurants = locator.isRegistered<MarketsProvider>()
            ? locator<MarketsProvider>().restaurants
            : <RestaurantStoreModel>[];

        final validItems = config.homeItems.where((cat) {
          // If backend reported merchantCount > 0, it has active restaurants
          if (cat.merchantCount > 0) return true;
          // If productCategoryId is null, verify against live active restaurants
          if (cat.productCategoryId == null && activeRestaurants.isNotEmpty) {
            final q = cat.filterTag.isNotEmpty
                ? cat.filterTag.toLowerCase()
                : cat.title.toLowerCase();
            return activeRestaurants.any((r) =>
                r.cuisine.toLowerCase().contains(q) ||
                r.categoryTag.toLowerCase().contains(q) ||
                r.name.toLowerCase().contains(q));
          }
          return false;
        }).map(CuisineCategoryItem.fromCategory).toList();

        setState(() {
          _title = sectionTitle;
          _items = (config.showOnHome && config.enabled) ? validItems : const [];
          _loaded = true;
        });
        return;
      }
    } catch (_) {
      // Fall through: showing nothing is better than showing categories that
      // are not known to lead anywhere.
    }
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to browse means no section at all, rather than a heading over an
    // empty strip.
    if (!_loaded || _items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Section Header Title (21px Bold Typography)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            widget.title ?? _title,
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),

        // 2. Horizontal Scrollable Cuisines List
        SizedBox(
          height: 114,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification.metrics.maxScrollExtent > 0) {
                final progress = (notification.metrics.pixels / notification.metrics.maxScrollExtent).clamp(0.0, 1.0);
                if (progress != _scrollProgress) {
                  setState(() {
                    _scrollProgress = progress;
                  });
                }
              }
              return false;
            },
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(overscroll: false),
              child: ListView.separated(
                physics: const ClampingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildCuisineCard(item);
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 3. Expanding Fill Progress Bar (Anchored Right, expands Left)
        if (_items.length > 4) _buildExpandingFillProgressBar(_items.length),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCuisineCard(CuisineCategoryItem item) {
    return GestureDetector(
      onTap: () {
        if (widget.onCategoryTap != null) {
          widget.onCategoryTap!(item);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Soft Rounded Studio Food Box (80x74 with 18px radius)
            Container(
              width: 80,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17.2),
                // The dashboard may hold either a bundled asset path or a
                // uploaded image URL, so both are supported.
                child: item.imageUrl.isEmpty
                    ? Icon(item.fallbackIcon, color: kPrimaryOrange, size: 34)
                    : item.imageUrl.startsWith('assets')
                        ? Image.asset(
                            item.imageUrl,
                            width: 80,
                            height: 74,
                            fit: BoxFit.fill,
                            errorBuilder: (_, __, ___) => Icon(item.fallbackIcon, color: kPrimaryOrange, size: 34),
                          )
                        : CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            width: 80,
                            height: 74,
                            fit: BoxFit.fill,
                            errorWidget: (_, __, ___) => Icon(item.fallbackIcon, color: kPrimaryOrange, size: 34),
                          ),
              ),
            ),

            const SizedBox(height: 6),

            // 2. Bold Category Label (14px w800)
            Text(
              item.title,
              style: GoogleFonts.ibmPlexSansArabic(
                color: const Color(0xFF1F2937),
                fontSize: 14.0,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandingFillProgressBar(int count) {
    const trackWidth = 74.0;
    const trackHeight = 11.0;
    const pad = 2.0;
    const usableTrackWidth = trackWidth - (pad * 2);
    const usableTrackHeight = trackHeight - (pad * 2);
    final minFillWidth = (usableTrackWidth / (count / 2).clamp(1, 10)).clamp(18.0, 28.0);
    final fillWidth = minFillWidth + (_scrollProgress * (usableTrackWidth - minFillWidth));

    return Center(
      child: Container(
        width: trackWidth,
        height: trackHeight,
        padding: const EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(trackHeight / 2),
        ),
        alignment: Alignment.centerRight,
        child: Container(
          width: fillWidth,
          height: usableTrackHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF4B5563),
            borderRadius: BorderRadius.circular(usableTrackHeight / 2),
          ),
        ),
      ),
    );
  }

}

/// ---------------------------------------------------------------------------
/// Sliver wrapper for smooth use in CustomScrollView
/// ---------------------------------------------------------------------------
class SliverJtakVariousCuisinesSection extends StatelessWidget {
  final String? title;
  final ValueChanged<CuisineCategoryItem>? onCategoryTap;

  const SliverJtakVariousCuisinesSection({
    super.key,
    this.title,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: JtakVariousCuisinesSection(
        title: title,
        onCategoryTap: onCategoryTap,
      ),
    );
  }
}

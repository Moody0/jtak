import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/themes/colors.dart';

/// ---------------------------------------------------------------------------
/// JTAK Various Cuisines / Categories Section (مطابخ متنوعة)
///
/// Section 6 on Home Page:
/// - Header: "مطابخ متنوعة"
/// - Horizontal scroll of compact 18px rounded category cards (80x74 image box + bold label)
/// - High-resolution studio food photography matching reference style
/// - Real-time scroll progress fill bar anchored right, expanding left as you scroll
/// ---------------------------------------------------------------------------

class CuisineCategoryItem {
  final int id;
  final String title;
  final String imageUrl;
  final String? assetPath;
  final IconData fallbackIcon;

  const CuisineCategoryItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.assetPath,
    this.fallbackIcon = Icons.restaurant_rounded,
  });
}

class JtakVariousCuisinesSection extends StatefulWidget {
  final String title;
  final ValueChanged<CuisineCategoryItem>? onCategoryTap;

  const JtakVariousCuisinesSection({
    super.key,
    this.title = 'مطابخ متنوعة',
    this.onCategoryTap,
  });

  @override
  State<JtakVariousCuisinesSection> createState() => _JtakVariousCuisinesSectionState();
}

class _JtakVariousCuisinesSectionState extends State<JtakVariousCuisinesSection> {
  double _scrollProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Section Header Title (21px Bold Typography)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            widget.title,
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
                itemCount: _sampleCuisines.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = _sampleCuisines[index];
                  return _buildCuisineCard(item);
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 3. Expanding Fill Progress Bar (Anchored Right, expands Left)
        if (_sampleCuisines.length > 4) _buildExpandingFillProgressBar(_sampleCuisines.length),

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
                child: item.assetPath != null && item.assetPath!.isNotEmpty
                    ? Image.asset(
                        item.assetPath!,
                        width: 80,
                        height: 74,
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) => Icon(item.fallbackIcon, color: kPrimaryOrange, size: 34),
                      )
                    : (item.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            width: 80,
                            height: 74,
                            fit: BoxFit.fill,
                            errorWidget: (_, __, ___) => Icon(item.fallbackIcon, color: kPrimaryOrange, size: 34),
                          )
                        : Icon(item.fallbackIcon, color: kPrimaryOrange, size: 34)),
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

  static const List<CuisineCategoryItem> _sampleCuisines = [
    CuisineCategoryItem(
      id: 1,
      title: 'فطور',
      imageUrl: '',
      assetPath: 'assets/images/cuisines/breakfast.webp',
      fallbackIcon: Icons.breakfast_dining_rounded,
    ),
    CuisineCategoryItem(
      id: 2,
      title: 'مخبوزات',
      imageUrl: '',
      assetPath: 'assets/images/cuisines/bakery.webp',
      fallbackIcon: Icons.bakery_dining_rounded,
    ),
    CuisineCategoryItem(
      id: 3,
      title: 'بيتزا',
      imageUrl: '',
      assetPath: 'assets/images/cuisines/pizza.webp',
      fallbackIcon: Icons.local_pizza_rounded,
    ),
    CuisineCategoryItem(
      id: 4,
      title: 'برجر',
      imageUrl: '',
      assetPath: 'assets/images/cuisines/burger.webp',
      fallbackIcon: Icons.lunch_dining_rounded,
    ),
    CuisineCategoryItem(
      id: 5,
      title: 'شاورما',
      imageUrl: '',
      assetPath: 'assets/images/cuisines/shawarma.webp',
      fallbackIcon: Icons.kebab_dining_rounded,
    ),
    CuisineCategoryItem(
      id: 6,
      title: 'مشاوي',
      imageUrl: '',
      assetPath: 'assets/images/cuisines/grills.webp',
      fallbackIcon: Icons.outdoor_grill_rounded,
    ),
    CuisineCategoryItem(
      id: 7,
      title: 'حلويات',
      imageUrl: '',
      assetPath: 'assets/images/cuisines/sweets.webp',
      fallbackIcon: Icons.cake_rounded,
    ),
    CuisineCategoryItem(
      id: 8,
      title: 'مشروبات',
      imageUrl: '',
      assetPath: 'assets/images/cuisines/drinks.webp',
      fallbackIcon: Icons.local_cafe_rounded,
    ),
  ];
}

/// ---------------------------------------------------------------------------
/// Sliver wrapper for smooth use in CustomScrollView
/// ---------------------------------------------------------------------------
class SliverJtakVariousCuisinesSection extends StatelessWidget {
  final String title;
  final ValueChanged<CuisineCategoryItem>? onCategoryTap;

  const SliverJtakVariousCuisinesSection({
    super.key,
    this.title = 'مطابخ متنوعة',
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

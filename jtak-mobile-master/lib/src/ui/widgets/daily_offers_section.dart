import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/initial_data_provider.dart';
import '../../core/models/banner_model.dart';
import '../../utils/custom_widgets/shimmer.dart';
import '../../utils/utilities/global_var.dart';

/// ---------------------------------------------------------------------------
/// JTAK Daily Offers Section (العروض اليومية)
///
/// Features (Exact Match to User Reference 2):
/// - Clean headerless full-width presentation
/// - Centered horizontal carousel with 90% viewport fraction
/// - Symmetrical peeking rounded edges of previous & next banners on left and right
/// - Infinite smooth circular loop (item 0 has previous peeking on right and next on left)
/// - Rounded card radius (24px) with soft ambient shadow
/// - Centered circular dots indicator underneath
/// - Auto-play sliding timer with smooth snapping
/// ---------------------------------------------------------------------------

const List<String> _defaultBannerImages = [
  'assets/images/promos/banner_groceries_delivery.jpg',
  'assets/images/promos/banner_burger_deals.jpg',
  'assets/images/promos/banner_exclusive_gifts.jpg',
  'assets/images/promos/banner_shawarma_feast.jpg',
  'assets/images/promos/banner_pizza_deals.jpg',
];

class JtakDailyOffersSection extends StatefulWidget {
  final String title;
  final VoidCallback? onViewAllTap;

  const JtakDailyOffersSection({
    super.key,
    this.title = '', // Default to clean headerless layout matching reference
    this.onViewAllTap,
  });

  @override
  State<JtakDailyOffersSection> createState() => _JtakDailyOffersSectionState();
}

class _JtakDailyOffersSectionState extends State<JtakDailyOffersSection> {
  static const int _kLoopMultiplier = 1000;
  PageController? _pageController;
  int _currentPageIndex = 0;
  int _actualPageIndex = 0;
  int _currentBannerCount = 0;
  Timer? _autoPlayTimer;
  Timer? _resumeAutoPlayTimer;

  void _ensureController(int bannerCount) {
    if (bannerCount == 0) return;
    if (_pageController != null && _currentBannerCount == bannerCount) return;

    _currentBannerCount = bannerCount;
    // Exactly at a multiple of bannerCount so (initialPage % bannerCount == 0)
    _actualPageIndex = bannerCount * (_kLoopMultiplier ~/ 2);
    _currentPageIndex = 0;

    _pageController?.dispose();
    _pageController = PageController(
      viewportFraction: 0.90,
      initialPage: _actualPageIndex,
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureController(_defaultBannerImages.length);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController == null || !_pageController!.hasClients) return;
      int count = _getBannerCount();
      if (count <= 1) return;

      _actualPageIndex += 1;
      _pageController!.animateToPage(
        _actualPageIndex,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onUserStartInteraction() {
    _autoPlayTimer?.cancel();
    _resumeAutoPlayTimer?.cancel();
  }

  void _onUserEndInteraction() {
    _resumeAutoPlayTimer?.cancel();
    _resumeAutoPlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _startAutoPlay();
      }
    });
  }

  int _getBannerCount() {
    try {
      InitialDataProvider provider = Provider.of<InitialDataProvider>(context, listen: false);
      if (GlobalVar.checkListNotEmpty(provider.dailyOffersBanners)) {
        return provider.dailyOffersBanners.length;
      }
    } catch (_) {}
    return _defaultBannerImages.length;
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _resumeAutoPlayTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    InitialDataProvider provider = Provider.of<InitialDataProvider>(context);
    List<BannerModel> apiBanners = provider.dailyOffersBanners;
    final bool hasApiBanners = GlobalVar.checkListNotEmpty(apiBanners);

    List<String> validUrls = [];
    if (hasApiBanners) {
      validUrls = apiBanners
          .map((b) => (b.featuredImage != null && b.featuredImage!.isNotEmpty)
              ? (b.featuredImage!.startsWith('http')
                  ? b.featuredImage!
                  : GlobalVar.getImageUrl(b.featuredImage!, width: 800, height: 450, crop: false))
              : '')
          .where((url) => url.isNotEmpty)
          .toList();
    }

    final List<String> bannerList = validUrls.isNotEmpty ? validUrls : _defaultBannerImages;

    if (bannerList.isEmpty) {
      return const SizedBox.shrink();
    }

    _ensureController(bannerList.length);

    const double cardHeight = 204.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Optional Header Row (only if non-empty title explicitly passed)
        if (widget.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: kCharcoalDark,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onViewAllTap,
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
                        const SizedBox(width: 4),
                        Text(
                          'جميع العروض',
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

        // 2. Centered Infinite Loop Banner Carousel (Freezes on user scroll, resumes after 3s)
        SizedBox(
          height: cardHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification is ScrollStartNotification) {
                _onUserStartInteraction();
              } else if (notification is ScrollEndNotification) {
                _onUserEndInteraction();
              }
              return false;
            },
            child: Listener(
              onPointerDown: (_) => _onUserStartInteraction(),
              onPointerUp: (_) => _onUserEndInteraction(),
              onPointerCancel: (_) => _onUserEndInteraction(),
              child: PageView.builder(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                padEnds: true, // Centers the active banner perfectly with symmetric peeking sides
                clipBehavior: Clip.none,
                itemCount: bannerList.length * _kLoopMultiplier,
                onPageChanged: (index) {
                  setState(() {
                    _actualPageIndex = index;
                    _currentPageIndex = index % bannerList.length;
                  });
                },
                itemBuilder: (context, index) {
                  final bannerIndex = index % bannerList.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: _buildPureImageBanner(
                      imagePath: bannerList[bannerIndex],
                      height: cardHeight,
                      onTap: () {
                        if (widget.onViewAllTap != null) {
                          widget.onViewAllTap!();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 3. Circular Dots Indicator (Matching Reference: Active Dark Circle, Inactive Grey)
        if (bannerList.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              bannerList.length,
              (index) {
                final bool isSelected = index == _currentPageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  width: isSelected ? 8.5 : 8.0,
                  height: isSelected ? 8.5 : 8.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF1F2937) // Active Dark Charcoal Dot
                        : const Color(0xFFE5E7EB), // Inactive Light Grey Dot
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 6),
      ],
    );
  }

  /// Pure Image Banner Container (100% full-bleed image with crisp 24px rounded corners and soft shadow)
  Widget _buildPureImageBanner({
    required String imagePath,
    required double height,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFFF3F4F6),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: imagePath.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: imagePath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: height,
                  fadeInDuration: const Duration(milliseconds: 220),
                  fadeOutDuration: const Duration(milliseconds: 150),
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: const Color(0xFFF1F5F9),
                    highlightColor: const Color(0xFFF8FAFC),
                    child: Container(
                      width: double.infinity,
                      height: height,
                      color: const Color(0xFFF1F5F9),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFFE5E7EB),
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 36),
                    ),
                  ),
                )
              : Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: height,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE5E7EB),
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 36),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Sliver wrapper for smooth use in CustomScrollView
/// ---------------------------------------------------------------------------
class SliverJtakDailyOffersSection extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAllTap;

  const SliverJtakDailyOffersSection({
    super.key,
    this.title = '', // Headerless by default
    this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: JtakDailyOffersSection(
        title: title,
        onViewAllTap: onViewAllTap,
      ),
    );
  }
}



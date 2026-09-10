import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/initial_data_provider.dart';
import '../../core/models/banner_model.dart';
import '../../utils/custom_widgets/shimmer.dart';
import '../../utils/utilities/global_var.dart';
import '../pages/catalog/market_page.dart';
import '../pages/catalog/restaurant_menu_page.dart';
import '../pages/catalog/restaurants_list_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK "Don't Miss" Section (لا تفوتها)
///
/// Features:
/// - Fully editable through the Admin Dashboard (synced via InitialDataProvider).
/// - Supports multiple banners (1, 2, 3+) with seamless infinite loop.
/// - Clean card presentation WITHOUT pagination dots or progress indicators.
/// - Exact visual styling: 168px height, 18px rounded radius, soft ambient shadow.
/// - Auto-swaps every 3 seconds with smooth cubic ease.
/// - Interactive: User can manually swipe at any time.
/// - Pause-on-touch interaction: auto-swap pauses while dragging and resumes after 3s.
/// - Deep linking: Tapping routes to linked merchant/restaurant or deals catalog.
/// ---------------------------------------------------------------------------

class DontMissBannerItem {
  final int? id;
  final String imageUrl;
  final String title;
  final String? url;

  const DontMissBannerItem({
    this.id,
    required this.imageUrl,
    this.title = '',
    this.url,
  });
}

const List<DontMissBannerItem> _defaultDontMissBanners = [
  DontMissBannerItem(
    id: 1,
    imageUrl: 'assets/images/promos/banner_burger_deals.jpg',
    title: 'عروض التوفير الكبرى - خصم حتى 40%',
  ),
  DontMissBannerItem(
    id: 2,
    imageUrl: 'assets/images/promos/banner_groceries_delivery.jpg',
    title: 'توصيل سوبرماركت سريع ومجاني',
  ),
  DontMissBannerItem(
    id: 3,
    imageUrl: 'assets/images/promos/banner_shawarma_feast.jpg',
    title: 'وليمة الشاورما والمشويات العائلية',
  ),
  DontMissBannerItem(
    id: 4,
    imageUrl: 'assets/images/promos/banner_pizza_deals.jpg',
    title: 'بيتزا إيطالية طازجة مع مقرمشات مجانية',
  ),
];

class JtakDontMissSection extends StatefulWidget {
  final String title;
  final List<String>? customImages;
  final VoidCallback? onBannerTap;

  const JtakDontMissSection({
    super.key,
    this.title = 'لا تفوتها',
    this.customImages,
    this.onBannerTap,
  });

  @override
  State<JtakDontMissSection> createState() => _JtakDontMissSectionState();
}

class _JtakDontMissSectionState extends State<JtakDontMissSection> {
  static const int _kLoopMultiplier = 1000;
  static const double _bannerHeight = 168.0;

  PageController? _pageController;
  int _actualPageIndex = 0;
  int _lastBannerCount = 0;

  Timer? _autoPlayTimer;
  Timer? _resumeAutoPlayTimer;

  void _ensureController(int bannerCount) {
    if (bannerCount <= 1) return;
    if (_pageController != null && _lastBannerCount == bannerCount) return;

    _lastBannerCount = bannerCount;
    _actualPageIndex = bannerCount * (_kLoopMultiplier ~/ 2);

    _pageController?.dispose();
    _pageController = PageController(
      viewportFraction: 1.0,
      initialPage: _actualPageIndex,
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureController(_defaultDontMissBanners.length);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (_pageController == null || !_pageController!.hasClients) return;
      if (_lastBannerCount <= 1) return;

      _actualPageIndex += 1;
      _pageController!.animateToPage(
        _actualPageIndex,
        duration: const Duration(milliseconds: 500),
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

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _resumeAutoPlayTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  List<DontMissBannerItem> _resolveBanners(InitialDataProvider? provider) {
    // 1. Explicit custom images if passed
    if (widget.customImages != null && widget.customImages!.isNotEmpty) {
      return widget.customImages!
          .map((img) => DontMissBannerItem(imageUrl: img))
          .toList();
    }

    // 2. Dynamic live banners from backend InitialDataProvider
    if (provider != null) {
      final apiBanners = provider.dontMissBanners;
      if (apiBanners.isNotEmpty) {
        final List<DontMissBannerItem> items = [];
        for (final BannerModel b in apiBanners) {
          final rawImg = (b.featuredImage ?? '').trim();
          if (rawImg.isNotEmpty) {
            final fullUrl = rawImg.startsWith('http')
                ? rawImg
                : GlobalVar.getImageUrl(rawImg, width: 800, height: 450, crop: false);
            items.add(
              DontMissBannerItem(
                id: b.id,
                imageUrl: fullUrl,
                title: b.title ?? '',
                url: b.url,
              ),
            );
          }
        }
        if (items.isNotEmpty) return items;
      }
    }

    // 3. Fallback seeded banners
    return _defaultDontMissBanners;
  }

  void _handleTap(BuildContext context, DontMissBannerItem item) {
    if (widget.onBannerTap != null) {
      widget.onBannerTap!();
      return;
    }

    final rawUrl = (item.url ?? '').trim();
    if (rawUrl.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RestaurantsListPage(initialFilter: 'عروض'),
        ),
      );
      return;
    }

    // Parse deep-link targets: "merchant:18", "restaurant:8", "market:19"
    final cleanUrl = rawUrl.split('#').first.trim();
    if (cleanUrl.startsWith('merchant:') || cleanUrl.startsWith('market:')) {
      final idStr = cleanUrl.split(':').last;
      final id = int.tryParse(idStr);
      if (id != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketPage(
              marketId: id,
              marketName: item.title.isNotEmpty ? item.title : 'المتجر',
            ),
          ),
        );
        return;
      }
    } else if (cleanUrl.startsWith('restaurant:')) {
      final idStr = cleanUrl.split(':').last;
      final id = int.tryParse(idStr);
      if (id != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantMenuPage(
              restaurantId: id,
              restaurantName: item.title.isNotEmpty ? item.title : 'المطعم',
            ),
          ),
        );
        return;
      }
    }

    // Fallback: Open promotional catalog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RestaurantsListPage(initialFilter: 'عروض'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialData = Provider.of<InitialDataProvider>(context);
    final banners = _resolveBanners(initialData);

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    _ensureController(banners.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Section Header Title ("لا تفوتها")
        if (widget.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
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

        // 2. Banner Container (Single Card or Auto-swapping Swipeable PageView WITHOUT Pagination)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: banners.length == 1 ? 16 : 8),
          child: banners.length == 1
              ? _buildBannerCard(context, banners.first, _bannerHeight)
              : SizedBox(
                  height: _bannerHeight,
                  width: double.infinity,
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
                        clipBehavior: Clip.none,
                        itemCount: banners.length * _kLoopMultiplier,
                        onPageChanged: (index) {
                          _actualPageIndex = index;
                        },
                        itemBuilder: (context, index) {
                          final item = banners[index % banners.length];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: _buildBannerCard(context, item, _bannerHeight),
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 6),
      ],
    );
  }

  /// Exact replica of the original single banner card:
  /// - Full width
  /// - 168px height
  /// - 18px rounded corners
  /// - Soft ambient box shadow (offset 0,4; blur 12; alpha 0x14)
  Widget _buildBannerCard(BuildContext context, DontMissBannerItem item, double height) {
    final imagePath = item.imageUrl;

    return GestureDetector(
      onTap: () => _handleTap(context, item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFFF3F4F6),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
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
class SliverJtakDontMissSection extends StatelessWidget {
  final String title;
  final List<String>? customImages;
  final VoidCallback? onBannerTap;

  const SliverJtakDontMissSection({
    super.key,
    this.title = 'لا تفوتها',
    this.customImages,
    this.onBannerTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: JtakDontMissSection(
        title: title,
        customImages: customImages,
        onBannerTap: onBannerTap,
      ),
    );
  }
}

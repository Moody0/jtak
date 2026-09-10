import 'package:flutter/material.dart';

import '../../utils/custom_widgets/shimmer.dart';

/// ---------------------------------------------------------------------------
/// JTAK Smooth Shine Skeleton System
///
/// Exact visual match to reference design (WhatsApp Image 2026-09-10 at 12.05.55 PM):
/// - Crisp, pure white background with seamless borderless cards
/// - Base tone: #F0F2F5 (soft, ultra-clean neutral)
/// - Highlight peak: #FFFFFF (smooth luminous white shine sweep)
/// - Exact geometry: Promo cards, 4-square squircles, circular avatars,
///   stadium capsule pills, and multi-line feed items
/// ---------------------------------------------------------------------------

/// Universal Smooth Shine wrapper applying the fluid white reflection.
class CleanShimmer extends StatelessWidget {
  final Widget child;
  final Duration period;
  final ShimmerDirection direction;

  const CleanShimmer({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1400),
    this.direction = ShimmerDirection.ltr,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      period: period,
      direction: direction,
      gradient: const LinearGradient(
        begin: Alignment(-1.0, -0.3),
        end: Alignment(1.0, 0.3),
        colors: [
          Color(0xFFF0F2F5),
          Color(0xFFF0F2F5),
          Color(0xFFFFFFFF),
          Color(0xFFF0F2F5),
          Color(0xFFF0F2F5),
        ],
        stops: [0.0, 0.30, 0.50, 0.70, 1.0],
      ),
      child: child,
    );
  }
}

/// Reusable borderless rounded rectangular or circular skeleton block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;
  final Color color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.margin,
    this.color = Colors.white,
  });

  const SkeletonBox.circle({
    super.key,
    required double size,
    this.margin,
    this.color = Colors.white,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 1. Home Page Full Moving Smooth Shine Skeleton
/// ---------------------------------------------------------------------------
class HomePageSkeleton extends StatelessWidget {
  const HomePageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: CleanShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Safe Area top spacing
              SizedBox(height: MediaQuery.of(context).padding.top + 10),

              // 1. Top Header: Location / Destination & Back / Menu Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        SkeletonBox.circle(size: 38),
                        SizedBox(width: 10),
                        SkeletonBox(width: 95, height: 16, borderRadius: 5),
                      ],
                    ),
                    const SkeletonBox.circle(size: 38),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Search Stadium Capsule Bar (BorderRadius 24)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: const [
                      SkeletonBox.circle(size: 18),
                      SizedBox(width: 12),
                      SkeletonBox(width: 160, height: 13, borderRadius: 4),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Section 1: Large Promo Cards Carousel (Rounded Rectangle Cards)
              SizedBox(
                height: 165,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, __) => const SkeletonBox(
                    width: 175,
                    height: 165,
                    borderRadius: 20,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. Section Title Bar 1
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const SkeletonBox(width: 150, height: 16, borderRadius: 6),
              ),
              const SizedBox(height: 14),

              // 5. Section 2: 4 Square Category Cards (Horizontal Row)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    4,
                    (_) => const SkeletonBox(
                      width: 76,
                      height: 76,
                      borderRadius: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 6. Section Title Bar 2
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const SkeletonBox(width: 130, height: 16, borderRadius: 6),
              ),
              const SizedBox(height: 14),

              // 7. Section 3: Circular Avatars with Subtitle Bars
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    4,
                    (_) => Column(
                      children: const [
                        SkeletonBox.circle(size: 64),
                        SizedBox(height: 8),
                        SkeletonBox(width: 48, height: 9, borderRadius: 5),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 8. Section 4: Capsule Filter Pills (Stadium Shapes)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, __) => const SkeletonBox(
                    width: 105,
                    height: 38,
                    borderRadius: 24,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 9. Section 5: Vertical Feed Item (Text lines + Image block)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: 170, height: 15, borderRadius: 5),
                          SizedBox(height: 10),
                          SkeletonBox(width: 120, height: 12, borderRadius: 4),
                          SizedBox(height: 10),
                          SkeletonBox(width: 80, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const SkeletonBox(
                      width: 110,
                      height: 110,
                      borderRadius: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 2. Restaurants List Page Feed Skeleton
/// ---------------------------------------------------------------------------
class RestaurantsListSkeleton extends StatelessWidget {
  final int count;

  const RestaurantsListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return CleanShimmer(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (_, __) => const _RestaurantVerticalCardSkeleton(),
      ),
    );
  }
}

/// Sliver variant for use inside CustomScrollView
class SliverRestaurantsListSkeleton extends StatelessWidget {
  final int count;

  const SliverRestaurantsListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverToBoxAdapter(
        child: CleanShimmer(
          child: Column(
            children: List.generate(
              count,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: _RestaurantVerticalCardSkeleton(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 3. Orders List Page Skeleton
/// ---------------------------------------------------------------------------
class OrdersListSkeleton extends StatelessWidget {
  final int count;

  const OrdersListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: CleanShimmer(
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, __) => const _OrderCardSkeleton(),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 4. Market Page Shelves Skeleton
/// ---------------------------------------------------------------------------
class MarketPageSkeleton extends StatelessWidget {
  const MarketPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CleanShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Pills Horizontal Row
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => const SkeletonBox(
                width: 90,
                height: 38,
                borderRadius: 20,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Shelves
          for (int i = 0; i < 2; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonBox(width: 140, height: 16, borderRadius: 5),
                  SkeletonBox(width: 50, height: 13, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 215,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => const _MarketProductCardSkeleton(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 5. Category Products / Sub-catalog Skeleton
/// ---------------------------------------------------------------------------
class CategoryProductsSkeleton extends StatelessWidget {
  const CategoryProductsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: CleanShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Category Banner
              Container(
                height: 135,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 8),

              // Filter Chips Row
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, __) => const SkeletonBox(
                    width: 85,
                    height: 36,
                    borderRadius: 20,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Vertical Merchants Feed
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: List.generate(
                    3,
                    (index) => const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: _RestaurantVerticalCardSkeleton(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 6. Product Details Skeleton
/// ---------------------------------------------------------------------------
class ProductDetailsSkeleton extends StatelessWidget {
  const ProductDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: CleanShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Hero Image
              Container(
                height: 280,
                width: double.infinity,
                color: Colors.white,
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 200, height: 22, borderRadius: 6),
                    SizedBox(height: 10),
                    SkeletonBox(width: 100, height: 18, borderRadius: 5),
                    SizedBox(height: 16),
                    SkeletonBox(width: double.infinity, height: 13, borderRadius: 4),
                    SizedBox(height: 6),
                    SkeletonBox(width: double.infinity, height: 13, borderRadius: 4),
                    SizedBox(height: 6),
                    SkeletonBox(width: 180, height: 13, borderRadius: 4),
                    SizedBox(height: 28),
                    SkeletonBox(width: 120, height: 18, borderRadius: 5),
                    SizedBox(height: 14),
                    SkeletonBox(width: double.infinity, height: 48, borderRadius: 14),
                    SizedBox(height: 10),
                    SkeletonBox(width: double.infinity, height: 48, borderRadius: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// INTERNAL HELPER SKELETON CARDS (Seamless borderless design)
/// ---------------------------------------------------------------------------

class _RestaurantVerticalCardSkeleton extends StatelessWidget {
  const _RestaurantVerticalCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Solid cover block (Borderless)
        const SkeletonBox(
          width: double.infinity,
          height: 155,
          borderRadius: 18,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 44, height: 44, borderRadius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 140, height: 15, borderRadius: 4),
                  SizedBox(height: 6),
                  SkeletonBox(width: 90, height: 12, borderRadius: 4),
                ],
              ),
            ),
            const SkeletonBox(width: 48, height: 20, borderRadius: 6),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            SkeletonBox(width: 70, height: 20, borderRadius: 6),
            SizedBox(width: 8),
            SkeletonBox(width: 60, height: 20, borderRadius: 6),
            SizedBox(width: 8),
            SkeletonBox(width: 75, height: 20, borderRadius: 6),
          ],
        ),
      ],
    );
  }
}

class _MarketProductCardSkeleton extends StatelessWidget {
  const _MarketProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBox(
          width: 130,
          height: 130,
          borderRadius: 18,
        ),
        const SizedBox(height: 8),
        const SkeletonBox(width: 95, height: 12, borderRadius: 4),
        const SizedBox(height: 6),
        const SkeletonBox(width: 60, height: 12, borderRadius: 4),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            SkeletonBox(width: 45, height: 14, borderRadius: 4),
            SizedBox(width: 40),
            SkeletonBox(width: 26, height: 26, borderRadius: 8),
          ],
        ),
      ],
    );
  }
}

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(width: 42, height: 42, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 130, height: 15, borderRadius: 4),
                    SizedBox(height: 5),
                    SkeletonBox(width: 80, height: 11, borderRadius: 4),
                  ],
                ),
              ),
              const SkeletonBox(width: 72, height: 26, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 14),
          const SkeletonBox(
            width: double.infinity,
            height: 1,
            color: Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 14),
          const SkeletonBox(width: 180, height: 12, borderRadius: 4),
          const SizedBox(height: 6),
          const SkeletonBox(width: 140, height: 12, borderRadius: 4),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonBox(width: 90, height: 16, borderRadius: 4),
              SkeletonBox(width: 84, height: 32, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

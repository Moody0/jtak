import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/catalog/markets_provider.dart';
import '../pages/catalog/market_page.dart';
import 'clean_shimmer_skeletons.dart';

class BigStoreData {
  final int id;
  final String name;
  final String eta;
  final String? tagline;
  final String logoText;
  final String? logoBoxedText;
  final Color logoColor;
  final String? logoUrl;
  final String? assetPath;

  const BigStoreData({
    required this.id,
    required this.name,
    required this.eta,
    required this.logoText,
    required this.logoColor,
    this.tagline,
    this.logoBoxedText,
    this.logoUrl,
    this.assetPath,
  });

  factory BigStoreData.fromModel(MarketStoreModel model) {
    return BigStoreData(
      id: model.id,
      name: model.name,
      eta: model.eta,
      tagline: model.tagline,
      logoText: model.logoText,
      logoBoxedText: model.logoBoxedText,
      logoColor: model.logoColor,
      logoUrl: model.logoUrl,
      assetPath: model.assetPath,
    );
  }
}

/// ---------------------------------------------------------------------------
/// Flagship JTAK Market Hero Spotlight Section (سوبرماركت ومقاضي جيتك الحصري)
///
/// Tailored for the single-market architecture:
/// - Replaces multi-store carousel with a unified flagship dark-store spotlight
/// - Highlights combined Best Market + Clover Mall inventory
/// - Immediate 1-tap navigation into MarketPage (id: 12)
/// ---------------------------------------------------------------------------
class JtakBigStoresSection extends StatelessWidget {
  final String title;
  final ValueChanged<BigStoreData>? onStoreTap;

  const JtakBigStoresSection({
    super.key,
    this.title = 'جيتك ماركت',
    this.onStoreTap,
  });

  void _navigateToMarket(BuildContext context, BigStoreData store) {
    if (onStoreTap != null) {
      onStoreTap!(store);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MarketPage(
            marketId: store.id,
            marketName: store.name,
            logoUrl: (store.logoUrl != null && store.logoUrl!.isNotEmpty)
                ? store.logoUrl
                : store.assetPath,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketsProvider>(
      builder: (context, marketsProvider, child) {
        final List<BigStoreData> stores = marketsProvider.markets
            .map((m) => BigStoreData.fromModel(m))
            .toList();

        final BigStoreData flagshipStore = stores.isNotEmpty
            ? stores.first
            : BigStoreData.fromModel(MarketsProvider.jtakMarketModel);

        if (marketsProvider.isLoading && stores.isEmpty) {
          return _buildLoadingSkeleton();
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (Title only)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: kCharcoalDark,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),

              // 2. Hero Spotlight Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _navigateToMarket(context, flagshipStore),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFEBEBEF),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo Box
                        _buildEmblem(flagshipStore),

                        const SizedBox(width: 12),

                        // Store Meta & Badges
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'جيتك ماركت',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: kCharcoalDark,
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Transform.flip(
                                    flipX: true,
                                    child: const Icon(
                                      PhosphorIconsFill.sealCheck,
                                      color: kPrimaryOrange,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'آلاف المنتجات • خضار، ألبان، مونة ومنظفات',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: const Color(0xFF4B5563),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // ETA Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3EB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.flip(
                                      flipX: true,
                                      child: const Icon(
                                        PhosphorIconsFill.lightning,
                                        color: kPrimaryOrange,
                                        size: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      flagshipStore.eta,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: kPrimaryOrange,
                                        fontSize: 11.0,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Shop Now Pill Button with opposite-facing arrow
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: kPrimaryOrange,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'تسوق',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: Colors.white,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                PhosphorIconsBold.caretRight,
                                color: Colors.white,
                                size: 11,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmblem(BigStoreData store) {
    const double size = 62.0;
    final bool hasUrl = store.logoUrl != null && store.logoUrl!.isNotEmpty;
    final bool hasAsset =
        store.assetPath != null && store.assetPath!.isNotEmpty;

    Widget imageContent;
    if (hasUrl) {
      imageContent = CachedNetworkImage(
        imageUrl: store.logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: const Color(0xFFF3F4F6)),
        errorWidget: (_, __, ___) => hasAsset
            ? Image.asset(
                store.assetPath!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackLogo(store, size),
              )
            : _buildFallbackLogo(store, size),
      );
    } else if (hasAsset) {
      imageContent = Image.asset(
        store.assetPath!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackLogo(store, size),
      );
    } else {
      imageContent = _buildFallbackLogo(store, size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: imageContent,
      ),
    );
  }

  Widget _buildFallbackLogo(BigStoreData store, double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFFF5C00),
      alignment: Alignment.center,
      child: Text(
        'جيتك',
        style: GoogleFonts.ibmPlexSansArabic(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return CleanShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEBEBEF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SliverJtakBigStoresSection extends StatelessWidget {
  final String title;
  final ValueChanged<BigStoreData>? onStoreTap;

  const SliverJtakBigStoresSection({
    super.key,
    this.title = 'جيتك ماركت',
    this.onStoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: JtakBigStoresSection(
        title: title,
        onStoreTap: onStoreTap,
      ),
    );
  }
}

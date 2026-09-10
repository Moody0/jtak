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

class JtakBigStoresSection extends StatefulWidget {
  final String title;
  final ValueChanged<BigStoreData>? onStoreTap;

  const JtakBigStoresSection({
    super.key,
    this.title = 'المتاجر الكبرى بالقرب منك',
    this.onStoreTap,
  });

  @override
  State<JtakBigStoresSection> createState() => _JtakBigStoresSectionState();
}

class _JtakBigStoresSectionState extends State<JtakBigStoresSection> {
  late final PageController _pageController = PageController(viewportFraction: 0.85);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketsProvider>(
      builder: (context, marketsProvider, child) {
        final stores = marketsProvider.markets.map((m) => BigStoreData.fromModel(m)).toList();
        final int pageCount = (stores.length / 2).ceil();

        if (marketsProvider.isLoading && stores.isEmpty) {
          return _buildLoadingSkeleton();
        }

        if (pageCount == 0) {
          return const SizedBox.shrink();
        }

        const double cardHeight = 112.0;
        const double cardGap = 12.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                ],
              ),
            ),
            SizedBox(
              height: (cardHeight * 2) + cardGap,
              child: PageView.builder(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                padEnds: false,
                clipBehavior: Clip.none,
                itemCount: pageCount,
                itemBuilder: (context, pageIndex) {
                  final int firstIndex = pageIndex * 2;
                  final BigStoreData topStore = stores[firstIndex];
                  final BigStoreData? bottomStore =
                      firstIndex + 1 < stores.length ? stores[firstIndex + 1] : null;

                  return Padding(
                    padding: const EdgeInsets.only(right: 16, left: 4),
                    child: Column(
                      children: [
                        _buildStoreCard(topStore, cardHeight),
                        const SizedBox(height: cardGap),
                        if (bottomStore != null) _buildStoreCard(bottomStore, cardHeight),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 180,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 112,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEBEBEF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(BigStoreData store, double height) {
    return GestureDetector(
      onTap: () {
        if (widget.onStoreTap != null) {
          widget.onStoreTap!(store);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MarketPage(
                marketId: store.id,
                marketName: store.name,
                logoUrl: store.assetPath ?? store.logoUrl,
              ),
            ),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEBEBEF), width: 1.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Row(
            children: [
              _buildLogoBlock(store),
              Expanded(child: _buildStoreInfo(store)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoBlock(BigStoreData store) {
    const Color defaultGrey = Color(0xFFEEEEEE);

    Widget content;
    final bool hasAsset = store.assetPath != null && store.assetPath!.isNotEmpty;
    final bool hasUrl = store.logoUrl != null && store.logoUrl!.isNotEmpty;

    if (hasUrl) {
      content = CachedNetworkImage(
        imageUrl: store.logoUrl!,
        width: 104,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => hasAsset
            ? Image.asset(
                store.assetPath!,
                width: 104,
                height: double.infinity,
                fit: BoxFit.cover,
              )
            : const CleanShimmer(
                child: SkeletonBox(
                  width: 104,
                  height: double.infinity,
                  borderRadius: 12,
                ),
              ),
        errorWidget: (_, __, ___) => hasAsset
            ? Image.asset(
                store.assetPath!,
                width: 104,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildTextLogoFallback(store),
              )
            : _buildTextLogoFallback(store),
      );
    } else if (hasAsset) {
      content = Image.asset(
        store.assetPath!,
        width: 104,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildTextLogoFallback(store),
      );
    } else {
      content = _buildTextLogoFallback(store);
    }

    return Container(
      width: 104,
      height: double.infinity,
      color: defaultGrey,
      alignment: Alignment.center,
      child: content,
    );
  }

  Widget _buildTextLogoFallback(BigStoreData store) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            store.logoText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFF1F2937),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          if (store.logoBoxedText != null) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
              ),
              child: Text(
                store.logoBoxedText!,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFF374151),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreInfo(BigStoreData store) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (store.tagline != null && store.tagline!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  PhosphorIconsFill.shoppingBag,
                  color: kPrimaryOrange,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    store.tagline!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF4B5563),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ],
          Text(
            store.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.clock,
                color: kCharcoalMedium,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                store.eta,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalMedium,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SliverJtakBigStoresSection extends StatelessWidget {
  final String title;
  final ValueChanged<BigStoreData>? onStoreTap;

  const SliverJtakBigStoresSection({
    super.key,
    this.title = 'المتاجر الكبرى بالقرب منك',
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

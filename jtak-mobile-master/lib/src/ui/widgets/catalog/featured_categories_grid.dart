import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/categories_provider.dart';
import '../../../core/models/catalog/category_model.dart';
import '../../../core/models/catalog/home_category_tile.dart';
import '../clean_shimmer_skeletons.dart';
import '../../pages/catalog/categories_page.dart';
import '../../pages/catalog/market_page.dart';
import '../../pages/catalog/restaurants_list_page.dart';
import '../../pages/catalog/search_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Featured Categories Grid Component (Dynamic Backend Driven)
///
/// Fully powered by backend database categories:
/// - Zero hardcoded mock categories
/// - Displays backend category title and uploaded images (or vector icons)
/// - Shows sleek Shimmer skeleton while loading
/// - Pure dynamic routing on tap
/// ---------------------------------------------------------------------------

class JtakFeaturedCategoriesGrid extends StatelessWidget {
  final int maxCount;
  final ValueChanged<int>? onCategoryTap;

  const JtakFeaturedCategoriesGrid({
    super.key,
    this.maxCount = 8,
    this.onCategoryTap,
  });

  /// Opens whatever the dashboard attached to this tile. The destination is
  /// data, so a new or renamed category routes correctly without the app
  /// knowing anything about the words in its title.
  void _openTile(BuildContext context, HomeCategoryTile tile) {
    switch (tile.linkType) {
      case HomeCategoryLinkType.merchant:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketPage(
              marketId: tile.merchantId!,
              marketName: tile.title,
              logoUrl: tile.imageUrl ?? '',
            ),
          ),
        );
        return;

      case HomeCategoryLinkType.merchantKind:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantsListPage(
              merchantKind: tile.merchantKind,
              title: tile.title,
            ),
          ),
        );
        return;

      case HomeCategoryLinkType.search:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchPage(initialQuery: tile.searchTerm),
          ),
        );
        return;

      case HomeCategoryLinkType.productCategory:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoriesPage(
              0,
              categoryId: tile.productCategoryId,
              categoryTitle: tile.title,
            ),
          ),
        );
        return;

      case HomeCategoryLinkType.unknown:
        // Filtered out before rendering; nothing sensible to open.
        return;
    }
  }

  /// Fallback for backends that predate the curated grid: treat a plain
  /// category as a product-category tile so routing stays on one path.
  void _openCategory(BuildContext context, CategoryModel cat) {
    if (cat.id == null) return;
    _openTile(
      context,
      HomeCategoryTile(
        id: 'category-${cat.id}',
        title: cat.title ?? '',
        imageUrl: cat.icon,
        linkType: HomeCategoryLinkType.productCategory,
        productCategoryId: cat.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    CategoriesProvider categoriesProvider =
        Provider.of<CategoriesProvider>(context);
    // The featured list comes from Home and preserves the sequence chosen in
    // the dashboard. Fall back gracefully for app versions/backends that have
    // not yet deployed the new Home response.
    // The curated grid is the source of truth. The plain category lists below
    // are only a fallback for backends that do not send it yet.
    final tiles = categoriesProvider.homeCategoryTiles;

    List<CategoryModel> categories =
        categoriesProvider.featuredDataList.isNotEmpty
            ? categoriesProvider.featuredDataList
            : categoriesProvider.dataList.isNotEmpty
                ? categoriesProvider.dataList
                : CategoriesProvider.defaultCategories;

    // If currently busy and no dynamic categories are available yet, show shimmer
    if (categoriesProvider.isBusy && categoriesProvider.dataList.isEmpty) {
      return _buildSkeletonGrid();
    }

    if (tiles.isNotEmpty) {
      final tileItems = maxCount > 0 ? tiles.take(maxCount).toList() : tiles;
      return _buildGrid(
        itemCount: tileItems.length,
        cardBuilder: (context, index) {
          final tile = tileItems[index];
          return _buildCategoryCard(
            context: context,
            title: tile.title,
            iconUrl: tile.imageUrl,
            onTap: () {
              if (onCategoryTap != null) {
                onCategoryTap!(index);
              } else {
                _openTile(context, tile);
              }
            },
          );
        },
      );
    }

    final items =
        maxCount > 0 ? categories.take(maxCount).toList() : categories;

    return _buildGrid(
      itemCount: items.length,
      cardBuilder: (context, index) {
        final CategoryModel cat = items[index];
        return _buildCategoryCard(
          context: context,
          title: cat.title ?? '',
          iconUrl: cat.icon,
          onTap: () {
            if (onCategoryTap != null) {
              onCategoryTap!(index);
            } else {
              _openCategory(context, cat);
            }
          },
        );
      },
    );
  }

  Widget _buildGrid({
    required int itemCount,
    required Widget Function(BuildContext, int) cardBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 10,
          // The card uses the available tile height so labels cannot push the
          // column beyond the grid's tight constraints.
          childAspectRatio: 0.74,
        ),
        itemCount: itemCount,
        itemBuilder: cardBuilder,
      ),
    );
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required String title,
    String? iconUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Sleek Full-Bleed Image Container (14px radius)
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEBEBEF), width: 0.8),
              ),
              child: _buildCategoryImage(title, iconUrl),
            ),
          ),

          const SizedBox(height: 5),

          // 2. Category Title Text (12.5px bold)
          // Reserve two lines for every label so the grid stays aligned.
          // Names longer than two lines are truncated with an ellipsis.
          SizedBox(
            height: 30,
            child: Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String? _getLocalAssetForCategory(String title, String? iconUrl) {
    final t = title.trim();
    if (t == 'المطاعم' || t == 'مطاعم') {
      return 'assets/images/categories/cat_restaurants.jpg';
    }
    if (t == 'البقالة' || t == 'بقالة' || t == 'غذائيات') {
      return 'assets/images/categories/cat_grocery.webp';
    }
    if (t.contains('حلويات') || t.contains('مخبوزات')) {
      return 'assets/images/categories/cat_sweets.jpg';
    }
    if (t.contains('قهوة') || t.contains('مشروبات')) {
      return 'assets/images/categories/cat_drinks.webp';
    }
    if (t.contains('خضار') || t.contains('فواكه')) {
      return 'assets/images/categories/cat_vegetables.webp';
    }
    if (t.contains('لحوم') || t.contains('دواجن')) {
      return 'assets/images/categories/cat_meat.webp';
    }

    if (iconUrl != null && iconUrl.startsWith('assets/')) {
      return iconUrl;
    }
    return null;
  }

  Widget _buildCategoryImage(String title, String? iconUrl) {
    final localAsset = _getLocalAssetForCategory(title, iconUrl);

    // If iconUrl is a vector icon font
    if (iconUrl != null &&
        (iconUrl.startsWith('fas ') || iconUrl.startsWith('fa-'))) {
      return _buildFontAwesomeIcon(iconUrl);
    }

    // Resolve network URL if provided
    String? networkUrl;
    if (iconUrl != null &&
        iconUrl.isNotEmpty &&
        !iconUrl.startsWith('assets/')) {
      if (iconUrl.startsWith('http://') || iconUrl.startsWith('https://')) {
        networkUrl = iconUrl;
      } else {
        networkUrl = 'https://api.jtak.app/api/v1/services/Download/$iconUrl';
      }
    }

    Widget buildFallback() {
      if (localAsset != null) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            localAsset,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.category_outlined,
                  color: Color(0xFF94A3B8), size: 28),
            ),
          ),
        );
      }
      return const Center(
        child:
            Icon(Icons.category_outlined, color: Color(0xFF94A3B8), size: 28),
      );
    }

    if (networkUrl != null) {
      return CachedNetworkImage(
        imageUrl: networkUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        fadeInDuration: const Duration(milliseconds: 150),
        imageBuilder: (context, imageProvider) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
          ),
        ),
        placeholder: (_, __) => const CleanShimmer(
          child: SizedBox.expand(
            child: ColoredBox(color: Colors.white),
          ),
        ),
        errorWidget: (_, __, ___) => buildFallback(),
      );
    }

    return buildFallback();
  }

  Widget _buildFontAwesomeIcon(String iconString) {
    IconData icon = Icons.restaurant_rounded;
    final lower = iconString.toLowerCase();
    if (lower.contains('burger') || lower.contains('hamburger')) {
      icon = Icons.lunch_dining_rounded;
    } else if (lower.contains('fire') || lower.contains('grill')) {
      icon = Icons.local_fire_department_rounded;
    } else if (lower.contains('cookie') ||
        lower.contains('cake') ||
        lower.contains('sweet')) {
      icon = Icons.cake_rounded;
    } else if (lower.contains('egg') || lower.contains('breakfast')) {
      icon = Icons.egg_rounded;
    } else if (lower.contains('coffee') || lower.contains('cup')) {
      icon = Icons.local_cafe_rounded;
    } else if (lower.contains('pizza')) {
      icon = Icons.local_pizza_rounded;
    } else if (lower.contains('basket') || lower.contains('shopping')) {
      icon = Icons.shopping_basket_rounded;
    }

    return Center(
      child: Icon(
        icon,
        color: kPrimaryOrange,
        size: 32,
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: CleanShimmer(
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 10,
            childAspectRatio: 0.74,
          ),
          itemCount: 8,
          itemBuilder: (_, __) {
            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEBEBEF), width: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  height: 30,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 50,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Sliver wrapper for smooth use in CustomScrollView
/// ---------------------------------------------------------------------------
class SliverJtakFeaturedCategories extends StatelessWidget {
  final int maxCount;
  final ValueChanged<int>? onCategoryTap;

  const SliverJtakFeaturedCategories({
    super.key,
    this.maxCount = 8,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: JtakFeaturedCategoriesGrid(
        maxCount: maxCount,
        onCategoryTap: onCategoryTap,
      ),
    );
  }
}

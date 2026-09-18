import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/categories_provider.dart';
import '../../../core/models/catalog/category_model.dart';
import '../../../core/models/catalog/home_category_tile.dart';
import '../clean_shimmer_skeletons.dart';
import '../../pages/catalog/catalog_scope.dart';
import '../../pages/catalog/categories_page.dart';
import '../../pages/catalog/market_page.dart';
import '../../pages/catalog/restaurants_list_page.dart';
import '../../pages/catalog/search_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Featured Categories Grid Component (Canonical 4-Section Architecture)
///
/// Features:
/// - EXACTLY 4 Top-Level Authoritative Categories in order:
///   1. البقالة (Grocery & Supermarkets, merging "المتاجر")
///   2. المطاعم (Restaurants)
///   3. قهوة ومشروبات (Coffee & Beverages)
///   4. صيدليات (Pharmacies)
/// - Pure dynamic routing with Scoped Catalog Pages
/// ---------------------------------------------------------------------------

class JtakFeaturedCategoriesGrid extends StatelessWidget {
  final int maxCount;
  final ValueChanged<int>? onCategoryTap;

  const JtakFeaturedCategoriesGrid({
    super.key,
    this.maxCount = 4,
    this.onCategoryTap,
  });

  void _openTile(BuildContext context, HomeCategoryTile tile) {
    // 1. Check canonical scope by title or category id first
    final scope = CatalogScope.fromCategory(
      tile.productCategoryId,
      tile.title,
    );
    if (scope != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RestaurantsListPage(
            catalogScope: scope,
            title: scope.title,
          ),
        ),
      );
      return;
    }

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
        return;
    }
  }

  void _openCategory(BuildContext context, CategoryModel cat) {
    final title = cat.title ?? '';
    final scope = CatalogScope.fromCategory(cat.id, title);
    if (scope != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RestaurantsListPage(
            catalogScope: scope,
            title: scope.title,
          ),
        ),
      );
      return;
    }

    _openTile(
      context,
      HomeCategoryTile(
        id: 'category-${cat.id ?? 0}',
        title: title,
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

    // Section visibility toggle controlled from Admin Dashboard
    if (!categoriesProvider.homeCategoriesEnabled) {
      return const SizedBox.shrink();
    }

    // If currently busy and no categories are available yet, show shimmer
    if (categoriesProvider.isBusy &&
        categoriesProvider.dataList.isEmpty &&
        categoriesProvider.homeCategoryTiles.isEmpty) {
      return _buildSkeletonGrid();
    }

    // 1. If Admin configured dynamic home category tiles, render those tiles (e.g. 4, 8, etc.)
    if (categoriesProvider.homeCategoryTiles.isNotEmpty) {
      final tiles = categoriesProvider.homeCategoryTiles;
      return _buildGrid(
        itemCount: tiles.length,
        cardBuilder: (context, index) {
          final tile = tiles[index];
          final resolvedIcon = (tile.imageUrl != null && tile.imageUrl!.isNotEmpty)
              ? tile.imageUrl
              : categoriesProvider.getIconForCategory(tile.title);

          return _buildCategoryCard(
            context: context,
            title: tile.title,
            iconUrl: resolvedIcon,
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

    // 2. Canonical 4 top-level service sections fallback (البقالة, المطاعم, قهوة ومشروبات, صيدليات)
    final List<CategoryModel> categories = categoriesProvider.homeSections;

    return _buildGrid(
      itemCount: categories.length,
      cardBuilder: (context, index) {
        final CategoryModel cat = categories[index];
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
    if (t == 'البقالة' || t == 'بقالة' || t == 'غذائيات' || t.contains('سوبرماركت') || t.contains('ماركت')) {
      return 'assets/images/categories/cat_grocery.webp';
    }
    if (t == 'المطاعم' || t == 'مطاعم') {
      return 'assets/images/categories/cat_restaurants.jpg';
    }
    if (t.contains('قهوة') || t.contains('مشروبات') || t.contains('كافيه')) {
      return 'assets/images/categories/cat_drinks.webp';
    }
    if (t.contains('صيدلي') || t.contains('صيدلية') || t.contains('صيدليات') || t.contains('أدوية')) {
      return 'assets/images/categories/cat_grocery.webp';
    }
    if (t.contains('حلويات') || t.contains('مخبوزات')) {
      return 'assets/images/categories/cat_sweets.jpg';
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
    // If iconUrl is a vector icon font
    if (iconUrl != null &&
        (iconUrl.startsWith('fas ') || iconUrl.startsWith('fa-'))) {
      return _buildFontAwesomeIcon(iconUrl);
    }

    // Resolve network URL with version token for instantaneous cache busting upon Admin updates
    String? networkUrl;
    if (iconUrl != null &&
        iconUrl.isNotEmpty &&
        !iconUrl.startsWith('assets/')) {
      if (iconUrl.startsWith('http://') || iconUrl.startsWith('https://')) {
        networkUrl = iconUrl;
      } else {
        var clean = iconUrl.trim().replaceAll(r'\', '/');
        while (clean.startsWith('/')) {
          clean = clean.substring(1);
        }
        final lower = clean.toLowerCase();
        if (lower.endsWith('.webp') || lower.endsWith('.svg') || lower.endsWith('.gif') || lower.endsWith('.avif')) {
          networkUrl = 'https://api.jtak.app/api/v1/services/Download/$clean?v=$clean';
        } else {
          networkUrl = 'https://api.jtak.app/api/v1/services/ImagePreview/$clean?w=250&h=250&crop=false&v=$clean';
        }
      }
    }

    Widget buildFallback() {
      final localAsset = _getLocalAssetForCategory(title, iconUrl);
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

    if (networkUrl != null && networkUrl.isNotEmpty) {
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
          itemCount: 4,
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
    this.maxCount = 4,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoriesProvider = Provider.of<CategoriesProvider>(context);
    if (!categoriesProvider.homeCategoriesEnabled) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: JtakFeaturedCategoriesGrid(
        maxCount: maxCount,
        onCategoryTap: onCategoryTap,
      ),
    );
  }
}

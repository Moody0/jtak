import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main_imports.dart';
import '../../config/themes/colors.dart';
import '../../core/controllers/app_parameters_provider.dart';
import '../../core/controllers/catalog/categories_provider.dart';
import '../../core/controllers/catalog/markets_provider.dart';
import '../../core/controllers/initial_data_provider.dart';
import '../../core/services/locator.dart';
import '../sections/bottom_navigation.dart';
import '../widgets/big_stores_section.dart';
import '../widgets/catalog/featured_categories_grid.dart';
import '../widgets/daily_offers_section.dart';
import '../widgets/delivery_offers_section.dart';
import '../widgets/dont_miss_section.dart';
import '../widgets/nearby_restaurants_section.dart';
import '../widgets/top_app_bar_widget.dart';
import '../widgets/various_cuisines_section.dart';
import '../../core/data/mock_catalog_data.dart';
import 'catalog/market_page.dart';
import 'catalog/restaurant_menu_page.dart';
import 'catalog/restaurants_list_page.dart';
import 'catalog/categories_page.dart';
import 'catalog/search_page.dart';

class HomePage extends StatefulWidget {
  static const String routeName = '/HomePage';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHomeInitialData();
    });
  }

  Future<void> _loadHomeInitialData() async {
    final stopwatch = Stopwatch()..start();
    try {
      final initialData = Provider.of<InitialDataProvider>(context, listen: false);
      final categoriesProvider = Provider.of<CategoriesProvider>(context, listen: false);
      final marketsProvider = Provider.of<MarketsProvider>(context, listen: false);
      final appParams = Provider.of<AppParametersProvider>(context, listen: false);

      // If location coordinates are empty, ensure background resolution is active
      if (appParams.mainAddressService.isCoordinateEmpty()) {
        appParams.loadMainParameters(context).catchError((e) => log('Home loadMainParameters error: $e'));
      }

      // Wait for essential data providers to finish fetching
      await Future.wait([
        initialData.getInitData(context).catchError((e) => log('InitialData error: $e')),
        categoriesProvider.loadData().catchError((e) => log('CategoriesProvider error: $e')),
        marketsProvider.loadMarkets().catchError((e) => log('MarketsProvider error: $e')),
        marketsProvider.loadPopularMeals().catchError((e) => log('PopularMeals error: $e')),
      ]).timeout(const Duration(seconds: 12), onTimeout: () => []);

      // Pre-cache images while skeleton is showing so everything appears immediately together
      if (mounted) {
        final precacheTasks = <Future>[];

        // 1. Top Category Icons
        final topCats = categoriesProvider.dataList.take(8).toList();
        for (final cat in topCats) {
          final icon = cat.icon;
          if (icon != null && icon.isNotEmpty && !icon.startsWith('fas ') && !icon.startsWith('fa-')) {
            final url = (icon.startsWith('http://') || icon.startsWith('https://'))
                ? icon
                : 'https://api.jtak.app/api/v1/services/Download/$icon';
            precacheTasks.add(
              precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {}),
            );
          }
        }

        // 2. Daily Offer Banners
        final banners = initialData.bannerList.take(4).toList();
        for (final b in banners) {
          final photo = b.featuredImage;
          if (photo != null && photo.isNotEmpty) {
            final url = (photo.startsWith('http://') || photo.startsWith('https://'))
                ? photo
                : 'https://api.jtak.app/api/v1/services/Download/$photo';
            precacheTasks.add(
              precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {}),
            );
          }
        }

        // 3. Big Stores & Top Restaurant Logos
        final topMarkets = marketsProvider.markets.take(4).toList();
        for (final m in topMarkets) {
          final logo = m.logoUrl;
          if (logo != null && logo.isNotEmpty && logo.startsWith('http')) {
            precacheTasks.add(
              precacheImage(CachedNetworkImageProvider(logo), context).catchError((_) {}),
            );
          }
        }

        if (precacheTasks.isNotEmpty) {
          await Future.wait(precacheTasks).timeout(const Duration(seconds: 2), onTimeout: () => []);
        }
      }
    } catch (e) {
      log('HomePage initial load error: $e');
    } finally {
      // Ensure skeleton is displayed smoothly for at least 500ms to prevent harsh flashing
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 500) {
        await Future.delayed(Duration(milliseconds: 500 - elapsed));
      }
    }
  }

  Future<void> _handleRefresh() async {
    try {
      final initialData = Provider.of<InitialDataProvider>(context, listen: false);
      final categoriesProvider = Provider.of<CategoriesProvider>(context, listen: false);
      final marketsProvider = Provider.of<MarketsProvider>(context, listen: false);
      await Future.wait([
        initialData.getInitData(context),
        categoriesProvider.loadData(),
        marketsProvider.loadMarkets(),
        marketsProvider.loadPopularMeals(),
      ]);
    } catch (e) {
      log('HomePage refresh error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    log('^^^^^^^^^^^^^^^^^^^^^^^^^^^^ HomePage.build');

    return Scaffold(
      backgroundColor: kPageBackground,
      body: RefreshIndicator(
        color: kPrimaryOrange,
        backgroundColor: Colors.white,
        edgeOffset: 0.0,
        displacement: 64.0,
        onRefresh: _handleRefresh,
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(overscroll: false),
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // 1. Top App Bar with Delivery Address & Search Bar (Seamless Natural Scroll)
              SliverJtakHeader(
                onSearchTap: () {
                  Navigator.pushNamed(context, SearchPage.routeName);
                },
                onFilterTap: () {
                  // Open filter bottom sheet
                },
              ),

              // 2. Featured Categories (4 Columns x Max 8 Categories)
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
              const SliverJtakFeaturedCategories(
                maxCount: 8,
              ),

              // 3. Daily Offers Section (العروض اليومية - Banners with Scroll Progress Bar)
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverJtakDailyOffersSection(
                onViewAllTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RestaurantsListPage(initialFilter: 'عروض'),
                    ),
                  );
                },
              ),

              // 4. Nearby Restaurants Section (مطاعم بالقرب منك)
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverJtakNearbyRestaurantsSection(
                onViewAllTap: () {
                  Navigator.pushNamed(context, RestaurantsListPage.routeName);
                },
                onRestaurantTap: (restaurant) {
                  final mock = MockCatalogData.getRestaurantById(restaurant.id);
                  final nameLower = restaurant.name.toLowerCase();
                  final catLower = restaurant.category.toLowerCase();
                  final isMarket = mock.isMarket ||
                      catLower.contains('سوبرماركت') ||
                      catLower.contains('ماركت') ||
                      catLower.contains('market') ||
                      nameLower.contains('ماركت') ||
                      nameLower.contains('سوبر ماركت') ||
                      nameLower.contains('سوبرماركت') ||
                      nameLower.contains('مارت') ||
                      nameLower.contains('كلوفر') ||
                      nameLower.contains('clover') ||
                      nameLower.contains('مول') ||
                      nameLower.contains('mall') ||
                      nameLower.contains('market') ||
                      nameLower.contains('mart');

                  if (isMarket) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MarketPage(
                          marketId: restaurant.id,
                          marketName: restaurant.name,
                          coverUrl: restaurant.coverUrl,
                          logoUrl: restaurant.logoUrl,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RestaurantMenuPage(
                          restaurantId: restaurant.id,
                          restaurantName: restaurant.name,
                          coverUrl: restaurant.coverUrl,
                          logoUrl: restaurant.logoUrl,
                        ),
                      ),
                    );
                  }
                },
              ),

              // 5. Most Popular Dishes Section (الأكثر طلباً - Meal Quick-Add Cards)
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverJtakDeliveryOffersSection(
                onViewAllTap: () {
                  Navigator.pushNamed(context, RestaurantsListPage.routeName);
                },
                onMealTap: (meal) {
                  final mockItem = MockCatalogData.getMenuItemById(meal.id);
                  int resId = meal.merchantId;
                  if (resId <= 0 && mockItem != null) {
                    resId = mockItem.restaurantId;
                  }

                  // Resolve restaurant cover and logo
                  RestaurantStoreModel? storeModel;
                  if (locator.isRegistered<MarketsProvider>()) {
                    final prov = locator<MarketsProvider>();
                    if (resId > 0) {
                      storeModel = prov.restaurants
                          .where((r) => r.id == resId)
                          .firstOrNull;
                    }
                    if (storeModel == null) {
                      final nameLower = meal.merchantName.toLowerCase().trim();
                      storeModel = prov.restaurants.where((r) =>
                          r.name.toLowerCase().contains(nameLower) ||
                          nameLower.contains(r.name.toLowerCase())).firstOrNull;
                    }
                  }

                  final mockRes = resId > 0
                      ? MockCatalogData.getRestaurantById(resId)
                      : MockCatalogData.getRestaurantByName(meal.merchantName);

                  final targetResId =
                      storeModel?.id ?? (resId > 0 ? resId : mockRes.id);
                  final targetResName = storeModel?.name ??
                      (meal.merchantName.isNotEmpty
                          ? meal.merchantName
                          : mockRes.name);
                  final targetCover =
                      storeModel?.coverUrl ?? mockRes.coverUrl;
                  final targetLogo =
                      storeModel?.logoUrl ?? mockRes.logoUrl;

                  if (meal.isMarket || (storeModel == null && mockRes.isMarket)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MarketPage(
                          marketId: targetResId,
                          marketName: targetResName,
                          coverUrl: targetCover,
                          logoUrl: targetLogo,
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestaurantMenuPage(
                        restaurantId: targetResId,
                        restaurantName: targetResName,
                        coverUrl: targetCover,
                        logoUrl: targetLogo,
                        initialSelectedItemId: meal.id,
                        initialSelectedItem: mockItem,
                      ),
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverJtakBigStoresSection(
                onStoreTap: (store) {
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
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              const SliverJtakDontMissSection(),

              // 8. Various Cuisines & Categories (أنواع المطاعم - Canonical #40)
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverJtakVariousCuisinesSection(
                title: 'أنواع المطاعم',
                onCategoryTap: (item) {
                  // The category id is the real association, so prefer it. The
                  // keyword filter is only for entries the admin has not linked
                  // to a category yet.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => item.productCategoryId != null
                          ? CategoriesPage(
                              0,
                              categoryId: item.productCategoryId,
                              categoryTitle: item.title,
                            )
                          : RestaurantsListPage(initialFilter: item.title),
                    ),
                  );
                },
              ),

              // Bottom Navigation Spacing
              SliverToBoxAdapter(child: context.addHeight(BottomNavigation.height + 24))
            ],
          ),
        ),
      ),
    );
  }
}

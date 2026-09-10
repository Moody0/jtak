import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app/home_navigation_provider.dart';
import '../../../core/controllers/catalog/favorite_product_provider.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../account/login_page.dart';
import '../../widgets/catalog/favorite_widgets.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Favorites Page (صفحة المفضلة - Flat Clean Minimalist Design)
/// ---------------------------------------------------------------------------

class FavoritePage extends StatefulWidget {
  static const String routeName = '/FavoritePage';

  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoriteProductProvider>(
      builder: (context, favProvider, _) {
        final restaurants = favProvider.favoriteRestaurants;
        final meals = favProvider.favoriteMeals;
        final totalCount = favProvider.totalFavoritesCount;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: _buildAppBar(totalCount),
          body: Column(
            children: [
              // 0. Guest Sync Banner (Nudge to sync favorites across devices)
              _buildGuestSyncBanner(totalCount),

              // 1. Modern Pill Segmented Tab Switcher (Flat Design)
              _buildSegmentedTabBar(restaurants.length, meals.length),

              // 2. Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    // Tab 1: Favorite Restaurants & Markets
                    _buildRestaurantsTab(restaurants),

                    // Tab 2: Favorite Meals & Dishes
                    _buildMealsTab(meals),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuestSyncBanner(int totalFavorites) {
    final isGuest = !locator<AuthenticationService>().isLogin();
    if (!isGuest || totalFavorites == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED), // Soft Peach/Orange container
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEDD5), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kPrimaryOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(PhosphorIconsFill.cloudArrowUp, color: kPrimaryOrange, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'احفظ مفضلتك عبر أجهزتك',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: kCharcoalDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'سجّل دخولك لمزامنة قائمتك على السحابة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF6B7280),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, LoginPage.routeName);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
              decoration: BoxDecoration(
                color: kPrimaryOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'تسجيل الدخول',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int totalCount) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            PhosphorIconsFill.heart,
            color: Color(0xFFEF4444),
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            'المفضلة',
            style: GoogleFonts.ibmPlexSansArabic(
              color: kCharcoalDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (totalCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$totalCount',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kPrimaryOrange,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedTabBar(int restaurantCount, int mealCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
          ),
          labelColor: kPrimaryOrange,
          unselectedLabelColor: const Color(0xFF6B7280),
          labelStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsFill.storefront, size: 16),
                  const SizedBox(width: 6),
                  Text('المطاعم ($restaurantCount)'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsFill.forkKnife, size: 16),
                  const SizedBox(width: 6),
                  Text('الأطباق ($mealCount)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantsTab(List restaurants) {
    if (restaurants.isEmpty) {
      return _buildEmptyState(
        icon: PhosphorIconsFill.storefront,
        title: 'لا توجد مطاعم في المفضلة',
        description: 'احفظ مطاعمك ومتاجرك المفضلة بالضغط على أيقونة القلب للوصول السريع لطلب أشهى الوجبات.',
      );
    }

    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 90),
      itemCount: restaurants.length,
      itemBuilder: (context, index) {
        return FavoriteRestaurantCard(restaurant: restaurants[index]);
      },
    );
  }

  Widget _buildMealsTab(List meals) {
    if (meals.isEmpty) {
      return _buildEmptyState(
        icon: PhosphorIconsFill.forkKnife,
        title: 'قائمة أطباقك المفضلة فارغة',
        description: 'أضف وجباتك وأطباقك المفضلة هنا لإعادة طلبها بضغطة زر واحدة في أي وقت.',
      );
    }

    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 90),
      itemCount: meals.length,
      itemBuilder: (context, index) {
        return FavoriteMealCard(item: meals[index]);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0E8),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 48,
                  color: kPrimaryOrange,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                color: const Color(0xFF6B7280),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Provider.of<HomeNavigationProvider>(context, listen: false).changePage(0);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: kPrimaryOrange,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'استكشف القائمة الآن',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

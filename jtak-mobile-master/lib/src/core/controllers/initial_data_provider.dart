import 'package:flutter/material.dart';
import 'package:jtek_app/src/core/controllers/catalog/categories_provider.dart';
import 'package:jtek_app/src/core/models/banner_model.dart';
import 'package:jtek_app/src/core/models/user/user_model.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';
import 'package:provider/provider.dart';

import '../models/catalog/category_model.dart';
import 'package:jtek_app/src/core/models/catalog/home_category_tile.dart';

import '../services/locator.dart';
import '../../utils/providers/sol_api.dart';
import 'app/base_provider.dart';

class InitialDataProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  List<BannerModel> bannerList = [];

  Future<void> getInitData(BuildContext context) async {
    try {
      Map data = await _api.getRequest('/Home');

      if (data.containsKey('user') && data['user'] != null) {
        locator<AuthenticationService>().user = UserModel.fromMap(data['user']);
      }

      if (data.containsKey('banners') && data['banners'] != null) {
        bannerList = [];
        for (var item in data['banners']) {
          bannerList.add(BannerModel.fromMap(item));
        }
      }

      if (data.containsKey('categories') && data['categories'] != null) {
        List<CategoryModel> catList = [];
        for (var item in data['categories']) {
          catList.add(CategoryModel.fromMap(item));
        }
        if (locator.isRegistered<CategoriesProvider>()) {
          locator<CategoriesProvider>().setCategories(catList);
        } else if (context.mounted) {
          Provider.of<CategoriesProvider>(context, listen: false).setCategories(catList);
        }
      }

      // Featured categories are deliberately supplied separately by Home.
      // Their sequence is controlled by the admin dashboard and must not be
      // re-sorted using the general catalog order above.
      if (data.containsKey('featuredCategories') &&
          data['featuredCategories'] != null) {
        final featuredCategories = <CategoryModel>[];
        for (final item in data['featuredCategories']) {
          featuredCategories.add(CategoryModel.fromMap(item));
        }
        if (featuredCategories.isNotEmpty) {
          if (locator.isRegistered<CategoriesProvider>()) {
            locator<CategoriesProvider>()
                .setFeaturedCategories(featuredCategories);
          } else if (context.mounted) {
            Provider.of<CategoriesProvider>(context, listen: false)
                .setFeaturedCategories(featuredCategories);
          }
        }
      }
      // The curated Home grid, where every tile carries its own destination.
      // Older backends do not send this; the featured category list above then
      // remains the fallback.
      final bool homeCategoriesEnabled = data.containsKey('homeCategoriesEnabled') && data['homeCategoriesEnabled'] != null
          ? data['homeCategoriesEnabled'] as bool
          : true;
      final int homeCategoriesMaxItems = data.containsKey('homeCategoriesMaxItems') && data['homeCategoriesMaxItems'] != null
          ? (data['homeCategoriesMaxItems'] as num).toInt()
          : 8;
      final String? homeCategoriesTitle = data['homeCategoriesTitle'] as String?;

      if (data.containsKey('homeCategories') && data['homeCategories'] != null) {
        final tiles = <HomeCategoryTile>[];
        for (final item in data['homeCategories']) {
          tiles.add(HomeCategoryTile.fromMap(Map<String, dynamic>.from(item)));
        }
        if (locator.isRegistered<CategoriesProvider>()) {
          locator<CategoriesProvider>().setHomeCategoryTiles(
            tiles,
            enabled: homeCategoriesEnabled,
            maxItems: homeCategoriesMaxItems,
            title: homeCategoriesTitle,
            authoritative: true,
          );
        } else if (context.mounted) {
          Provider.of<CategoriesProvider>(context, listen: false).setHomeCategoryTiles(
            tiles,
            enabled: homeCategoriesEnabled,
            maxItems: homeCategoriesMaxItems,
            title: homeCategoriesTitle,
            authoritative: true,
          );
        }
      } else {
        if (locator.isRegistered<CategoriesProvider>()) {
          locator<CategoriesProvider>().setHomeCategoryTiles(
            [],
            enabled: homeCategoriesEnabled,
            maxItems: homeCategoriesMaxItems,
            title: homeCategoriesTitle,
            authoritative: false,
          );
        } else if (context.mounted) {
          Provider.of<CategoriesProvider>(context, listen: false).setHomeCategoryTiles(
            [],
            enabled: homeCategoriesEnabled,
            maxItems: homeCategoriesMaxItems,
            title: homeCategoriesTitle,
            authoritative: false,
          );
        }
      }

      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  /// Banners specifically targeted or allocated for the "لا تفوتها" (Don't Miss) promo section
  List<BannerModel> get dontMissBanners {
    if (bannerList.isEmpty) return [];

    final specific = bannerList.where((b) {
      final url = (b.url ?? '').toLowerCase();
      final desc = (b.description ?? '').toLowerCase();
      final title = (b.title ?? '').toLowerCase();
      return url.contains('dontmiss') ||
          url.contains('dont_miss') ||
          desc.contains('dontmiss') ||
          desc.contains('dont_miss') ||
          title.contains('لا تفوتها') ||
          desc.contains('لا تفوتها') ||
          url.contains('section:dontmiss') ||
          url.contains('section:all') ||
          b.bannerLocation == 1;
    }).toList();

    if (specific.isNotEmpty) return specific;

    // If no banners are explicitly tagged for dontmiss, return active banners that have an image
    return bannerList.where((b) => b.featuredImage != null && b.featuredImage!.isNotEmpty).toList();
  }

  /// Banners targeted for the "العروض اليومية" (Daily Offers) section
  List<BannerModel> get dailyOffersBanners {
    if (bannerList.isEmpty) return [];

    final specific = bannerList.where((b) {
      final url = (b.url ?? '').toLowerCase();
      final desc = (b.description ?? '').toLowerCase();
      // Exclude banners tagged specifically only for dontmiss
      return !url.contains('section:dontmiss_only') && !desc.contains('dontmiss_only');
    }).toList();

    return specific.isNotEmpty ? specific : bannerList;
  }

  /// Banners targeted for the "صفحة المطاعم" (Restaurants Page) promo ads section
  List<BannerModel> get restaurantBanners {
    if (bannerList.isEmpty) return [];

    return bannerList.where((b) {
      final url = (b.url ?? '').toLowerCase();
      final desc = (b.description ?? '').toLowerCase();
      final title = (b.title ?? '').toLowerCase();
      return b.bannerLocation == 2 || // RestaurantsPage
          b.bannerLocation == 4 || // All
          url.contains('section:restaurant') ||
          url.contains('section:food') ||
          desc.contains('restaurants') ||
          desc.contains('مطاعم') ||
          title.contains('مطاعم');
    }).toList();
  }

  /// Banners targeted for the "صفحة الماركت" (Market Page) promo ads section
  List<BannerModel> get marketBanners {
    if (bannerList.isEmpty) return [];

    return bannerList.where((b) {
      final url = (b.url ?? '').toLowerCase();
      final desc = (b.description ?? '').toLowerCase();
      final title = (b.title ?? '').toLowerCase();
      return b.bannerLocation == 3 || // MarketPage
          b.bannerLocation == 4 || // All
          url.contains('section:market') ||
          url.contains('section:grocery') ||
          desc.contains('market') ||
          desc.contains('ماركت') ||
          title.contains('ماركت');
    }).toList();
  }
}

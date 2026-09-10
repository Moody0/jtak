import 'package:flutter/material.dart';
import 'package:jtek_app/src/core/controllers/catalog/categories_provider.dart';
import 'package:jtek_app/src/core/models/banner_model.dart';
import 'package:jtek_app/src/core/models/user/user_model.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';
import 'package:provider/provider.dart';

import '../models/catalog/category_model.dart';

import '../services/locator.dart';
import '../../utils/providers/sol_api.dart';
import 'app/base_provider.dart';

class InitialDataProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  List<BannerModel> bannerList = [];

  Future<void> getInitData(BuildContext context) async {
    try {
      Map data = await _api.getRequest('/Home');

      if (data.containsKey('user')) {
        locator<AuthenticationService>().user = data['user'] != null ? UserModel.fromMap(data['user']) : null;
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
}

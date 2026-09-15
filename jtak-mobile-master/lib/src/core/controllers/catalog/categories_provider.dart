import 'package:flutter/material.dart';
import '../../enums/viewstate.dart';
import '../../services/locator.dart';
import '../app/base_provider.dart';
import '../../models/catalog/category_model.dart';
import 'package:jtek_app/src/core/models/catalog/home_category_tile.dart';
import '../../../utils/providers/sol_api.dart';

class CategoriesProvider extends BaseProvider<CategoryModel> {
  final SolApi _api = locator<SolApi>();
  // The full root-category list remains available for catalog screens. Home
  // uses this independent, ordered list so it can follow the admin-curated
  // featured categories without affecting the rest of the catalog.
  List<CategoryModel> featuredDataList = [];

  static const Map<String, String> defaultCategoryIcons = {
    'المطاعم': '2026_9_10_6d5b7ddac77344cca57899d237306499.jpg',
    'مطاعم': '2026_9_10_6d5b7ddac77344cca57899d237306499.jpg',
    'البقالة': '2026_9_9_b025b708c360481487f839e5f7d5151d.webp',
    'بقالة': '2026_9_9_b025b708c360481487f839e5f7d5151d.webp',
    'حلويات ومخابز': '2026_9_10_edb3d6717f7946e09ffe536866a5d15b.jpg',
    'حلويات': '2026_9_10_edb3d6717f7946e09ffe536866a5d15b.jpg',
    'قهوة ومشروبات': '2026_9_9_7849ac5d25364622bb5f05bdefe1d4e9.webp',
    'مشروبات': '2026_9_9_7849ac5d25364622bb5f05bdefe1d4e9.webp',
    'خضار وفواكه': '2026_9_9_100a77725ce74b7ab7090c4d00e8197c.webp',
    'خضراوات': '2026_9_9_100a77725ce74b7ab7090c4d00e8197c.webp',
    'خضار': '2026_9_9_100a77725ce74b7ab7090c4d00e8197c.webp',
    'فواكه': '2026_9_9_100a77725ce74b7ab7090c4d00e8197c.webp',
    'لحوم ودواجن': '2026_9_9_bcebb1f48db84e23a93aa322f481216b.webp',
    'لحوم': '2026_9_9_bcebb1f48db84e23a93aa322f481216b.webp',
    'دجاج': '2026_9_9_5bc3af42830541a78a50fd283a750bf6.webp',
    'غذائيات': '2026_9_9_b025b708c360481487f839e5f7d5151d.webp',
    'غذائية': '2026_9_9_b025b708c360481487f839e5f7d5151d.webp',
    'مواد غذائية': '2026_9_9_b025b708c360481487f839e5f7d5151d.webp',
    'نقرشات': '2026_9_9_50fff68503034a9e82786275d9c80391.webp',
    'سناك': '2026_9_9_50fff68503034a9e82786275d9c80391.webp',
    'تسالي': '2026_9_9_50fff68503034a9e82786275d9c80391.webp',
    'ألبان وأجبان': '2026_9_9_90ac8b76d5984700bdfe7d2895950517.webp',
    'أجبان وألبان': '2026_9_9_90ac8b76d5984700bdfe7d2895950517.webp',
    'اجبان وألبان': '2026_9_9_90ac8b76d5984700bdfe7d2895950517.webp',
    'ألبان واأجبان': '2026_9_9_90ac8b76d5984700bdfe7d2895950517.webp',
    'مجمدات': '2026_9_9_982936ec02084caba78fed6c591dd4b5.webp',
    'منظفات': '2026_9_9_5fc8b22e492f4f06b54f48cbb0183183.webp',
    'منظفات وعناية': '2026_9_9_5fc8b22e492f4f06b54f48cbb0183183.webp',
    'مونة': '2026_9_9_ec5de055008949088b82e0043bbce3a5.webp',
    'توابل وبقوليات': '2026_9_9_778ced0e7db847f985e986933d4c17d5.webp',
    'بقوليات': '2026_9_9_778ced0e7db847f985e986933d4c17d5.webp',
    'بهارات وتوابل': '2026_9_9_778ced0e7db847f985e986933d4c17d5.webp',
    'عروض': '2026_8_25_5e7c4a2018a94c1c9c466ad28c749919.jpg',
    'الفطور': '2026_8_25_3d69257f39d84c08abf7bb4454f31188.jpg',
    'مخبوزات': '2026_8_25_95de21288dba4c02a1dada850d1cc8d2.jpg',
    'عناية شخصية': '2026_8_25_64abea0f60564a5db7f32d10c477b381.jpg',
    'عناية بالطفل': '2026_8_25_5000bc7e3d7d48df97b716da4c6e1914.jpg',
    'مناديل': '2026_8_25_55598b93677340f791f900f6452713d5.jpg',
    'منزلية': '2026_8_25_becde35640834ff9860b8586e7b37f91.jpg',
    'هدايا': '2026_8_25_fa222b8c20994ccf8468300634fca5c8.jpg',
  };

  String? getIconForCategory(String title) {
    if (title.isEmpty) return null;
    final clean = title.trim();

    // 1. Dynamic lookup from live database categories
    for (final cat in dataList) {
      final icon = cat.icon;
      if (icon != null && icon.isNotEmpty && !icon.startsWith('fas fa-')) {
        final catTitle = (cat.title ?? '').trim();
        if (catTitle.isEmpty) continue;
        if (catTitle == clean || catTitle.contains(clean) || clean.contains(catTitle)) {
          return icon;
        }
      }
    }

    // 2. Direct fallback mapping from system-assigned uploaded images
    for (final entry in defaultCategoryIcons.entries) {
      if (clean == entry.key || clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }

    return null;
  }

  static List<CategoryModel> get defaultCategories => [
    CategoryModel(id: 191, title: 'المطاعم', icon: '2026_9_10_6d5b7ddac77344cca57899d237306499.jpg', order: 1),
    CategoryModel(id: 110, title: 'البقالة', icon: '2026_9_9_b025b708c360481487f839e5f7d5151d.webp', order: 2),
    CategoryModel(id: 122, title: 'حلويات ومخابز', icon: '2026_9_10_edb3d6717f7946e09ffe536866a5d15b.jpg', order: 3),
    CategoryModel(id: 140, title: 'قهوة ومشروبات', icon: '2026_9_9_7849ac5d25364622bb5f05bdefe1d4e9.webp', order: 4),
    CategoryModel(id: 107, title: 'خضار وفواكه', icon: '2026_9_9_100a77725ce74b7ab7090c4d00e8197c.webp', order: 5),
    CategoryModel(id: 167, title: 'لحوم ودواجن', icon: '2026_9_9_bcebb1f48db84e23a93aa322f481216b.webp', order: 6),
  ];

  CategoriesProvider() {
    dataList = List.from(defaultCategories);
  }

  void setCategories(List<CategoryModel> list) {
    if (list.isNotEmpty) {
      dataList = List.from(list);
      dataList.sort((a, b) => _getCategoryPriority(a).compareTo(_getCategoryPriority(b)));
      notifyListeners();
    }
  }

  void setFeaturedCategories(List<CategoryModel> list) {
    featuredDataList = List<CategoryModel>.from(list);
    notifyListeners();
  }

  /// The curated Home grid. Each tile states its own destination, so the grid
  /// never has to work out where a category leads from its title.
  List<HomeCategoryTile> homeCategoryTiles = [];

  void setHomeCategoryTiles(List<HomeCategoryTile> tiles) {
    homeCategoryTiles = tiles.where((tile) => tile.isRoutable).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    notifyListeners();
  }

  int _getCategoryPriority(CategoryModel cat) {
    if (cat.order != null && cat.order! > 0) return cat.order!;
    final t = (cat.title ?? '').trim();
    if (t == 'المطاعم' || t == 'مطاعم') return 1;
    if (t == 'البقالة' || t == 'بقالة' || t == 'غذائيات' || t.contains('سوبرماركت') || t.contains('ماركت')) return 2;
    if (t.contains('حلويات') || t.contains('مخبوزات')) return 3;
    if (t.contains('قهوة') || t.contains('مشروبات')) return 4;
    if (t.contains('خضار') || t.contains('فواكه')) return 5;
    if (t.contains('لحوم') || t.contains('دواجن')) return 6;
    return 99 + (cat.id ?? 0);
  }

  Future loadData() async {
    try {
      setState(ViewState.busy);
      var res = await _api.getRequest('/ProductCategories');
      if (res is List && res.isNotEmpty) {
        List<CategoryModel> items = [];
        for (var element in res) {
          final cat = CategoryModel.fromMap(element);
          final t = (cat.title ?? '').trim();
          if (t.contains('صيدلي') || t == 'المتاجر' || t == 'متاجر') continue;
          items.add(cat);
        }
        setCategories(items);
      }
      setState(ViewState.idle);
    } catch (error) {
      setState(ViewState.idle);
      debugPrint('CategoriesProvider.loadData error: $error');
      if (dataList.isEmpty) {
        dataList = List.from(defaultCategories);
        notifyListeners();
      }
    }
  }
}

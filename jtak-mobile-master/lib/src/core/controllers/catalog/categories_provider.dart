import 'package:flutter/material.dart';
import '../../enums/viewstate.dart';
import '../../services/locator.dart';
import '../app/base_provider.dart';
import '../../models/catalog/category_model.dart';
import 'package:jtek_app/src/core/models/catalog/home_category_tile.dart';
import '../../../utils/providers/sol_api.dart';

class CategoriesProvider extends BaseProvider<CategoryModel> {
  final SolApi _api = locator<SolApi>();

  // The 4 canonical top-level customer categories:
  // 1. البقالة (Grocery & Supermarkets, merging "المتاجر")
  // 2. المطاعم (Restaurants)
  // 3. قهوة ومشروبات (Coffee & Beverages)
  // 4. صيدليات (Pharmacies)
  static List<CategoryModel> get defaultCategories => [
    CategoryModel(
      id: 110,
      title: 'البقالة',
      icon: '2026_9_9_b025b708c360481487f839e5f7d5151d.webp',
      order: 1,
    ),
    CategoryModel(
      id: 191,
      title: 'المطاعم',
      icon: '2026_9_10_6d5b7ddac77344cca57899d237306499.jpg',
      order: 2,
    ),
    CategoryModel(
      id: 140,
      title: 'قهوة ومشروبات',
      icon: '2026_9_9_7849ac5d25364622bb5f05bdefe1d4e9.webp',
      order: 3,
    ),
    CategoryModel(
      id: 149,
      title: 'صيدليات',
      icon: '2026_8_25_64abea0f60564a5db7f32d10c477b381.jpg',
      order: 4,
    ),
  ];

  List<CategoryModel> featuredDataList = [];

  static const Map<String, String> defaultCategoryIcons = {
    'المطاعم': '2026_9_10_6d5b7ddac77344cca57899d237306499.jpg',
    'مطاعم': '2026_9_10_6d5b7ddac77344cca57899d237306499.jpg',
    'البقالة': '2026_9_9_b025b708c360481487f839e5f7d5151d.webp',
    'بقالة': '2026_9_9_b025b708c360481487f839e5f7d5151d.webp',
    'قهوة ومشروبات': '2026_9_9_7849ac5d25364622bb5f05bdefe1d4e9.webp',
    'مشروبات': '2026_9_9_7849ac5d25364622bb5f05bdefe1d4e9.webp',
    'صيدليات': '2026_8_25_64abea0f60564a5db7f32d10c477b381.jpg',
    'صيدلية': '2026_8_25_64abea0f60564a5db7f32d10c477b381.jpg',
    'حلويات ومخابز': '2026_9_10_edb3d6717f7946e09ffe536866a5d15b.jpg',
    'حلويات': '2026_9_10_edb3d6717f7946e09ffe536866a5d15b.jpg',
    'خضار وفواكه': '2026_9_9_100a77725ce74b7ab7090c4d00e8197c.webp',
    'خضراوات': '2026_9_9_100a77725ce74b7ab7090c4d00e8197c.webp',
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
    'مجمدات': '2026_9_9_982936ec02084caba78fed6c591dd4b5.webp',
    'منظفات': '2026_9_9_5fc8b22e492f4f06b54f48cbb0183183.webp',
    'منظفات وعناية': '2026_9_9_5fc8b22e492f4f06b54f48cbb0183183.webp',
    'مونة': '2026_9_9_ec5de055008949088b82e0043bbce3a5.webp',
    'توابل وبقوليات': '2026_9_9_778ced0e7db847f985e986933d4c17d5.webp',
    'بقوليات': '2026_9_9_778ced0e7db847f985e986933d4c17d5.webp',
    'عروض': '2026_8_25_5e7c4a2018a94c1c9c466ad28c749919.jpg',
    'الفطور': '2026_8_25_3d69257f39d84c08abf7bb4454f31188.jpg',
    'مخبوزات': '2026_8_25_95de21288dba4c02a1dada850d1cc8d2.jpg',
    'عناية شخصية': '2026_8_25_64abea0f60564a5db7f32d10c477b381.jpg',
    'عناية بالطفل': '2026_8_25_5000bc7e3d7d48df97b716da4c6e1914.jpg',
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

  CategoriesProvider() {
    dataList = List.from(defaultCategories);
  }

  void setCategories(List<CategoryModel> list) {
    if (list.isNotEmpty) {
      final filtered = <CategoryModel>[];
      for (final cat in list) {
        final t = (cat.title ?? '').trim();
        // Standalone "المتاجر" is merged entirely into "البقالة"
        if (t == 'المتاجر' || t == 'متاجر') continue;
        // Subcategories must not be scattered as top-level homepage cards
        if (cat.parentId != null && cat.parentId! > 0) continue;
        filtered.add(cat);
      }
      dataList = filtered.isNotEmpty ? filtered : List.from(defaultCategories);
      dataList.sort((a, b) => _getCategoryPriority(a).compareTo(_getCategoryPriority(b)));
      notifyListeners();
    }
  }

  void setFeaturedCategories(List<CategoryModel> list) {
    featuredDataList = list.where((cat) {
      final t = (cat.title ?? '').trim();
      return t != 'المتاجر' && t != 'متاجر';
    }).toList();
    notifyListeners();
  }

  /// The curated Home grid.
  bool homeCategoriesEnabled = true;
  int homeCategoriesMaxItems = 8;
  String? homeCategoriesTitle;
  List<HomeCategoryTile> homeCategoryTiles = [];

  void setHomeCategoryTiles(
    List<HomeCategoryTile> tiles, {
    bool enabled = true,
    int maxItems = 8,
    String? title,
  }) {
    homeCategoriesEnabled = enabled;
    homeCategoriesMaxItems = maxItems;
    homeCategoriesTitle = title;

    final validTiles = tiles.where((tile) {
      final t = tile.title.trim();
      return tile.isRoutable && t != 'المتاجر' && t != 'متاجر';
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (maxItems > 0 && validTiles.length > maxItems) {
      homeCategoryTiles = validTiles.take(maxItems).toList();
    } else {
      homeCategoryTiles = validTiles;
    }

    notifyListeners();
  }

  /// Returns EXACTLY the 4 canonical top-level Home service sections in strict order:
  /// 1. البقالة (Grocery & Supermarkets)
  /// 2. المطاعم (Restaurants)
  /// 3. قهوة ومشروبات (Coffee & Beverages)
  /// 4. صيدليات (Pharmacies)
  List<CategoryModel> get homeSections {
    CategoryModel resolveSection(String canonicalTitle, int defaultId, String defaultIcon, int order) {
      CategoryModel? match;
      for (final cat in dataList) {
        final t = (cat.title ?? '').trim();
        if (canonicalTitle == 'البقالة' &&
            (t == 'البقالة' || t == 'بقالة' || t == 'غذائيات' || t.contains('سوبرماركت') || t.contains('ماركت'))) {
          match = cat;
          break;
        } else if (canonicalTitle == 'المطاعم' && (t == 'المطاعم' || t == 'مطاعم')) {
          match = cat;
          break;
        } else if (canonicalTitle == 'قهوة ومشروبات' &&
            (t == 'قهوة ومشروبات' || t.contains('قهوة') || t.contains('مشروبات') || t.contains('كافيه'))) {
          match = cat;
          break;
        } else if (canonicalTitle == 'صيدليات' &&
            (t == 'صيدليات' || t == 'صيدلية' || t.contains('صيدلي') || t.contains('أدوية') || t.contains('دواء'))) {
          match = cat;
          break;
        }
      }

      final resolvedId = match?.id ?? defaultId;
      final resolvedIcon = (match?.icon != null && match!.icon!.isNotEmpty && !match.icon!.startsWith('fas fa-'))
          ? match.icon
          : (getIconForCategory(canonicalTitle) ?? defaultIcon);

      return CategoryModel(
        id: resolvedId,
        title: canonicalTitle,
        icon: resolvedIcon,
        order: order,
      );
    }

    return [
      resolveSection('البقالة', 110, '2026_9_9_b025b708c360481487f839e5f7d5151d.webp', 1),
      resolveSection('المطاعم', 191, '2026_9_10_6d5b7ddac77344cca57899d237306499.jpg', 2),
      resolveSection('قهوة ومشروبات', 140, '2026_9_9_7849ac5d25364622bb5f05bdefe1d4e9.webp', 3),
      resolveSection('صيدليات', 149, '2026_8_25_64abea0f60564a5db7f32d10c477b381.jpg', 4),
    ];
  }

  int _getCategoryPriority(CategoryModel cat) {
    final t = (cat.title ?? '').trim();
    if (t == 'البقالة' || t == 'بقالة' || t == 'غذائيات' || t.contains('سوبرماركت') || t.contains('ماركت')) return 1;
    if (t == 'المطاعم' || t == 'مطاعم') return 2;
    if (t.contains('قهوة') || t.contains('مشروبات') || t.contains('كافيه')) return 3;
    if (t.contains('صيدلي') || t.contains('صيدلية') || t.contains('صيدليات') || t.contains('أدوية') || t.contains('دواء')) return 4;
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
          // Standalone "المتاجر" is merged entirely into "البقالة"
          if (t == 'المتاجر' || t == 'متاجر') continue;
          // Canonical: Subcategories must not be scattered as top-level homepage cards
          if (cat.parentId != null && cat.parentId! > 0) continue;
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

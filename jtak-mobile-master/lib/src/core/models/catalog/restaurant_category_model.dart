class RestaurantCategoryModel {
  final int id;
  final String title;
  final String? titleEn;
  final String image;
  final int order;
  final bool active;
  final String filterTag;

  /// Catalog category this entry stands for. The merchants behind it are the
  /// ones that genuinely sell in it, which is what makes the count meaningful.
  final int? productCategoryId;

  /// How many merchants sell in the category, as reported by the backend.
  final int merchantCount;

  RestaurantCategoryModel({
    required this.id,
    required this.title,
    this.titleEn,
    required this.image,
    required this.order,
    this.active = true,
    required this.filterTag,
    this.productCategoryId,
    this.merchantCount = 0,
  });

  factory RestaurantCategoryModel.fromMap(Map<String, dynamic> map) {
    return RestaurantCategoryModel(
      id: map['id'] is int
          ? map['id']
          : int.tryParse((map['id'] ?? '0').toString()) ?? 0,
      title: (map['title'] ?? '').toString().trim(),
      titleEn: map['titleEn']?.toString().trim(),
      image: (map['image'] ?? '').toString().trim(),
      order: map['order'] is int
          ? map['order']
          : int.tryParse((map['order'] ?? '0').toString()) ?? 0,
      active: map['active'] == true || map['active'] == null,
      filterTag: (map['filterTag'] ?? map['title'] ?? '').toString().trim(),
      productCategoryId: (map['productCategoryId'] as num?)?.toInt(),
      merchantCount: (map['merchantCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'titleEn': titleEn,
      'image': image,
      'order': order,
      'active': active,
      'filterTag': filterTag,
      'productCategoryId': productCategoryId,
      'merchantCount': merchantCount,
    };
  }
}

class RestaurantCategoriesConfigModel {
  final String sectionTitle;
  final String sectionTitleEn;

  /// Heading used where these categories appear as a strip on Home, which
  /// reads differently from the restaurants page listing.
  final String homeSectionTitle;
  final String homeSectionTitleEn;

  final bool enabled;
  final bool showOnHome;
  final List<RestaurantCategoryModel> items;

  RestaurantCategoriesConfigModel({
    this.sectionTitle = 'كل المطاعم',
    this.sectionTitleEn = 'All Restaurants',
    this.homeSectionTitle = 'أصناف متنوعة',
    this.homeSectionTitleEn = 'Browse by kind',
    this.enabled = true,
    this.showOnHome = true,
    required this.items,
  });

  /// Entries worth showing on Home: active, and known to have merchants behind
  /// them. An entry with none can only open an empty list.
  List<RestaurantCategoryModel> get homeItems => items
      .where((item) =>
          item.active &&
          item.title.isNotEmpty &&
          (item.productCategoryId == null || item.merchantCount > 0))
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  factory RestaurantCategoriesConfigModel.fromMap(Map<String, dynamic> map) {
    List rawItems = [];
    if (map['items'] is List) {
      rawItems = map['items'];
    } else if (map['data'] is List) {
      rawItems = map['data'];
    }

    final items = <RestaurantCategoryModel>[];
    for (final item in rawItems) {
      if (item is Map<String, dynamic>) {
        items.add(RestaurantCategoryModel.fromMap(item));
      } else if (item is Map) {
        items.add(
            RestaurantCategoryModel.fromMap(Map<String, dynamic>.from(item)));
      }
    }

    return RestaurantCategoriesConfigModel(
      sectionTitle: (map['sectionTitle'] ?? 'كل المطاعم').toString().trim(),
      sectionTitleEn:
          (map['sectionTitleEn'] ?? 'All Restaurants').toString().trim(),
      homeSectionTitle:
          (map['homeSectionTitle'] ?? 'أصناف متنوعة').toString().trim(),
      homeSectionTitleEn:
          (map['homeSectionTitleEn'] ?? 'Browse by kind').toString().trim(),
      enabled: map['enabled'] != false,
      showOnHome: map['showOnHome'] != false,
      items: items,
    );
  }
}

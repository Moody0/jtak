/// Where a home tile takes the customer. The destination arrives from the
/// backend as data, so adding, renaming or translating a category never
/// requires the app to recognise the words in its title.
enum HomeCategoryLinkType {
  productCategory,
  merchantKind,
  merchant,
  search,
  unknown,
}

HomeCategoryLinkType _linkTypeFrom(dynamic raw) {
  switch (raw is int ? raw : int.tryParse('$raw')) {
    case 0:
      return HomeCategoryLinkType.productCategory;
    case 1:
      return HomeCategoryLinkType.merchantKind;
    case 2:
      return HomeCategoryLinkType.merchant;
    case 3:
      return HomeCategoryLinkType.search;
    default:
      // A tile added by a newer backend must be ignored rather than routed
      // somewhere arbitrary.
      return HomeCategoryLinkType.unknown;
  }
}

/// One tile of the Home "shop by category" grid, authored in the dashboard.
class HomeCategoryTile {
  final String id;
  final String title;
  final String? titleEn;
  final String? imageUrl;
  final int order;
  final HomeCategoryLinkType linkType;
  final int? productCategoryId;
  final int? merchantKind;
  final int? merchantId;
  final String? searchTerm;

  const HomeCategoryTile({
    required this.id,
    required this.title,
    required this.linkType,
    this.titleEn,
    this.imageUrl,
    this.order = 0,
    this.productCategoryId,
    this.merchantKind,
    this.merchantId,
    this.searchTerm,
  });

  factory HomeCategoryTile.fromMap(Map<String, dynamic> map) {
    return HomeCategoryTile(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? ''}',
      titleEn: map['titleEn'] as String?,
      imageUrl: map['imageUrl'] as String?,
      order: (map['order'] as num?)?.toInt() ?? 0,
      linkType: _linkTypeFrom(map['linkType']),
      productCategoryId: (map['productCategoryId'] as num?)?.toInt(),
      merchantKind: (map['merchantKind'] as num?)?.toInt(),
      merchantId: (map['merchantId'] as num?)?.toInt(),
      searchTerm: map['searchTerm'] as String?,
    );
  }

  /// True when the tile carries everything its destination needs. A tile that
  /// fails this is skipped, because rendering it would produce a square that
  /// does nothing useful when tapped.
  bool get isRoutable {
    if (title.trim().isEmpty) return false;
    switch (linkType) {
      case HomeCategoryLinkType.productCategory:
        return productCategoryId != null;
      case HomeCategoryLinkType.merchantKind:
        return merchantKind != null;
      case HomeCategoryLinkType.merchant:
        return merchantId != null;
      case HomeCategoryLinkType.search:
        return (searchTerm ?? '').trim().isNotEmpty;
      case HomeCategoryLinkType.unknown:
        return false;
    }
  }
}

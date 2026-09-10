enum CatalogScopeKind { grocery, pharmacy, stores }

/// Describes a top-level, product-based marketplace opened from the home page.
/// The backend category id is deliberately carried through every screen so
/// merchant discovery and product search use the same source of truth.
class CatalogScope {
  final int categoryId;
  final String title;
  final CatalogScopeKind kind;

  const CatalogScope({
    required this.categoryId,
    required this.title,
    required this.kind,
  });

  static CatalogScope? fromCategory(int? id, String title) {
    if (id == null) return null;
    final normalized = title.trim().toLowerCase();

    if (normalized == 'البقالة' ||
        normalized == 'بقالة' ||
        normalized == 'غذائيات' ||
        normalized.contains('grocery')) {
      return CatalogScope(
        categoryId: id,
        title: title,
        kind: CatalogScopeKind.grocery,
      );
    }

    if (normalized.contains('صيدلي') || normalized.contains('pharmacy')) {
      return CatalogScope(
        categoryId: id,
        title: title,
        kind: CatalogScopeKind.pharmacy,
      );
    }

    if (normalized == 'المتاجر' ||
        normalized == 'متاجر' ||
        normalized.contains('store')) {
      return CatalogScope(
        categoryId: id,
        title: title,
        kind: CatalogScopeKind.stores,
      );
    }

    return null;
  }

  String get searchHint {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 'ابحث عن بقالة أو منتج';
      case CatalogScopeKind.pharmacy:
        return 'ابحث عن صيدلية أو دواء';
      case CatalogScopeKind.stores:
        return 'ابحث عن متجر أو منتج';
    }
  }

  String get allSectionTitle {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 'كل البقالات';
      case CatalogScopeKind.pharmacy:
        return 'كل الصيدليات';
      case CatalogScopeKind.stores:
        return 'كل المتاجر';
    }
  }

  String get categorySelectorTitle {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 'الأقسام';
      case CatalogScopeKind.pharmacy:
        return 'أقسام الصيدلية';
      case CatalogScopeKind.stores:
        return 'الأقسام';
    }
  }

  String get emptyMerchantsMessage {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 'لا توجد بقالات مطابقة للفلاتر';
      case CatalogScopeKind.pharmacy:
        return 'لا توجد صيدليات مطابقة للفلاتر';
      case CatalogScopeKind.stores:
        return 'لا توجد متاجر مطابقة للفلاتر';
    }
  }

  String get fallbackImage {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 'assets/images/categories/cat_grocery.webp';
      case CatalogScopeKind.pharmacy:
        return 'assets/images/categories/cat_pharmacy.jpg';
      case CatalogScopeKind.stores:
        return 'assets/images/categories/cat_stores.jpg';
    }
  }

  int get merchantKind {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 1;
      case CatalogScopeKind.pharmacy:
        return 2;
      case CatalogScopeKind.stores:
        return 3;
    }
  }
}

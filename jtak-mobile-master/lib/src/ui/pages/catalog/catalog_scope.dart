enum CatalogScopeKind {
  grocery,
  restaurants,
  coffee,
  pharmacy,
}

/// Describes a top-level, canonical customer section opened from the home page.
/// The 4 authoritative top-level customer categories are:
/// 1. البقالة (Grocery & Supermarkets, merging "المتاجر")
/// 2. المطاعم (Restaurants)
/// 3. قهوة ومشروبات (Coffee & Beverages)
/// 4. صيدليات (Pharmacies)
class CatalogScope {
  final int categoryId;
  final String title;
  final CatalogScopeKind kind;

  const CatalogScope({
    required this.categoryId,
    required this.title,
    required this.kind,
  });

  factory CatalogScope.forGrocery({
    int categoryId = 110,
    String title = 'البقالة',
  }) =>
      CatalogScope(
        categoryId: categoryId,
        title: title,
        kind: CatalogScopeKind.grocery,
      );

  factory CatalogScope.forRestaurants({
    int categoryId = 191,
    String title = 'المطاعم',
  }) =>
      CatalogScope(
        categoryId: categoryId,
        title: title,
        kind: CatalogScopeKind.restaurants,
      );

  factory CatalogScope.forCoffee({
    int categoryId = 140,
    String title = 'قهوة ومشروبات',
  }) =>
      CatalogScope(
        categoryId: categoryId,
        title: title,
        kind: CatalogScopeKind.coffee,
      );

  factory CatalogScope.forPharmacy({
    int categoryId = 149,
    String title = 'صيدليات',
  }) =>
      CatalogScope(
        categoryId: categoryId,
        title: title,
        kind: CatalogScopeKind.pharmacy,
      );

  static CatalogScope? fromCategory(int? id, String title) {
    final normalized = title.trim().toLowerCase();
    final normNoAl = normalized.replaceFirst(RegExp(r'^ال'), '');

    // 1. Grocery & Supermarkets (Merging "المتاجر" and "stores")
    if (normNoAl == 'بقالة' ||
        normNoAl == 'غذائيات' ||
        normNoAl == 'متاجر' ||
        normNoAl == 'متجر' ||
        normalized.contains('سوبرماركت') ||
        normalized.contains('ماركت') ||
        normalized.contains('grocery') ||
        normalized.contains('store')) {
      return CatalogScope.forGrocery(
        categoryId: id ?? 110,
        title: 'البقالة',
      );
    }

    // 2. Restaurants
    if (normNoAl == 'مطاعم' ||
        normNoAl == 'مطعم' ||
        normNoAl == 'طعام' ||
        normalized.contains('restaurant') ||
        normalized.contains('food')) {
      return CatalogScope.forRestaurants(
        categoryId: id ?? 191,
        title: 'المطاعم',
      );
    }

    // 3. Coffee & Beverages
    if (normalized.contains('قهوة') ||
        normalized.contains('مشروبات') ||
        normalized.contains('كافيه') ||
        normalized.contains('مشروب') ||
        normalized.contains('عصائر') ||
        normalized.contains('coffee') ||
        normalized.contains('cafe') ||
        normalized.contains('beverage') ||
        normalized.contains('drink')) {
      return CatalogScope.forCoffee(
        categoryId: id ?? 140,
        title: 'قهوة ومشروبات',
      );
    }

    // 4. Pharmacies
    if (normalized.contains('صيدل') ||
        normalized.contains('دواء') ||
        normalized.contains('أدوية') ||
        normalized.contains('ادوية') ||
        normalized.contains('صحة') ||
        normalized.contains('pharmacy') ||
        normalized.contains('medicine')) {
      return CatalogScope.forPharmacy(
        categoryId: id ?? 149,
        title: 'صيدليات',
      );
    }

    return null;
  }

  String get searchHint {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 'ابحث عن بقالة أو منتج';
      case CatalogScopeKind.restaurants:
        return 'ابحث عن المطاعم والأطباق';
      case CatalogScopeKind.coffee:
        return 'ابحث عن مقهى أو مشروب';
      case CatalogScopeKind.pharmacy:
        return 'ابحث عن صيدلية أو منتج صحي';
    }
  }

  String get allSectionTitle {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 'كل البقالات';
      case CatalogScopeKind.restaurants:
        return 'كل المطاعم';
      case CatalogScopeKind.coffee:
        return 'كل المقاهي والمشروبات';
      case CatalogScopeKind.pharmacy:
        return 'كل الصيدليات';
    }
  }

  String get categorySelectorTitle {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 'الأقسام';
      case CatalogScopeKind.restaurants:
        return 'المطابخ';
      case CatalogScopeKind.coffee:
        return 'المشروبات';
      case CatalogScopeKind.pharmacy:
        return 'الأقسام';
    }
  }

  String get emptyMerchantsMessage {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 'لا توجد بقالات مطابقة للفلاتر';
      case CatalogScopeKind.restaurants:
        return 'لا توجد مطاعم مطابقة للبحث أو الفلتر';
      case CatalogScopeKind.coffee:
        return 'لا توجد مقاهي مطابقة للفلاتر';
      case CatalogScopeKind.pharmacy:
        return 'لا توجد صيدليات مطابقة للفلاتر';
    }
  }

  String get fallbackImage {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 'assets/images/categories/cat_grocery.webp';
      case CatalogScopeKind.restaurants:
        return 'assets/images/categories/cat_restaurants.jpg';
      case CatalogScopeKind.coffee:
        return 'assets/images/categories/cat_drinks.webp';
      case CatalogScopeKind.pharmacy:
        return 'assets/images/categories/cat_grocery.webp';
    }
  }

  int get merchantKind {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return 1;
      case CatalogScopeKind.restaurants:
        return 0;
      case CatalogScopeKind.coffee:
        return 2;
      case CatalogScopeKind.pharmacy:
        return 3;
    }
  }

  List<String> get defaultChildCategories {
    switch (kind) {
      case CatalogScopeKind.grocery:
        return const [
          'خضار وفواكه',
          'لحوم ودواجن',
          'ألبان وأجبان',
          'غذائيات',
          'حلويات ومخابز',
          'مجمدات ومفرزات',
          'المنظفات',
          'نقرشات وتسالي',
        ];
      case CatalogScopeKind.restaurants:
        return const [
          'شاورما',
          'مشاوي',
          'فطور شعبي',
          'حلويات',
          'البرجر',
          'بيتزا',
          'مشروبات',
          'مخبوزات',
          'وجبات سريعة',
        ];
      case CatalogScopeKind.coffee:
        return const [
          'قهوة مختصة',
          'مشروبات باردة',
          'مشروبات ساخنة',
          'عصائر',
          'شاي وأعشاب',
          'حلويات الكافيه',
        ];
      case CatalogScopeKind.pharmacy:
        return const [
          'أدوية ومسكنات',
          'عناية شخصية',
          'فيتامينات ومكملات',
          'عناية بالطفل',
          'إسعافات أولية',
        ];
    }
  }
}

/// Represents a single canonical category bucket with all its database aliases.
class CanonicalCategoryBucket {
  final int canonicalId;
  final String canonicalName;
  final Set<int> aliasCategoryIds;
  final List<String> aliasNames;
  final String fallbackImage;

  const CanonicalCategoryBucket({
    required this.canonicalId,
    required this.canonicalName,
    required this.aliasCategoryIds,
    required this.aliasNames,
    required this.fallbackImage,
  });

  bool matches(int? id, String? name) {
    if (id != null && aliasCategoryIds.contains(id)) return true;
    if (name == null || name.trim().isEmpty) return false;
    final normalized = CanonicalCategoryRegistry.normalizeArabic(name);
    for (final alias in aliasNames) {
      final normAlias = CanonicalCategoryRegistry.normalizeArabic(alias);
      if (normalized == normAlias) return true;
      if (normalized.contains(normAlias) || normAlias.contains(normalized)) {
        if (normAlias.length >= 4 &&
            (normalized.startsWith(normAlias) ||
                normalized.endsWith(normAlias) ||
                normalized == normAlias)) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Authoritative registry mapping known duplicate database categories to clean canonical buckets.
/// Implements a tiered deduplication strategy:
/// 1. Primary Canonical Category ID & Bucket Alias IDs
/// 2. Explicit Alias Name Matching
/// 3. Normalized Arabic String Matching
/// 4. Safe Non-Ambiguous Substring Fallback
class CanonicalCategoryRegistry {
  static final List<CanonicalCategoryBucket> buckets = [
    // 1. Produce / الخضار والفواكه
    CanonicalCategoryBucket(
      canonicalId: 107,
      canonicalName: 'خضار وفواكه',
      aliasCategoryIds: {107},
      aliasNames: const [
        'خضار وفواكه',
        'خضار',
        'فواكه',
        'خضراوات',
        'فاكهة',
        'خضار وفاكهة',
      ],
      fallbackImage: 'assets/images/categories/cat_vegetables.webp',
    ),

    // 2. Meat & Poultry / اللحوم والدواجن
    CanonicalCategoryBucket(
      canonicalId: 167,
      canonicalName: 'لحوم ودواجن',
      aliasCategoryIds: {167, 227, 228, 229, 298, 299, 300, 324, 326},
      aliasNames: const [
        'لحوم ودواجن',
        'لحوم',
        'دواجن',
        'دجاج',
        'لحم',
        'طازج',
        'متبل',
        'سمك',
        'لحوم وطازج',
        'دواجن طازجة',
      ],
      fallbackImage: 'assets/images/categories/cat_meat.webp',
    ),

    // 3. Dairy & Cheese / ألبان وأجبان
    CanonicalCategoryBucket(
      canonicalId: 204,
      canonicalName: 'ألبان وأجبان',
      aliasCategoryIds: {
        199,
        204,
        205,
        206,
        207,
        208,
        209,
        210,
        211,
        237,
        247,
        256,
        301,
        323,
      },
      aliasNames: const [
        'ألبان وأجبان',
        'أجبان وألبان',
        'اجبان والبان',
        'أجبان',
        'ألبان',
        'حليب',
        'لبنة',
        'جبنة',
        'قشطة',
        'لبن',
        'أجبان والبان',
        'الالبان والاجبان',
      ],
      fallbackImage: 'assets/images/categories/cat_grocery.webp',
    ),

    // 4. Foodstuffs & Pantry / غذائيات
    CanonicalCategoryBucket(
      canonicalId: 246,
      canonicalName: 'غذائيات',
      aliasCategoryIds: {
        220,
        221,
        222,
        233,
        234,
        236,
        241,
        246,
        249,
        251,
        252,
        269,
        293,
        294,
        296,
        297,
        313,
      },
      aliasNames: const [
        'غذائيات',
        'غذايات',
        'عذائيات',
        'مواد غذائية',
        'مونة',
        'توابل وبقوليات',
        'بقوليات',
        'بهارات',
        'باستا',
        'سمن وزيت',
        'نودلز',
        'أغذية',
        'اغذية',
        'توابل',
        'زيوت',
        'معلبات',
      ],
      fallbackImage: 'assets/images/categories/cat_grocery.webp',
    ),

    // 5. Sweets & Bakery / حلويات ومخابز
    CanonicalCategoryBucket(
      canonicalId: 122,
      canonicalName: 'حلويات ومخابز',
      aliasCategoryIds: {122},
      aliasNames: const [
        'حلويات ومخابز',
        'حلويات',
        'مخابز',
        'معجنات',
        'كيك',
        'خبز',
        'حلويات غربية',
        'حلويات شرقية',
        'كيك وحلويات',
      ],
      fallbackImage: 'assets/images/categories/cat_sweets.jpg',
    ),

    // 6. Frozen / مجمدات ومفرزات
    CanonicalCategoryBucket(
      canonicalId: 322,
      canonicalName: 'مجمدات ومفرزات',
      aliasCategoryIds: {291, 322, 327},
      aliasNames: const [
        'مجمدات',
        'مفرزات',
        'مجمدات ومفرزات',
        'مثلجات',
        'مفرز ومجمد',
      ],
      fallbackImage: 'assets/images/categories/cat_grocery.webp',
    ),

    // 7. Cleaning & Household / المنظفات
    CanonicalCategoryBucket(
      canonicalId: 214,
      canonicalName: 'المنظفات',
      aliasCategoryIds: {
        214,
        215,
        314,
        315,
        316,
        318,
        319,
        320,
        321,
        328,
        329,
        331,
        332,
        337,
        338,
        339,
        340,
        341,
        342,
        343,
        344,
        345,
        346,
        347,
        348,
        349,
        363,
      },
      aliasNames: const [
        'المنظفات',
        'منظفات',
        'مظفات',
        'أدوات تنظيف',
        'أدوات منزلية',
        'صابون',
        'جلي',
        'غسيل',
        'فلاش وكلور',
        'كلور وفلاش',
        'معطر',
        'معقم',
        'ملمعات',
        'شامبو',
        'محارم',
      ],
      fallbackImage: 'assets/images/categories/cat_grocery.webp',
    ),

    // 8. Snacks & Treats / نقرشات وتسالي
    CanonicalCategoryBucket(
      canonicalId: 364,
      canonicalName: 'نقرشات وتسالي',
      aliasCategoryIds: {
        218,
        219,
        223,
        231,
        235,
        250,
        255,
        351,
        354,
        356,
        357,
        359,
        364,
        365,
        366,
        367,
        368,
        369,
        370,
        371,
        372,
        373,
        375,
      },
      aliasNames: const [
        'نقرشات',
        'تقرشات',
        'تسالي',
        'سناك',
        'بسكويت',
        'بسكوت',
        'شوكولا',
        'شوكولاتة',
        'تشيبس',
        'حلوى',
        'ايس كريم',
        'مكسرات',
        'شيبس',
        'نقرشات وتسالي',
      ],
      fallbackImage: 'assets/images/categories/cat_grocery.webp',
    ),

    // 9. Coffee & Beverages / قهوة ومشروبات
    CanonicalCategoryBucket(
      canonicalId: 140,
      canonicalName: 'قهوة ومشروبات',
      aliasCategoryIds: {
        140,
        239,
        240,
        271,
        274,
        281,
        283,
        304,
        311,
        312,
        374,
      },
      aliasNames: const [
        'قهوة ومشروبات',
        'مشروبات',
        'عصائر',
        'عصير',
        'مياه',
        'شاي',
        'قهوة',
        'مشروبات باردة',
        'مشروبات ساخنة',
        'قهوة مختصة',
        'شاي وأعشاب',
      ],
      fallbackImage: 'assets/images/categories/cat_drinks.webp',
    ),

    // 10. Pharmacy & Wellness / صيدليات
    CanonicalCategoryBucket(
      canonicalId: 149,
      canonicalName: 'صيدليات',
      aliasCategoryIds: {
        149,
        212,
        213,
        242,
        244,
        317,
        330,
        334,
        335,
        336,
      },
      aliasNames: const [
        'صيدليات',
        'صيدلية',
        'أدوية ومسكنات',
        'عناية شخصية',
        'فيتامينات ومكملات',
        'عناية بالأسنان',
        'عناية نسائية',
        'عناية بالطفل',
        'إسعافات أولية',
        'مستحضرات طبية',
      ],
      fallbackImage: 'assets/images/categories/cat_grocery.webp',
    ),
  ];

  static String normalizeArabic(String text) {
    var s = text.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    s = s.replaceAll(RegExp(r'[أإآ]'), 'ا');
    s = s.replaceAll('ة', 'ه');
    s = s.replaceAll('ى', 'ي');
    if (s.startsWith('ال') && s.length > 3) {
      s = s.substring(2);
    }
    return s.trim();
  }

  static CanonicalCategoryBucket? findBucket(int? id, String? name) {
    for (final bucket in buckets) {
      if (bucket.matches(id, name)) {
        return bucket;
      }
    }
    return null;
  }

  static String canonicalizeName(int? id, String rawName) {
    final bucket = findBucket(id, rawName);
    if (bucket != null) {
      return bucket.canonicalName;
    }
    return rawName.trim();
  }

  static bool areSameCategory({
    int? id1,
    String? name1,
    int? id2,
    String? name2,
  }) {
    if (id1 != null && id2 != null && id1 > 0 && id1 == id2) {
      return true;
    }

    final bucket1 = findBucket(id1, name1);
    final bucket2 = findBucket(id2, name2);

    if (bucket1 != null && bucket2 != null) {
      return bucket1.canonicalId == bucket2.canonicalId;
    }

    if (bucket1 != null && (id2 != null || name2 != null)) {
      return bucket1.matches(id2, name2);
    }

    if (bucket2 != null && (id1 != null || name1 != null)) {
      return bucket2.matches(id1, name1);
    }

    final n1 = normalizeArabic(name1 ?? '');
    final n2 = normalizeArabic(name2 ?? '');

    if (n1.isEmpty || n2.isEmpty) return false;
    return n1 == n2 || n1.contains(n2) || n2.contains(n1);
  }
}

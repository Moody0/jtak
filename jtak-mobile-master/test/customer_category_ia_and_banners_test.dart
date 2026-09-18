import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jtek_app/src/core/controllers/catalog/categories_provider.dart';
import 'package:jtek_app/src/core/models/catalog/category_model.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/utils/providers/sol_api.dart';
import 'package:jtek_app/src/ui/pages/catalog/catalog_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    if (!locator.isRegistered<SolApi>()) {
      locator.registerLazySingleton<SolApi>(() => SolApi());
    }
  });

  group('Canonical 4-Section Customer Category Architecture (#49)', () {
    test('Authoritative 4 top-level categories are defined in exact order', () {
      final defaultCats = CategoriesProvider.defaultCategories;

      expect(defaultCats.length, equals(4));

      // 1. البقالة (Grocery & Supermarkets, merging "المتاجر")
      expect(defaultCats[0].id, equals(110));
      expect(defaultCats[0].title, equals('البقالة'));
      expect(defaultCats[0].order, equals(1));

      // 2. المطاعم (Restaurants)
      expect(defaultCats[1].id, equals(191));
      expect(defaultCats[1].title, equals('المطاعم'));
      expect(defaultCats[1].order, equals(2));

      // 3. قهوة ومشروبات (Coffee & Beverages)
      expect(defaultCats[2].id, equals(140));
      expect(defaultCats[2].title, equals('قهوة ومشروبات'));
      expect(defaultCats[2].order, equals(3));

      // 4. صيدليات (Pharmacies)
      expect(defaultCats[3].id, equals(149));
      expect(defaultCats[3].title, equals('صيدليات'));
      expect(defaultCats[3].order, equals(4));
    });

    test('CatalogScope.fromCategory merges "المتاجر" and "stores" into Grocery scope', () {
      final scopeStores = CatalogScope.fromCategory(192, 'المتاجر');
      expect(scopeStores, isNotNull);
      expect(scopeStores!.kind, equals(CatalogScopeKind.grocery));
      expect(scopeStores.title, equals('البقالة'));

      final scopeStoresPlain = CatalogScope.fromCategory(null, 'متاجر');
      expect(scopeStoresPlain, isNotNull);
      expect(scopeStoresPlain!.kind, equals(CatalogScopeKind.grocery));

      final scopeGrocery = CatalogScope.fromCategory(110, 'البقالة');
      expect(scopeGrocery, isNotNull);
      expect(scopeGrocery!.kind, equals(CatalogScopeKind.grocery));
    });

    test('CatalogScope.fromCategory resolves Restaurants, Coffee, and Pharmacies', () {
      final scopeRest = CatalogScope.fromCategory(191, 'المطاعم');
      expect(scopeRest, isNotNull);
      expect(scopeRest!.kind, equals(CatalogScopeKind.restaurants));
      expect(scopeRest.title, equals('المطاعم'));

      final scopeCoffee = CatalogScope.fromCategory(140, 'قهوة ومشروبات');
      expect(scopeCoffee, isNotNull);
      expect(scopeCoffee!.kind, equals(CatalogScopeKind.coffee));
      expect(scopeCoffee.title, equals('قهوة ومشروبات'));

      final scopePharm = CatalogScope.fromCategory(149, 'صيدليات');
      expect(scopePharm, isNotNull);
      expect(scopePharm!.kind, equals(CatalogScopeKind.pharmacy));
      expect(scopePharm.title, equals('صيدليات'));
    });

    test('CatalogScope provides scoped search hints and section titles', () {
      final grocery = CatalogScope.forGrocery();
      expect(grocery.searchHint, equals('ابحث عن بقالة أو منتج'));
      expect(grocery.allSectionTitle, equals('كل البقالات'));
      expect(grocery.categorySelectorTitle, equals('الأقسام'));
      expect(grocery.merchantKind, equals(1));

      final restaurants = CatalogScope.forRestaurants();
      expect(restaurants.searchHint, equals('ابحث عن المطاعم والأطباق'));
      expect(restaurants.allSectionTitle, equals('كل المطاعم'));
      expect(restaurants.categorySelectorTitle, equals('المطابخ'));
      expect(restaurants.merchantKind, equals(0));

      final coffee = CatalogScope.forCoffee();
      expect(coffee.searchHint, equals('ابحث عن مقهى أو مشروب'));
      expect(coffee.allSectionTitle, equals('كل المقاهي والمشروبات'));
      expect(coffee.categorySelectorTitle, equals('المشروبات'));
      expect(coffee.merchantKind, equals(0));

      final pharmacy = CatalogScope.forPharmacy();
      expect(pharmacy.searchHint, equals('ابحث عن صيدلية أو منتج صحي'));
      expect(pharmacy.allSectionTitle, equals('كل الصيدليات'));
      expect(pharmacy.categorySelectorTitle, equals('الأقسام'));
      expect(pharmacy.merchantKind, equals(2));
    });

    test('CatalogScope provides scoped child category defaults with strict separation', () {
      final grocery = CatalogScope.forGrocery();
      expect(grocery.defaultChildCategories.contains('خضار وفواكه'), isTrue);
      expect(grocery.defaultChildCategories.contains('لحوم ودواجن'), isTrue);
      expect(grocery.defaultChildCategories.contains('ألبان وأجبان'), isTrue);
      // Grocery must NOT contain restaurant cuisines
      expect(grocery.defaultChildCategories.contains('شاورما'), isFalse);
      expect(grocery.defaultChildCategories.contains('برغر'), isFalse);

      final restaurants = CatalogScope.forRestaurants();
      expect(restaurants.defaultChildCategories.contains('شاورما'), isTrue);
      expect(restaurants.defaultChildCategories.contains('مشاوي'), isTrue);
      expect(restaurants.defaultChildCategories.contains('البرجر'), isTrue);
      // Restaurants must NOT contain grocery departments
      expect(restaurants.defaultChildCategories.contains('خضار وفواكه'), isFalse);
      expect(restaurants.defaultChildCategories.contains('المنظفات'), isFalse);

      final coffee = CatalogScope.forCoffee();
      expect(coffee.defaultChildCategories.contains('قهوة مختصة'), isTrue);
      expect(coffee.defaultChildCategories.contains('مشروبات باردة'), isTrue);

      final pharmacy = CatalogScope.forPharmacy();
      expect(pharmacy.defaultChildCategories.contains('أدوية ومسكنات'), isTrue);
      expect(pharmacy.defaultChildCategories.contains('عناية شخصية'), isTrue);
    });

    test('CategoriesProvider filters out standalone "المتاجر" from root categories list', () {
      final provider = CategoriesProvider();

      provider.setCategories([
        CategoryModel(id: 110, title: 'البقالة', order: 1),
        CategoryModel(id: 191, title: 'المطاعم', order: 2),
        CategoryModel(id: 192, title: 'المتاجر', order: 5), // Standalone stores should be stripped
        CategoryModel(id: 140, title: 'قهوة ومشروبات', order: 3),
        CategoryModel(id: 149, title: 'صيدليات', order: 4),
        CategoryModel(id: 107, title: 'خضار وفواكه', parentId: 110), // Subcategory should be stripped from top level
      ]);

      expect(provider.dataList.any((c) => c.title == 'المتاجر'), isFalse);
      expect(provider.dataList.any((c) => c.title == 'خضار وفواكه'), isFalse);
      expect(provider.dataList.length, equals(4));
      expect(provider.dataList[0].title, equals('البقالة'));
      expect(provider.dataList[1].title, equals('المطاعم'));
      expect(provider.dataList[2].title, equals('قهوة ومشروبات'));
      expect(provider.dataList[3].title, equals('صيدليات'));
    });

    test('homeSections ALWAYS returns exactly [البقالة, المطاعم, قهوة ومشروبات, صيدليات] in order even with arbitrary subcategories', () {
      final provider = CategoriesProvider();

      // Simulate backend sending grocery subcategories at root level
      provider.setCategories([
        CategoryModel(id: 107, title: 'خضار وفواكه', icon: 'veg.png', order: 1),
        CategoryModel(id: 110, title: 'البقالة', icon: 'grocery.png', order: 2),
        CategoryModel(id: 108, title: 'حلويات ومخابز', icon: 'bakery.png', order: 3),
        CategoryModel(id: 140, title: 'قهوة ومشروبات', icon: 'coffee.png', order: 4),
        CategoryModel(id: 191, title: 'المطاعم', icon: 'rest.png', order: 5),
        CategoryModel(id: 149, title: 'صيدليات', icon: 'pharm.png', order: 6),
      ]);

      final sections = provider.homeSections;
      expect(sections.length, equals(4));
      expect(sections[0].title, equals('البقالة'));
      expect(sections[0].order, equals(1));
      expect(sections[0].id, equals(110));

      expect(sections[1].title, equals('المطاعم'));
      expect(sections[1].order, equals(2));
      expect(sections[1].id, equals(191));

      expect(sections[2].title, equals('قهوة ومشروبات'));
      expect(sections[2].order, equals(3));
      expect(sections[2].id, equals(140));

      expect(sections[3].title, equals('صيدليات'));
      expect(sections[3].order, equals(4));
      expect(sections[3].id, equals(149));
    });
  });

  group('Canonical Category Deduplication Registry (ID-First + Stable Mapping)', () {
    test('Resolves known foodstuffs duplicate IDs and aliases to canonical "غذائيات"', () {
      // Direct canonical ID
      expect(CanonicalCategoryRegistry.canonicalizeName(246, 'غذائيات'), equals('غذائيات'));
      // Alias IDs
      expect(CanonicalCategoryRegistry.canonicalizeName(294, 'غذائيات'), equals('غذائيات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(233, 'غذايات'), equals('غذائيات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(220, 'عذائيات'), equals('غذائيات'));
      // Alias text without ID
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'غذايات'), equals('غذائيات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'عذائيات'), equals('غذائيات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'مواد غذائية'), equals('غذائيات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'مونة'), equals('غذائيات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'توابل وبقوليات'), equals('غذائيات'));
    });

    test('Resolves dairy variations and aliases to canonical "ألبان وأجبان"', () {
      expect(CanonicalCategoryRegistry.canonicalizeName(204, 'ألبان وأجبان'), equals('ألبان وأجبان'));
      expect(CanonicalCategoryRegistry.canonicalizeName(199, 'أجبان وألبان'), equals('ألبان وأجبان'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'اجبان والبان'), equals('ألبان وأجبان'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'أجبان'), equals('ألبان وأجبان'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'ألبان'), equals('ألبان وأجبان'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'جبنة'), equals('ألبان وأجبان'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'لبنة'), equals('ألبان وأجبان'));
    });

    test('Resolves cleaning and typo aliases to canonical "المنظفات"', () {
      expect(CanonicalCategoryRegistry.canonicalizeName(214, 'المنظفات'), equals('المنظفات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(215, 'منظفات'), equals('المنظفات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'مظفات'), equals('المنظفات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'أدوات تنظيف'), equals('المنظفات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'صابون'), equals('المنظفات'));
    });

    test('Resolves frozen variations to canonical "مجمدات ومفرزات"', () {
      expect(CanonicalCategoryRegistry.canonicalizeName(322, 'مجمدات'), equals('مجمدات ومفرزات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(291, 'مفرزات'), equals('مجمدات ومفرزات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'مفرزات'), equals('مجمدات ومفرزات'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'مجمدات'), equals('مجمدات ومفرزات'));
    });

    test('Resolves snacks and typo variations to canonical "نقرشات وتسالي"', () {
      expect(CanonicalCategoryRegistry.canonicalizeName(364, 'نقرشات'), equals('نقرشات وتسالي'));
      expect(CanonicalCategoryRegistry.canonicalizeName(351, 'تقرشات'), equals('نقرشات وتسالي'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'تسالي'), equals('نقرشات وتسالي'));
      expect(CanonicalCategoryRegistry.canonicalizeName(null, 'سناك'), equals('نقرشات وتسالي'));
    });

    test('Strict non-collision between distinct categories with similar letters', () {
      // 'مجمدات / مفرزات' must NOT match 'منظفات / مظفات'
      expect(
        CanonicalCategoryRegistry.areSameCategory(name1: 'مفرزات', name2: 'منظفات'),
        isFalse,
      );
      expect(
        CanonicalCategoryRegistry.areSameCategory(name1: 'مجمدات', name2: 'منظفات'),
        isFalse,
      );
      expect(
        CanonicalCategoryRegistry.areSameCategory(name1: 'مفرزات', name2: 'مظفات'),
        isFalse,
      );

      // 'نقرشات' must NOT match 'مفرزات' or 'منظفات'
      expect(
        CanonicalCategoryRegistry.areSameCategory(name1: 'نقرشات', name2: 'مفرزات'),
        isFalse,
      );
      expect(
        CanonicalCategoryRegistry.areSameCategory(name1: 'نقرشات', name2: 'منظفات'),
        isFalse,
      );

      // 'لحوم ودواجن' must NOT match 'ألبان وأجبان'
      expect(
        CanonicalCategoryRegistry.areSameCategory(name1: 'لحوم ودواجن', name2: 'ألبان وأجبان'),
        isFalse,
      );
    });

    test('areSameCategory correctly equates aliases within the same canonical bucket', () {
      expect(
        CanonicalCategoryRegistry.areSameCategory(name1: 'غذايات', name2: 'غذائيات'),
        isTrue,
      );
      expect(
        CanonicalCategoryRegistry.areSameCategory(name1: 'أجبان وألبان', name2: 'ألبان وأجبان'),
        isTrue,
      );
      expect(
        CanonicalCategoryRegistry.areSameCategory(name1: 'منظفات', name2: 'المنظفات'),
        isTrue,
      );
      expect(
        CanonicalCategoryRegistry.areSameCategory(name1: 'مظفات', name2: 'المنظفات'),
        isTrue,
      );
      expect(
        CanonicalCategoryRegistry.areSameCategory(id1: 246, id2: 294),
        isTrue,
      );
    });
  });

  group('Banner URL Target Interpretation & Safety', () {
    test('Empty and no_link targets are treated as non-navigating', () {
      bool isDisplayOnly(String? url) {
        final raw = (url ?? '').trim();
        return raw.isEmpty || raw == 'none' || raw == 'no_link';
      }

      expect(isDisplayOnly(''), isTrue);
      expect(isDisplayOnly(null), isTrue);
      expect(isDisplayOnly('   '), isTrue);
      expect(isDisplayOnly('none'), isTrue);
      expect(isDisplayOnly('no_link'), isTrue);
      expect(isDisplayOnly('market:12'), isFalse);
      expect(isDisplayOnly('restaurant:5'), isFalse);
    });

    test('Explicit targets parse destination types and IDs correctly', () {
      Map<String, dynamic>? parseTarget(String rawUrl) {
        final clean = rawUrl.trim().split('#').first.trim();
        if (clean.isEmpty || clean == 'none' || clean == 'no_link') return null;

        if (clean.startsWith('http://') || clean.startsWith('https://')) {
          return {'type': 'external', 'url': clean};
        }
        if (clean.startsWith('restaurant:')) {
          return {'type': 'restaurant', 'id': int.tryParse(clean.split(':').last)};
        }
        if (clean.startsWith('merchant:') || clean.startsWith('market:') || clean.startsWith('store:')) {
          return {'type': 'market', 'id': int.tryParse(clean.split(':').last)};
        }
        if (clean.startsWith('category:')) {
          return {'type': 'category', 'param': clean.split(':').last.trim()};
        }
        if (clean == 'offers' || clean == 'promotions') {
          return {'type': 'offers'};
        }
        final directId = int.tryParse(clean);
        if (directId != null) {
          return {'type': 'market', 'id': directId};
        }
        return {'type': 'unknown', 'raw': clean};
      }

      // Explicit market targets
      expect(parseTarget('market:12'), equals({'type': 'market', 'id': 12}));
      expect(parseTarget('merchant:18'), equals({'type': 'market', 'id': 18}));
      expect(parseTarget('store:20'), equals({'type': 'market', 'id': 20}));
      expect(parseTarget('12'), equals({'type': 'market', 'id': 12}));

      // Explicit restaurant targets
      expect(parseTarget('restaurant:8'), equals({'type': 'restaurant', 'id': 8}));

      // Explicit category targets
      expect(parseTarget('category:110'), equals({'type': 'category', 'param': '110'}));
      expect(parseTarget('category:191'), equals({'type': 'category', 'param': '191'}));

      // Offers
      expect(parseTarget('offers'), equals({'type': 'offers'}));
      expect(parseTarget('promotions'), equals({'type': 'offers'}));

      // External URLs
      expect(parseTarget('https://example.com/promo'), equals({'type': 'external', 'url': 'https://example.com/promo'}));

      // Empty / non-configured
      expect(parseTarget(''), isNull);
      expect(parseTarget('none'), isNull);
    });
  });
}

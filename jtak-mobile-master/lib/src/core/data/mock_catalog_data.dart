import 'package:intl/intl.dart';

import '../../ui/widgets/catalog/meal_card_widget.dart';
import '../../ui/widgets/catalog/restaurant_card_widget.dart';

/// ---------------------------------------------------------------------------
/// JTAK Catalog Data Repository
///
/// 100% Authentic Syrian Restaurants, Traditional Cafes, Sweets & Bakeries
/// featuring Damascus, Aleppo and Syrian specialties with full customization
/// option groups (Bread, Tahini, Toum, Samin Baladi, Removals, Combos).
/// ---------------------------------------------------------------------------

class MockItemOption {
  final String id;
  final String name;
  final int price; // in Syrian Pounds (0 = free / included)
  final bool isDefault;

  const MockItemOption({
    required this.id,
    required this.name,
    this.price = 0,
    this.isDefault = false,
  });
}

class MockItemOptionGroup {
  final String id;
  final String title;
  final String? subtitle;
  final bool isRequired;
  final bool isMultiSelect;
  final int maxSelect;
  final List<MockItemOption> options;

  const MockItemOptionGroup({
    required this.id,
    required this.title,
    this.subtitle,
    this.isRequired = false,
    this.isMultiSelect = false,
    this.maxSelect = 1,
    required this.options,
  });
}

class MockMenuItemData {
  final int id;
  final String title;
  final String description;
  final String price;
  final int basePriceValue;
  final String category;
  final String imageUrl;
  final String calories;
  final double rating;
  final int restaurantId;
  final String restaurantName;
  final String eta;
  final String distance;
  final List<MockItemOptionGroup> optionGroups;

  const MockMenuItemData({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.basePriceValue = 35000,
    required this.category,
    required this.imageUrl,
    this.calories = '420 سعرة',
    this.rating = 4.8,
    required this.restaurantId,
    required this.restaurantName,
    this.eta = '20-30 دقيقة',
    this.distance = '2.4 كم',
    this.optionGroups = const [],
  });

  MealItemData toMealItemData({String? merchantLogo}) {
    String logo = merchantLogo ?? '';
    if (logo.isEmpty) {
      try {
        final parent = MockCatalogData.getRestaurantById(restaurantId);
        logo = parent.logoUrl;
      } catch (_) {}
    }
    return MealItemData(
      id: id,
      title: title,
      price: price,
      coverUrl: imageUrl,
      merchantLogoUrl: logo,
      merchantName: restaurantName,
      eta: eta,
      distance: distance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'basePriceValue': basePriceValue,
      'category': category,
      'imageUrl': imageUrl,
      'calories': calories,
      'rating': rating,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'eta': eta,
      'distance': distance,
    };
  }

  factory MockMenuItemData.fromMap(Map<String, dynamic> map) {
    return MockMenuItemData(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      price: map['price']?.toString() ?? '',
      basePriceValue: (map['basePriceValue'] as num?)?.toInt() ?? 0,
      category: map['category']?.toString() ?? 'وجبات',
      imageUrl: map['imageUrl']?.toString() ?? '',
      calories: map['calories']?.toString() ?? '420 سعرة',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.8,
      restaurantId: (map['restaurantId'] as num?)?.toInt() ?? 0,
      restaurantName: map['restaurantName']?.toString() ?? '',
      eta: map['eta']?.toString() ?? '20-30 دقيقة',
      distance: map['distance']?.toString() ?? '2.4 كم',
    );
  }
}

class MockRestaurantData {
  final int id;
  final String name;
  final String cuisine;
  final String categoryTag;
  final double rating;
  final int ratingCount;
  final String eta;
  final String distance;
  final String deliveryFee;
  final int minOrder;
  final String workingHours;
  final bool hasOffers;
  final bool isFast;
  final bool isMarket;
  final String coverUrl;
  final String logoUrl;
  final List<String> categories;
  final List<MockMenuItemData> menuItems;

  const MockRestaurantData({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.categoryTag,
    required this.rating,
    required this.ratingCount,
    required this.eta,
    required this.distance,
    required this.deliveryFee,
    this.minOrder = 30000,
    this.workingHours = 'حتى 3 ص',
    this.hasOffers = true,
    this.isFast = true,
    this.isMarket = false,
    required this.coverUrl,
    required this.logoUrl,
    required this.categories,
    required this.menuItems,
  });

  RestaurantItemData toRestaurantItemData() {
    return RestaurantItemData(
      id: id,
      name: name,
      coverUrl: coverUrl,
      logoUrl: logoUrl,
      category: cuisine,
      rating: rating,
      ratingCount: ratingCount,
      eta: eta,
      distance: distance,
      deliveryFee: deliveryFee,
      isVerified: true,
      isOpen: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cuisine': cuisine,
      'categoryTag': categoryTag,
      'rating': rating,
      'ratingCount': ratingCount,
      'eta': eta,
      'distance': distance,
      'deliveryFee': deliveryFee,
      'minOrder': minOrder,
      'workingHours': workingHours,
      'hasOffers': hasOffers,
      'isFast': isFast,
      'isMarket': isMarket,
      'coverUrl': coverUrl,
      'logoUrl': logoUrl,
      'categories': categories,
    };
  }

  factory MockRestaurantData.fromMap(Map<String, dynamic> map) {
    return MockRestaurantData(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? '',
      cuisine: map['cuisine']?.toString() ?? '',
      categoryTag: map['categoryTag']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.8,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 100,
      eta: map['eta']?.toString() ?? '20-30 دقيقة',
      distance: map['distance']?.toString() ?? '2.5 كم',
      deliveryFee: map['deliveryFee']?.toString() ?? '5,000 ل.س',
      minOrder: (map['minOrder'] as num?)?.toInt() ?? 30000,
      workingHours: map['workingHours']?.toString() ?? 'حتى 3 ص',
      hasOffers: map['hasOffers'] == true,
      isFast: map['isFast'] == true,
      isMarket: map['isMarket'] == true,
      coverUrl: map['coverUrl']?.toString() ?? '',
      logoUrl: map['logoUrl']?.toString() ?? '',
      categories: (map['categories'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['الكل'],
      menuItems: const [],
    );
  }
}

// ---------------------------------------------------------------------------
// Authentic Syrian Option Groups
// ---------------------------------------------------------------------------

final List<MockItemOptionGroup> _shawarmaOptionGroups = [
  const MockItemOptionGroup(
    id: 'bread_type',
    title: 'نوع الخبز الشامي',
    subtitle: 'إجباري - اختر ١',
    isRequired: true,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'saj', name: 'خبز صاج مقرمش ومحمر', price: 0, isDefault: true),
      MockItemOption(id: 'sayahi', name: 'خبز سياحي طري', price: 0),
      MockItemOption(id: 'mashrouh', name: 'خبز مشروح شامي كبير', price: 2000),
    ],
  ),
  const MockItemOptionGroup(
    id: 'garlic_sauce',
    title: 'الثومية والصلصات السورية',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'extra_toum', name: 'كريم ثوم شامي إكسترا', price: 3000),
      MockItemOption(id: 'spicy_toum', name: 'ثومية حارة بالدقة الدمشقية', price: 3000),
      MockItemOption(id: 'pomegranate_molasses', name: 'دبس رمان طبيعي مركز', price: 3000),
      MockItemOption(id: 'tahini_sauce', name: 'صوص طحينة بالليمون والكمون', price: 3000),
      MockItemOption(id: 'kashkaval_cheese', name: 'جبنة قشقوان سورية ذائبة', price: 8000),
      MockItemOption(id: 'extra_meat', name: 'دبل لحمة / دجاج إضافي (+50غ)', price: 12000),
    ],
  ),
  const MockItemOptionGroup(
    id: 'shawarma_removals',
    title: 'استبعاد مكونات (بدون)',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'no_toum', name: 'بدون ثومية', price: 0),
      MockItemOption(id: 'no_pickles', name: 'بدون مخلل لفت', price: 0),
      MockItemOption(id: 'no_fries_inside', name: 'بدون بطاطا داخل الساندوتش', price: 0),
    ],
  ),
  const MockItemOptionGroup(
    id: 'combo_upgrade',
    title: 'ترقية إلى وجبة كاملة',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'sandwich_only', name: 'ساندوتش فقط', price: 0, isDefault: true),
      MockItemOption(id: 'combo_regular', name: 'وجبة: بطاطا مقلية + كريم ثوم + مشروب', price: 14000),
      MockItemOption(id: 'combo_super', name: 'وجبة سوبر: بطاطا بالقشقوان + ثومية ومخلل + كولا', price: 20000),
    ],
  ),
];

final List<MockItemOptionGroup> _grillOptionGroups = [
  const MockItemOptionGroup(
    id: 'grill_doneness',
    title: 'درجة استواء المشاوي',
    subtitle: 'إجباري - اختر ١',
    isRequired: true,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'well_done', name: 'استواء كامل محمر على الفحم (Well Done)', price: 0, isDefault: true),
      MockItemOption(id: 'medium_well', name: 'استواء وسط طري وجوسي (Medium)', price: 0),
    ],
  ),
  const MockItemOptionGroup(
    id: 'bread_side',
    title: 'نوع الخبز والتقديم',
    subtitle: 'إجباري - اختر ١',
    isRequired: true,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'biwaz_bread', name: 'خبز محمر بالبيواز والبقدونس والسماق', price: 0, isDefault: true),
      MockItemOption(id: 'tannour', name: 'خبز تنور طازج ساخن', price: 2000),
      MockItemOption(id: 'sayahi', name: 'خبز سياحي شامي', price: 0),
    ],
  ),
  const MockItemOptionGroup(
    id: 'grill_sides',
    title: 'مقبلات وإضافات المشاوي',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'extra_biwaz', name: 'صحن بيواز إضافي (بصل، بقدونس، سماق)', price: 4000),
      MockItemOption(id: 'grilled_veg', name: 'طماطم وفلفل وبصل مشوي زيادة', price: 5000),
      MockItemOption(id: 'garlic_cream', name: 'كريم ثوم بلدي', price: 4000),
      MockItemOption(id: 'tahini', name: 'صلصة طحينة بلدية', price: 4000),
      MockItemOption(id: 'hummus_small', name: 'صحن حمص ناعم صغير', price: 12000),
      MockItemOption(id: 'mutabbal_small', name: 'صحن متبل باذنجان مشوي صغير', price: 14000),
    ],
  ),
  const MockItemOptionGroup(
    id: 'grill_removals',
    title: 'استبعاد (بدون)',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'no_onion', name: 'بدون بصل', price: 0),
      MockItemOption(id: 'no_spice', name: 'بدون شطة / فلفل حار', price: 0),
      MockItemOption(id: 'no_fat', name: 'دهنة خفيفة جداً', price: 0),
    ],
  ),
];

final List<MockItemOptionGroup> _fattehOptionGroups = [
  const MockItemOptionGroup(
    id: 'ghee_level',
    title: 'السمنة البلدية المقداحة',
    subtitle: 'إجباري - اختر ١',
    isRequired: true,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'samin_normal', name: 'سمنة بلدية حموية مقداحة عيار ممتاز', price: 0, isDefault: true),
      MockItemOption(id: 'samin_extra', name: 'سمنة بلدية دبل زيادة', price: 5000),
      MockItemOption(id: 'samin_light', name: 'سمنة خفيفة جداً', price: 0),
      MockItemOption(id: 'no_samin', name: 'بدون سمنة (بزيت الزيتون فقط)', price: 0),
    ],
  ),
  const MockItemOptionGroup(
    id: 'nuts_extra',
    title: 'المكسرات المحمصة',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'nuts_pine', name: 'صنوبر بلدي مقلي بالسمنة (إكسترا)', price: 12000),
      MockItemOption(id: 'nuts_almond', name: 'لوز مقشر محمص بالسمنة', price: 6000),
      MockItemOption(id: 'nuts_mix', name: 'مكسرات مكس (صنوبر ولوز)', price: 15000),
      MockItemOption(id: 'no_extra_nuts', name: 'الكمية العادية المرفقة فقط', price: 0, isDefault: true),
    ],
  ),
  const MockItemOptionGroup(
    id: 'fatteh_removals',
    title: 'استبعاد (بدون)',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'no_garlic', name: 'بدون ثوم في اللبن', price: 0),
      MockItemOption(id: 'no_cumin', name: 'بدون كمون', price: 0),
    ],
  ),
];

final List<MockItemOptionGroup> _bakdashOptionGroups = [
  const MockItemOptionGroup(
    id: 'pistachio_level',
    title: 'الفستق الحلبي',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'pistachio_normal', name: 'فستق حلبي أخضر عادي', price: 0, isDefault: true),
      MockItemOption(id: 'pistachio_extra', name: 'فستق حلبي إكسترا مضاعف', price: 8000),
    ],
  ),
  const MockItemOptionGroup(
    id: 'sweets_additions',
    title: 'إضافات شامية تراثية',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'ghazl_banat', name: 'غزل البنات الحريري فوق البوظة', price: 6000),
      MockItemOption(id: 'ashta_arabia', name: 'ملعقة قشطة عربية بلدية إضافية', price: 8000),
      MockItemOption(id: 'honey', name: 'رذاذ عسل جبلي طبيعي', price: 4000),
    ],
  ),
];

final List<MockItemOptionGroup> _sweetsOptionGroups = [
  const MockItemOptionGroup(
    id: 'syrup_level',
    title: 'عيار القطر (الشيرة)',
    subtitle: 'إجباري - اختر ١',
    isRequired: true,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'syrup_medium', name: 'قطر معتدل بماء الزهر', price: 0, isDefault: true),
      MockItemOption(id: 'syrup_light', name: 'قطر خفيف دايت', price: 0),
      MockItemOption(id: 'syrup_extra', name: 'قطر زيادة ساخن', price: 0),
    ],
  ),
  const MockItemOptionGroup(
    id: 'sweets_toppings',
    title: 'إضافات القشطة والمكسرات',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'extra_ashta', name: 'صحن قشطة بلدية طازجة جانبي', price: 14000),
      MockItemOption(id: 'extra_pistachio', name: 'رشة فستق حلبي أخضر ناعم', price: 6000),
    ],
  ),
];

final List<MockItemOptionGroup> _cafeSyrianOptionGroups = [
  const MockItemOptionGroup(
    id: 'sugar_level',
    title: 'عيار السكر',
    subtitle: 'إجباري - اختر ١',
    isRequired: true,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'sugar_medium', name: 'سكر وسط معتدل', price: 0, isDefault: true),
      MockItemOption(id: 'sugar_none', name: 'سادة (بدون سكر)', price: 0),
      MockItemOption(id: 'sugar_riha', name: 'على الريحة (سكر خفيف جداً)', price: 0),
      MockItemOption(id: 'sugar_sweet', name: 'حلوة (سكر زيادة)', price: 0),
    ],
  ),
  const MockItemOptionGroup(
    id: 'flavor_additions',
    title: 'النكهات والإضافات الشامية',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'extra_mastic', name: 'مستكة شامية فاخرة', price: 2000),
      MockItemOption(id: 'extra_cardamom', name: 'حب هيل مطحون زيادة', price: 2000),
      MockItemOption(id: 'extra_cinnamon', name: 'رشة قرفة مطحونة فريش', price: 1000),
      MockItemOption(id: 'orange_blossom', name: 'قطرات ماء زهر بلدي', price: 1000),
    ],
  ),
];

final List<MockItemOptionGroup> _burgerShamOptionGroups = [
  const MockItemOptionGroup(
    id: 'patty_size',
    title: 'حجم قرص اللحم البلدي',
    subtitle: 'إجباري - اختر ١',
    isRequired: true,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'single', name: 'سنجل (١٥٠ غرام لحم بلدي طازج)', price: 0, isDefault: true),
      MockItemOption(id: 'double', name: 'دبل (٣٠٠ غرام قطعتين لحم بلدي)', price: 16000),
    ],
  ),
  const MockItemOptionGroup(
    id: 'cheese_type',
    title: 'نوع الجبنة الذائبة',
    subtitle: 'إجباري - اختر ١',
    isRequired: true,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'kashkaval', name: 'جبنة قشقوان سورية بلدية ذائبة', price: 0, isDefault: true),
      MockItemOption(id: 'cheddar', name: 'جبنة شيدر كلاسيكية', price: 0),
    ],
  ),
  const MockItemOptionGroup(
    id: 'burger_extras',
    title: 'إضافات شهية',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'caramelized_onion', name: 'مربى بصل مكرمل بالسماق', price: 3000),
      MockItemOption(id: 'sauted_mushrooms', name: 'فطر طازج سوتيه بالزبدة', price: 5000),
      MockItemOption(id: 'sham_sauce', name: 'صوص الشام السري المدخن', price: 3000),
      MockItemOption(id: 'jalapeno', name: 'هالبينو حار مقرمش', price: 2000),
    ],
  ),
  const MockItemOptionGroup(
    id: 'burger_removals',
    title: 'استبعاد (بدون)',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'no_onion', name: 'بدون بصل', price: 0),
      MockItemOption(id: 'no_pickles', name: 'بدون مخلل', price: 0),
      MockItemOption(id: 'no_tomato', name: 'بدون طماطم', price: 0),
    ],
  ),
  const MockItemOptionGroup(
    id: 'side_meal',
    title: 'ترقية إلى وجبة متكاملة',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'sandwich_only', name: 'ساندوتش برغر فقط', price: 0, isDefault: true),
      MockItemOption(id: 'combo_fries_drink', name: 'وجبة: بطاطا كرسبي + بيبسي كولا', price: 14000),
      MockItemOption(id: 'combo_loaded', name: 'وجبة سوبر: بطاطا لوديد بالقشقوان + مشروب', price: 20000),
    ],
  ),
];

final List<MockItemOptionGroup> _artCafeOptionGroups = [
  const MockItemOptionGroup(
    id: 'coffee_size',
    title: 'حجم الكوب',
    subtitle: 'إجباري - اختر ١',
    isRequired: true,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'regular', name: 'حجم عادي (Medium - 350ml)', price: 0, isDefault: true),
      MockItemOption(id: 'large', name: 'حجم كبير (Large - 480ml)', price: 6000),
    ],
  ),
  const MockItemOptionGroup(
    id: 'milk_selection',
    title: 'نوع الحليب',
    subtitle: 'إجباري - اختر ١',
    isRequired: true,
    isMultiSelect: false,
    options: [
      MockItemOption(id: 'whole_milk', name: 'حليب كامل الدسم مبخر', price: 0, isDefault: true),
      MockItemOption(id: 'skim_milk', name: 'حليب خفيف الدسم', price: 0),
      MockItemOption(id: 'oat_milk', name: 'حليب شوفان نباتي باريستا', price: 5000),
      MockItemOption(id: 'almond_milk', name: 'حليب لوز نباتي', price: 5000),
    ],
  ),
  const MockItemOptionGroup(
    id: 'specialty_extras',
    title: 'إضافات القهوة المختصة',
    subtitle: 'اختياري',
    isRequired: false,
    isMultiSelect: true,
    options: [
      MockItemOption(id: 'extra_espresso', name: 'شوت إسبريسو إثيوبي إضافي', price: 5000),
      MockItemOption(id: 'vanilla_syrup', name: 'سيروب فانيلا طبيعي', price: 3000),
      MockItemOption(id: 'caramel_drizzle', name: 'رذاذ صوص كراميل ذهبي', price: 3000),
      MockItemOption(id: 'less_ice', name: 'ثلج خفيف (Less Ice)', price: 0),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Main Catalog Data Repository
// ---------------------------------------------------------------------------

class MockCatalogData {
  static final List<MockRestaurantData> restaurants = [
    // 1. شاورما أنس الدمشقية (Shawarma Anas)
    MockRestaurantData(
      id: 8,
      name: 'شاورما أنس الدمشقية',
      cuisine: 'شاورما سورية على أصولها، وجبات عربي وسندويش صاج',
      categoryTag: 'شاورما',
      rating: 4.9,
      ratingCount: 1850,
      eta: '15-25 دقيقة',
      distance: '1.8 كم',
      deliveryFee: '3,500 ل.س',
      minOrder: 30000,
      hasOffers: true,
      isFast: true,
      coverUrl: 'assets/images/restaurants/anas_cover.webp',
      logoUrl: 'assets/images/restaurants/anas_logo.webp',
      categories: ['الأكثر طلباً', 'شاورما دجاج صاج', 'شاورما لحمة بلدي', 'وجبات عربي عائلية', 'بروستد وسناك', 'مقبلات وصوصات'],
      menuItems: [
        MockMenuItemData(
          id: 101,
          restaurantId: 1,
          restaurantName: 'شاورما أنس الدمشقية',
          category: 'الأكثر طلباً',
          title: 'وجبة عربي سوبر دجاج أنس',
          description: 'ساندوتشين شاورما دجاج مقطع على الصاج مع كريم ثوم شامي أصلي، بطاطا مقلية مقرمشة ومخلل لفت.',
          price: '48,000 ل.س',
          basePriceValue: 48000,
          imageUrl: 'assets/images/restaurants/anas_dish.webp',
          calories: '820 سعرة',
          rating: 4.9,
          optionGroups: _shawarmaOptionGroups,
        ),
        MockMenuItemData(
          id: 102,
          restaurantId: 1,
          restaurantName: 'شاورما أنس الدمشقية',
          category: 'الأكثر طلباً',
          title: 'وجبة عربي لحمة بلدي بالصنوبر',
          description: 'شاورما لحم عجل وضان سوري محمر مع صوص طحينة بالليمون، بيواز بالسماق، مخللات وبطاطا مقلية.',
          price: '58,000 ل.س',
          basePriceValue: 58000,
          imageUrl: 'assets/images/products/Meat Shawarma Saj.webp',
          calories: '890 سعرة',
          rating: 4.9,
          optionGroups: _shawarmaOptionGroups,
        ),
        MockMenuItemData(
          id: 103,
          restaurantId: 1,
          restaurantName: 'شاورما أنس الدمشقية',
          category: 'شاورما دجاج صاج',
          title: 'ساندوتش شاورما دجاج صاج إكسترا ثومية',
          description: 'شاورما دجاج محمرة على الصاج بالثومية والمخلل في خبز صاج رقيق ومقرمش.',
          price: '28,000 ل.س',
          basePriceValue: 28000,
          imageUrl: 'assets/images/products/Arabic Chicken Shawarma Platter.webp',
          calories: '560 سعرة',
          rating: 4.9,
          optionGroups: _shawarmaOptionGroups,
        ),
        MockMenuItemData(
          id: 104,
          restaurantId: 1,
          restaurantName: 'شاورما أنس الدمشقية',
          category: 'شاورما لحمة بلدي',
          title: 'ساندوتش شاورما لحمة بلدي بدبس الرمان',
          description: 'لحم ضان متبل بالبهار الشامي في خبز صاج مع بيواز، دبس رمان مركز وطحينة سمسم.',
          price: '34,000 ل.س',
          basePriceValue: 34000,
          imageUrl: 'assets/images/products/Meat Shawarma Saj.webp',
          calories: '620 سعرة',
          rating: 4.8,
          optionGroups: _shawarmaOptionGroups,
        ),
        MockMenuItemData(
          id: 105,
          restaurantId: 1,
          restaurantName: 'شاورما أنس الدمشقية',
          category: 'وجبات عربي عائلية',
          title: 'صحن شاورما فرط مشكل (دجاج ولحم)',
          description: 'نصف كيلو شاورما مشكلة دجاج ولحم مع ثومية، طحينة، بيواز ومخللات وخبز صاج ساخن.',
          price: '75,000 ل.س',
          basePriceValue: 75000,
          imageUrl: 'assets/images/products/Arabic Chicken Shawarma Platter.webp',
          calories: '1100 سعرة',
          rating: 4.9,
          optionGroups: _shawarmaOptionGroups,
        ),
        MockMenuItemData(
          id: 106,
          restaurantId: 1,
          restaurantName: 'شاورما أنس الدمشقية',
          category: 'بروستد وسناك',
          title: 'وجبة بروستد أنس المقرمش (٤ قطع)',
          description: '٤ قطع دجاج بروستد ذهبي بتتبيلة أنس السرية مع بطاطا مقلية، كريم ثوم، كول سلو وخبز طازج.',
          price: '52,000 ل.س',
          basePriceValue: 52000,
          imageUrl: 'assets/images/products/Crispy Chicken Tower.webp',
          calories: '950 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 107,
          restaurantId: 1,
          restaurantName: 'شاورما أنس الدمشقية',
          category: 'مقبلات وصوصات',
          title: 'صحن بطاطا مقلية عائلي مع كريم ثوم',
          description: 'بطاطا ذهبية مقرمشة مع علبة كريم ثوم شامي أصلي ومخلل لفت بلدي.',
          price: '20,000 ل.س',
          basePriceValue: 20000,
          imageUrl: 'assets/images/products/Loaded Fire Fries.webp',
          calories: '450 سعرة',
          rating: 4.7,
        ),
        MockMenuItemData(
          id: 108,
          restaurantId: 1,
          restaurantName: 'شاورما أنس الدمشقية',
          category: 'مقبلات وصوصات',
          title: 'علبة كريم ثوم شامي إكسترا',
          description: 'ثومية شامية بيضاء ناصعة وقوام كريمي حريري مخفوقة على الأصول.',
          price: '6,000 ل.س',
          basePriceValue: 6000,
          imageUrl: 'assets/images/products/Arabic Chicken Shawarma Platter.webp',
          calories: '180 سعرة',
          rating: 4.9,
        ),
      ],
    ),

    // 2. مشاوي وكباب بوابة دمشق (Damascus Gate Grills)
    MockRestaurantData(
      id: 6,
      name: 'مشاوي وكباب بوابة دمشق',
      cuisine: 'مشاوي حلبية على الفحم، كباب حلبي، أوصال ضان وكبة',
      categoryTag: 'مشاوي',
      rating: 4.9,
      ratingCount: 2150,
      eta: '25-40 دقيقة',
      distance: '2.5 كم',
      deliveryFee: '4,000 ل.س',
      minOrder: 45000,
      hasOffers: true,
      isFast: true,
      coverUrl: 'assets/images/restaurants/damascus_cover.webp',
      logoUrl: 'assets/images/restaurants/damascus_logo.webp',
      categories: ['الأكثر طلباً', 'كباب حلبي وشامي', 'شيش ولحوم مشوية', 'كبة مشوية ومقلية', 'مقبلات وسلطات الشام'],
      menuItems: [
        MockMenuItemData(
          id: 201,
          restaurantId: 2,
          restaurantName: 'مشاوي وكباب بوابة دمشق',
          category: 'الأكثر طلباً',
          title: 'كيلو كباب حلبي مشوي عالفحم',
          description: 'أسياخ كباب غنم بلدي مشوي على الفحم الحجري مع بيواز بالبقدونس، طماطم وفلفل مشوي وخبز محمر.',
          price: '180,000 ل.س',
          basePriceValue: 18000,
          imageUrl: 'assets/images/restaurants/damascus_dish.webp',
          calories: '1450 سعرة',
          rating: 4.9,
          optionGroups: _grillOptionGroups,
        ),
        MockMenuItemData(
          id: 202,
          restaurantId: 2,
          restaurantName: 'مشاوي وكباب بوابة دمشق',
          category: 'الأكثر طلباً',
          title: 'نصف كيلو مشاوي مشكلة فاخرة',
          description: 'تشكيلة سيخ كباب غنم، سيخ شقف لحم ضان وسيخ شيش طاووق مع الخضار المشوية والخبز المحمص.',
          price: '95,000 ل.س',
          basePriceValue: 95000,
          imageUrl: 'assets/images/categories/meat_poultry.png',
          calories: '980 سعرة',
          rating: 4.9,
          optionGroups: _grillOptionGroups,
        ),
        MockMenuItemData(
          id: 203,
          restaurantId: 2,
          restaurantName: 'مشاوي وكباب بوابة دمشق',
          category: 'شيش ولحوم مشوية',
          title: 'وجبة شيش طاووق سوري بتتبيلة اللبن',
          description: 'أسياخ صدور دجاج طرية متبلة بالثوم والليمون واللبن الرائب مع كريم ثوم، بطاطا وخبز تنور.',
          price: '52,000 ل.س',
          basePriceValue: 52000,
          imageUrl: 'assets/images/categories/meat_poultry.png',
          calories: '720 سعرة',
          rating: 4.8,
          optionGroups: _grillOptionGroups,
        ),
        MockMenuItemData(
          id: 204,
          restaurantId: 2,
          restaurantName: 'مشاوي وكباب بوابة دمشق',
          category: 'كباب حلبي وشامي',
          title: 'كباب باذنجان دمشقي على السيخ',
          description: 'طبقات كباب لحم غنم مع شرائح باذنجان مشوي وصلصة طماطم وثوم على الفحم.',
          price: '58,000 ل.س',
          basePriceValue: 58000,
          imageUrl: 'assets/images/categories/meat_poultry.png',
          calories: '680 سعرة',
          rating: 4.8,
          optionGroups: _grillOptionGroups,
        ),
        MockMenuItemData(
          id: 205,
          restaurantId: 2,
          restaurantName: 'مشاوي وكباب بوابة دمشق',
          category: 'كبة مشوية ومقلية',
          title: 'قرص كبة مشوية على الجمر بالجوز',
          description: 'كبة برغل دمشقية محشوة باللحمة المفرومة، الجوز البلدي، حب الرمان والشحم الشهي.',
          price: '25,000 ل.س',
          basePriceValue: 25000,
          imageUrl: 'assets/images/restaurants/bouz_dish.webp',
          calories: '420 سعرة',
          rating: 4.9,
        ),
        MockMenuItemData(
          id: 206,
          restaurantId: 2,
          restaurantName: 'مشاوي وكباب بوابة دمشق',
          category: 'مقبلات وسلطات الشام',
          title: 'صحن تبولة شامية بزيت الزيتون البكر',
          description: 'بقدونس طازج مفروم ناعم مع برغل، طماطم، نعناع أخضر، ليمون وزيت زيتون بلدي معصور ع البارد.',
          price: '22,000 ل.س',
          basePriceValue: 22000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '210 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 207,
          restaurantId: 2,
          restaurantName: 'مشاوي وكباب بوابة دمشق',
          category: 'مقبلات وسلطات الشام',
          title: 'فتوش دمشقي بدبس الرمان والخبز المقرمش',
          description: 'خضار موسمية طازجة مع سماق بلدي، دبس رمان أصلي وقطع خبز محمص ذهبي.',
          price: '22,000 ل.س',
          basePriceValue: 22000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '240 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 208,
          restaurantId: 2,
          restaurantName: 'مشاوي وكباب بوابة دمشق',
          category: 'مقبلات وسلطات الشام',
          title: 'متبل باذنجان مشوي عالحطب مع طحينة',
          description: 'باذنجان مدخن مشوي على الحطب مهروس مع طحينة السمسم والليمون ومزين بحبات الرمان وزيت الزيتون.',
          price: '24,000 ل.س',
          basePriceValue: 24000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '260 سعرة',
          rating: 4.9,
        ),
      ],
    ),

    // 3. فطاير وفول بوز الجدي (Bouz El Jedi)
    MockRestaurantData(
      id: 10,
      name: 'فطاير وفول بوز الجدي',
      cuisine: 'فتات شامية بالسمنة البلدية، فول مدمس، فلافل ومسبحة',
      categoryTag: 'فطور شعبي',
      rating: 4.8,
      ratingCount: 1420,
      eta: '15-20 دقيقة',
      distance: '1.2 كم',
      deliveryFee: '2,500 ل.س',
      minOrder: 20000,
      hasOffers: false,
      isFast: true,
      coverUrl: 'assets/images/restaurants/bouz_cover.webp',
      logoUrl: 'assets/images/restaurants/bouz_logo.webp',
      categories: ['الأكثر طلباً', 'فتات وتساقي', 'فول وحمص بلدي', 'فلافل سخنة ومقرمشة', 'فطاير ومعجنات الفرن'],
      menuItems: [
        MockMenuItemData(
          id: 301,
          restaurantId: 3,
          restaurantName: 'فطاير وفول بوز الجدي',
          category: 'الأكثر طلباً',
          title: 'فتة حمص بالسمنة البلدية والصنوبر',
          description: 'تسقية شامية باللبن والطحينة والخبز المحمص والسمنة البلدية المقداحة مع صنوبر محمص.',
          price: '38,000 ل.س',
          basePriceValue: 38000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '650 سعرة',
          rating: 4.9,
          optionGroups: _fattehOptionGroups,
        ),
        MockMenuItemData(
          id: 302,
          restaurantId: 3,
          restaurantName: 'فطاير وفول بوز الجدي',
          category: 'الأكثر طلباً',
          title: 'صحن مسبحة شامية بزيت الزيتون البلدي',
          description: 'حمص ناعم متبل بالطحينة والليمون ومغطى بزيت الزيتون البكر والكمون والفليفلة الحمراء.',
          price: '24,000 ل.س',
          basePriceValue: 24000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '410 سعرة',
          rating: 4.9,
        ),
        MockMenuItemData(
          id: 303,
          restaurantId: 3,
          restaurantName: 'فطاير وفول بوز الجدي',
          category: 'فول وحمص بلدي',
          title: 'صحن فول مدمس باللبن والطحينة',
          description: 'فول بلدي مستوي على الهادي مع تتبيلة اللبن والطحينة والثوم وزيت الزيتون والنعناع.',
          price: '22,000 ل.س',
          basePriceValue: 22000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '380 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 304,
          restaurantId: 3,
          restaurantName: 'فطاير وفول بوز الجدي',
          category: 'فلافل سخنة ومقرمشة',
          title: 'دزينة فلافل شامية سخنة بالسمسم (١٢ قرص)',
          description: 'أقراص فلافل مقرمشة بالسمسم وحبة البركة مع طراطور ومخلل لفت وشطة شامية.',
          price: '18,000 ل.س',
          basePriceValue: 18000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '490 سعرة',
          rating: 4.9,
        ),
        MockMenuItemData(
          id: 305,
          restaurantId: 3,
          restaurantName: 'فطاير وفول بوز الجدي',
          category: 'فلافل سخنة ومقرمشة',
          title: 'ساندوتش فلافل إكسترا طراطور ولفت',
          description: 'فلافل ساخنة في خبز سياحي طري مع سلطة خيار وبندورة وطراطور متبل ومخلل لفت.',
          price: '14,000 ل.س',
          basePriceValue: 14000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '390 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 306,
          restaurantId: 3,
          restaurantName: 'فطاير وفول بوز الجدي',
          category: 'فطاير ومعجنات الفرن',
          title: 'فطيرة جبنة بلدية محمرة بالفرن',
          description: 'عجينة رقيقة ومحشوة بجبنة بلدية عكاوية مع حبة البركة والسمسم مخبوزة بالفرن الحجري.',
          price: '12,000 ل.س',
          basePriceValue: 12000,
          imageUrl: 'assets/images/products/Super Papa\'s Pizza.webp',
          calories: '310 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 307,
          restaurantId: 3,
          restaurantName: 'فطاير وفول بوز الجدي',
          category: 'فطاير ومعجنات الفرن',
          title: 'فطيرة زعتر حلبي بالزيت البلدي',
          description: 'فطيرة فرن سخنة بالزعتر الحلبي الأخضر الفاخر وزيت الزيتون الصافي.',
          price: '9,000 ل.س',
          basePriceValue: 9000,
          imageUrl: 'assets/images/products/BBQ Chicken Pizza.webp',
          calories: '260 سعرة',
          rating: 4.7,
        ),
        MockMenuItemData(
          id: 308,
          restaurantId: 3,
          restaurantName: 'فطاير وفول بوز الجدي',
          category: 'فول وحمص بلدي',
          title: 'صحن حمص باللحمة البلدية والصنوبر',
          description: 'حمص ناعم بالسمنة مع لحمة غنم مفرومة محموسة وصنوبر مقلي مقرمش.',
          price: '42,000 ل.س',
          basePriceValue: 42000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '540 سعرة',
          rating: 4.9,
        ),
      ],
    ),

    // 4. حلويات بكداش التراثية (Bakdash Sweets)
    MockRestaurantData(
      id: 7,
      name: 'حلويات بكداش التراثية',
      cuisine: 'أعرق بوظة شامية مدقوقة بالفستق الحلبي وحلاوة الجبن',
      categoryTag: 'حلويات',
      rating: 4.9,
      ratingCount: 3100,
      eta: '20-30 دقيقة',
      distance: '2.1 كم',
      deliveryFee: '3,000 ل.س',
      minOrder: 25000,
      hasOffers: true,
      isFast: true,
      coverUrl: 'assets/images/restaurants/bakdash_cover.webp',
      logoUrl: 'assets/images/restaurants/bakdash_logo.webp',
      categories: ['الأكثر طلباً', 'البوظة العربية المدقوقة', 'حلاوة الجبن والقشطة', 'حلويات دمشقية باردة', 'عصائر وكوكتيل شامي'],
      menuItems: [
        MockMenuItemData(
          id: 401,
          restaurantId: 4,
          restaurantName: 'حلويات بكداش التراثية',
          category: 'الأكثر طلباً',
          title: 'كيلو بوظة شامية مدقوقة بالفستق الحلبي',
          description: 'بوظة الحليب الطبيعي بالمستكة والسحلب مدقوقة بالمهباج ومغطاة بطبقة فستق أخضر فاخر.',
          price: '95,000 ل.س',
          basePriceValue: 95000,
          imageUrl: 'assets/images/restaurants/bakdash_dish.webp',
          calories: '1100 سعرة',
          rating: 4.9,
          optionGroups: _bakdashOptionGroups,
        ),
        MockMenuItemData(
          id: 402,
          restaurantId: 4,
          restaurantName: 'حلويات بكداش التراثية',
          category: 'الأكثر طلباً',
          title: 'زبدية بوظة عربية مع غزل البنات',
          description: 'كرات بوظة شامية بالفستق الحلبي مع غزل البنات الحريري ورشة ماء زهر نقي.',
          price: '32,000 ل.س',
          basePriceValue: 32000,
          imageUrl: 'assets/images/products/Classic Roll.webp',
          calories: '480 سعرة',
          rating: 4.9,
          optionGroups: _bakdashOptionGroups,
        ),
        MockMenuItemData(
          id: 403,
          restaurantId: 4,
          restaurantName: 'حلويات بكداش التراثية',
          category: 'حلاوة الجبن والقشطة',
          title: 'صحن حلاوة الجبن الحمصية بالقشطة البلدية',
          description: 'لفائف حلاوة الجبن الطرية محشوة قشطة عربية بلدية مع فستق حلبي وقطر ماء الزهر.',
          price: '36,000 ل.س',
          basePriceValue: 36000,
          imageUrl: 'assets/images/products/Chocobon.webp',
          calories: '520 سعرة',
          rating: 4.9,
          optionGroups: _sweetsOptionGroups,
        ),
        MockMenuItemData(
          id: 404,
          restaurantId: 4,
          restaurantName: 'حلويات بكداش التراثية',
          category: 'حلاوة الجبن والقشطة',
          title: 'صحن قشطة عربية بلدية بالعسل والموز',
          description: 'قشطة حليب بقري طازجة يومياً مع عسل نحل طبيعي، شرائح موز ومكسرات محمصة.',
          price: '42,000 ل.س',
          basePriceValue: 42000,
          imageUrl: 'assets/images/products/Caramel Pecanbon.webp',
          calories: '580 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 405,
          restaurantId: 4,
          restaurantName: 'حلويات بكداش التراثية',
          category: 'عصائر وكوكتيل شامي',
          title: 'كوكتيل إمبراطور شامي بالقشطة والعسل',
          description: 'طبقات عصير مانجو وفراولة طبيعية مع قطع فواكه، قشطة بلدية وفستق حلبي وعسل.',
          price: '34,000 ل.س',
          basePriceValue: 34000,
          imageUrl: 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?auto=format&fit=crop&w=600&q=80',
          calories: '490 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 406,
          restaurantId: 4,
          restaurantName: 'حلويات بكداش التراثية',
          category: 'حلويات دمشقية باردة',
          title: 'صحن مهلبية شامية بماء الورد والفستق',
          description: 'حلى حليب ناعم ومعطر بماء الورد الدمشقي ومزين بالفستق الحلبي الأخضر.',
          price: '20,000 ل.س',
          basePriceValue: 20000,
          imageUrl: 'assets/images/products/Cinnabon Bites Cup.webp',
          calories: '310 سعرة',
          rating: 4.7,
        ),
        MockMenuItemData(
          id: 407,
          restaurantId: 4,
          restaurantName: 'حلويات بكداش التراثية',
          category: 'حلويات دمشقية باردة',
          title: 'رز بحليب شامي بالفرن مع رشة قرفة',
          description: 'طبق رز بحليب غني ومكرمل بالفرن ومزين بجوز الهند والقرفة العطرية.',
          price: '22,000 ل.س',
          basePriceValue: 22000,
          imageUrl: 'assets/images/products/Classic Roll.webp',
          calories: '360 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 408,
          restaurantId: 4,
          restaurantName: 'حلويات بكداش التراثية',
          category: 'البوظة العربية المدقوقة',
          title: 'نصف كيلو بوظة عربية بالفستق الحلبي',
          description: 'علبة حرارية حافظة للبرودة نصف كيلو من بوظة بكداش المدقوقة الأصلية.',
          price: '52,000 ل.س',
          basePriceValue: 52000,
          imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80',
          calories: '580 سعرة',
          rating: 4.9,
          optionGroups: _bakdashOptionGroups,
        ),
      ],
    ),

    // 5. مقهى النوفرة التراثي (Al Noufara Heritage Cafe)
    MockRestaurantData(
      id: 11,
      name: 'مقهى النوفرة التراثي',
      cuisine: 'مقهى شامي عريق خلف الجامع الأموي، شاي بالنعناع وسحلب',
      categoryTag: 'كافيه ومشروبات',
      rating: 4.8,
      ratingCount: 1650,
      eta: '15-25 دقيقة',
      distance: '2.8 كم',
      deliveryFee: '3,500 ل.س',
      minOrder: 20000,
      hasOffers: true,
      isFast: true,
      coverUrl: 'assets/images/restaurants/noufara_cover.webp',
      logoUrl: 'assets/images/restaurants/noufara_logo.webp',
      categories: ['الأكثر طلباً', 'مشروبات شامية ساخنة', 'مشروبات باردة ومنعشة', 'حلويات وتسالي الشام'],
      menuItems: [
        MockMenuItemData(
          id: 501,
          restaurantId: 5,
          restaurantName: 'مقهى النوفرة التراثي',
          category: 'الأكثر طلباً',
          title: 'سحلب شامي ساخن بالقرفة والفستق الحلبي',
          description: 'سحلب حليب كثيف وطازج مع المستكة والقرفة وجوز الهند وفستق حلبي محمص.',
          price: '22,000 ل.س',
          basePriceValue: 22000,
          imageUrl: 'assets/images/restaurants/noufara_dish.webp',
          calories: '320 سعرة',
          rating: 4.9,
          optionGroups: _cafeSyrianOptionGroups,
        ),
        MockMenuItemData(
          id: 502,
          restaurantId: 5,
          restaurantName: 'مقهى النوفرة التراثي',
          category: 'الأكثر طلباً',
          title: 'قهوة شامية بالهيل والمستكة على الرمل',
          description: 'فنجان قهوة عربية محمصة بدرجة مثالية مع حب الهيل الفاخر والمستكة على الرمل الساخن.',
          price: '14,000 ل.س',
          basePriceValue: 14000,
          imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=600&q=80',
          calories: '35 سعرة',
          rating: 4.9,
          optionGroups: _cafeSyrianOptionGroups,
        ),
        MockMenuItemData(
          id: 503,
          restaurantId: 5,
          restaurantName: 'مقهى النوفرة التراثي',
          category: 'مشروبات شامية ساخنة',
          title: 'إبريق شاي دمشقي بالنعناع البلدي',
          description: 'شاي سيلاني مخدر على الفحم مع أوراق النعناع الأخضر الطازج في كاسات استكانة.',
          price: '16,000 ل.س',
          basePriceValue: 16000,
          imageUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=600&q=80',
          calories: '45 سعرة',
          rating: 4.8,
          optionGroups: _cafeSyrianOptionGroups,
        ),
        MockMenuItemData(
          id: 504,
          restaurantId: 5,
          restaurantName: 'مقهى النوفرة التراثي',
          category: 'مشروبات شامية ساخنة',
          title: 'زهورات شامية جبلية معسلة',
          description: 'خلطة أعشاب دمشقية طبيعية من البابونج، الورد الجوري والمليسة مع العسل الجبلي.',
          price: '14,000 ل.س',
          basePriceValue: 14000,
          imageUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=600&q=80',
          calories: '50 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 505,
          restaurantId: 5,
          restaurantName: 'مقهى النوفرة التراثي',
          category: 'مشروبات باردة ومنعشة',
          title: 'كركديه دمشقي مثلج منعش',
          description: 'شراب كركديه طبيعي بارد مع مكعبات الثلج وماء الورد الدمشقي العطري.',
          price: '16,000 ل.س',
          basePriceValue: 16000,
          imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=600&q=80',
          calories: '110 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 506,
          restaurantId: 5,
          restaurantName: 'مقهى النوفرة التراثي',
          category: 'مشروبات باردة ومنعشة',
          title: 'ليموناضة بلدية بالنعناع الأخضر',
          description: 'عصير ليمون طازج معصور مع النعناع الأخضر والسكر المعتدل ومكعبات الثلج.',
          price: '18,000 ل.س',
          basePriceValue: 18000,
          imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=600&q=80',
          calories: '140 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 507,
          restaurantId: 5,
          restaurantName: 'مقهى النوفرة التراثي',
          category: 'حلويات وتسالي الشام',
          title: 'صحن بليلة شامية ساخنة بالكمون والليمون',
          description: 'حمص حب مسلوق ساخن بالمرقة المتبلة والكمون وزيت الزيتون وعصير الليمون.',
          price: '15,000 ل.س',
          basePriceValue: 15000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '280 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 508,
          restaurantId: 5,
          restaurantName: 'مقهى النوفرة التراثي',
          category: 'حلويات وتسالي الشام',
          title: 'صحن فول نابت شامي بالكمون',
          description: 'فول نابت مسلوق ساخن بمرقته الشهية مع عصرة ليمون وكمون وزيت زيتون.',
          price: '15,000 ل.س',
          basePriceValue: 15000,
          imageUrl: 'assets/images/categories/dish_syrian.png',
          calories: '260 سعرة',
          rating: 4.7,
        ),
      ],
    ),

    // 6. كلاسيك برغر الشام (Classic Burger Sham)
    MockRestaurantData(
      id: 9,
      name: 'كلاسيك برغر الشام',
      cuisine: 'برغر لحم بلدي طازج يومياً، كرسبي تشيكن وبطاطا لوديد',
      categoryTag: 'البرجر',
      rating: 4.8,
      ratingCount: 1350,
      eta: '20-30 دقيقة',
      distance: '2.3 كم',
      deliveryFee: '4,000 ل.س',
      minOrder: 35000,
      hasOffers: true,
      isFast: true,
      coverUrl: 'assets/images/restaurants/burger_cover.webp',
      logoUrl: 'assets/images/restaurants/burger_logo.webp',
      categories: ['الأكثر طلباً', 'برغر لحم بلدي', 'دجاج كرسبي ومقرمش', 'بطاطا ومقبلات', 'مشروبات وصوصات'],
      menuItems: [
        MockMenuItemData(
          id: 601,
          restaurantId: 6,
          restaurantName: 'كلاسيك برغر الشام',
          category: 'الأكثر طلباً',
          title: 'برغر كلاسيك لحم بلدي وقشقوان',
          description: 'قرص لحم بقري بلدي مشوي مع جبنة قشقوان سورية، بصل مكرمل وصوص الشام الخاص في خبز بطاطا.',
          price: '46,000 ل.س',
          basePriceValue: 46000,
          imageUrl: 'assets/images/restaurants/burger_dish.webp',
          calories: '690 سعرة',
          rating: 4.9,
          optionGroups: _burgerShamOptionGroups,
        ),
        MockMenuItemData(
          id: 602,
          restaurantId: 6,
          restaurantName: 'كلاسيك برغر الشام',
          category: 'الأكثر طلباً',
          title: 'دبل سماش برغر لحم بلدي',
          description: 'قطعتين لحم بلدي سماش مع جبنة شيدر، مخلل خيار، خس وصوص سموكي برغر في خبز بريوش.',
          price: '56,000 ل.س',
          basePriceValue: 56000,
          imageUrl: 'assets/images/products/Double Angus Smash Burger.webp',
          calories: '860 سعرة',
          rating: 4.9,
          optionGroups: _burgerShamOptionGroups,
        ),
        MockMenuItemData(
          id: 603,
          restaurantId: 6,
          restaurantName: 'كلاسيك برغر الشام',
          category: 'دجاج كرسبي ومقرمش',
          title: 'ساندوتش كرسبي تشيكن سوبريم',
          description: 'صدر دجاج مقرمش ذهبي مع كول سلو حامض، جبنة شيدر، ثومية ومايونيز في خبز بريوش.',
          price: '44,000 ل.س',
          basePriceValue: 44000,
          imageUrl: 'assets/images/products/Crispy Chicken Tower.webp',
          calories: '740 سعرة',
          rating: 4.8,
          optionGroups: _burgerShamOptionGroups,
        ),
        MockMenuItemData(
          id: 604,
          restaurantId: 6,
          restaurantName: 'كلاسيك برغر الشام',
          category: 'دجاج كرسبي ومقرمش',
          title: 'كرسبي تندر ستريبس (٥ قطع)',
          description: 'أصابع دجاج مقرمشة بتتبيلة خاصة مع صوص ثوم وصوص باربكيو وبطاطا مقلية.',
          price: '42,000 ل.س',
          basePriceValue: 42000,
          imageUrl: 'assets/images/products/Crispy Chicken Tower.webp',
          calories: '620 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 605,
          restaurantId: 6,
          restaurantName: 'كلاسيك برغر الشام',
          category: 'بطاطا ومقبلات',
          title: 'بطاطا لوديد بالجبنة البلدية وصوص الشام',
          description: 'بطاطا مقلية ذهبية مغطاة بجبنة القشقوان والشيدر الذائبة وصوص الشام المدخن.',
          price: '26,000 ل.س',
          basePriceValue: 26000,
          imageUrl: 'assets/images/products/Loaded Fire Fries.webp',
          calories: '530 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 606,
          restaurantId: 6,
          restaurantName: 'كلاسيك برغر الشام',
          category: 'بطاطا ومقبلات',
          title: 'حلقات بصل مقرمشة مع صوص رانش',
          description: 'حلقات بصل طازجة مقلية ومقرمشة مع صوص رانش بالأعشاب.',
          price: '18,000 ل.س',
          basePriceValue: 18000,
          imageUrl: 'https://images.unsplash.com/photo-1639024471287-032f66e054cf?auto=format&fit=crop&w=600&q=80',
          calories: '380 سعرة',
          rating: 4.7,
        ),
        MockMenuItemData(
          id: 607,
          restaurantId: 6,
          restaurantName: 'كلاسيك برغر الشام',
          category: 'برغر لحم بلدي',
          title: 'برغر مشروم سويسري باللحم البلدي',
          description: 'لحم بلدي مع فطر طازج سوتيه بالزبدة وجبنة سويسرية وصوص مايونيز الثوم.',
          price: '52,000 ل.س',
          basePriceValue: 52000,
          imageUrl: 'assets/images/products/Double Angus Smash Burger.webp',
          calories: '780 سعرة',
          rating: 4.8,
          optionGroups: _burgerShamOptionGroups,
        ),
        MockMenuItemData(
          id: 608,
          restaurantId: 6,
          restaurantName: 'كلاسيك برغر الشام',
          category: 'دجاج كرسبي ومقرمش',
          title: 'ساندوتش زنجر سبايسي حار',
          description: 'صدر دجاج مقلي حار مع شرائح هالبينو، صوص ديناميت وخس مقرمش.',
          price: '46,000 ل.س',
          basePriceValue: 46000,
          imageUrl: 'assets/images/products/Crispy Chicken Tower.webp',
          calories: '760 سعرة',
          rating: 4.8,
          optionGroups: _burgerShamOptionGroups,
        ),
      ],
    ),

    // 7. حلويات داوود ومهنا (Dawood & Muhanna Sweets)
    MockRestaurantData(
      id: 5,
      name: 'حلويات داوود ومهنا',
      cuisine: 'حلويات دمشقية بالسمن الحيواني، مبرومة بالفستق ومعمول',
      categoryTag: 'حلويات',
      rating: 4.9,
      ratingCount: 1980,
      eta: '25-35 دقيقة',
      distance: '3.2 كم',
      deliveryFee: '4,500 ل.س',
      minOrder: 40000,
      hasOffers: true,
      isFast: false,
      coverUrl: 'assets/images/restaurants/dawood_cover.webp',
      logoUrl: 'assets/images/restaurants/dawood_logo.webp',
      categories: ['الأكثر طلباً', 'صواني البقلاوة والمبرومة', 'مدلوقة وكنافة نابلسية', 'معمول وغريبة وبرازق', 'علب هدايا مشكلة'],
      menuItems: [
        MockMenuItemData(
          id: 701,
          restaurantId: 7,
          restaurantName: 'حلويات داوود ومهنا',
          category: 'الأكثر طلباً',
          title: 'كيلو مبرومة بالفستق الحلبي البلدي',
          description: 'مبرومة شامية أصيلة محشوة بأجود أنواع الفستق الأخضر ومحضرة بالسمن الحيواني الفاخر.',
          price: '220,000 ل.س',
          basePriceValue: 220000,
          imageUrl: 'assets/images/restaurants/dawood_dish.webp',
          calories: '1650 سعرة',
          rating: 4.9,
          optionGroups: _sweetsOptionGroups,
        ),
        MockMenuItemData(
          id: 702,
          restaurantId: 7,
          restaurantName: 'حلويات داوود ومهنا',
          category: 'الأكثر طلباً',
          title: 'صحن مدلوقة بالقشطة البلدية والفستق',
          description: 'عجينة كنافة ناعمة بالسمن الحيواني مغطاة بطبقة قشطة بلدية طازجة وفستق حلبي محمص.',
          price: '45,000 ل.س',
          basePriceValue: 45000,
          imageUrl: 'assets/images/products/Chocobon.webp',
          calories: '640 سعرة',
          rating: 4.9,
          optionGroups: _sweetsOptionGroups,
        ),
        MockMenuItemData(
          id: 703,
          restaurantId: 7,
          restaurantName: 'حلويات داوود ومهنا',
          category: 'صواني البقلاوة والمبرومة',
          title: 'كيلو مشكل بقلاوة شامية فاخرة',
          description: 'تشكيلة راقية من البلورية، الآسية، كول وشكور، وربات زنود الست المحشوة بالفستق.',
          price: '190,000 ل.س',
          basePriceValue: 190000,
          imageUrl: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=600&q=80',
          calories: '1550 سعرة',
          rating: 4.9,
          optionGroups: _sweetsOptionGroups,
        ),
        MockMenuItemData(
          id: 704,
          restaurantId: 7,
          restaurantName: 'حلويات داوود ومهنا',
          category: 'صواني البقلاوة والمبرومة',
          title: 'صحن وربات بالقشطة البلدية مقرمشة',
          description: 'رقائق بقلاوة هشة محشوة قشطة بلدية ساخنة ومسقية بالقطر المعطر.',
          price: '38,000 ل.س',
          basePriceValue: 38000,
          imageUrl: 'assets/images/products/Caramel Pecanbon.webp',
          calories: '540 سعرة',
          rating: 4.8,
          optionGroups: _sweetsOptionGroups,
        ),
        MockMenuItemData(
          id: 705,
          restaurantId: 7,
          restaurantName: 'حلويات داوود ومهنا',
          category: 'معمول وغريبة وبرازق',
          title: 'علبة معمول مشكل بالفستق والعجوة (١ كغ)',
          description: 'معمول شامي بالسمن البلدي محشو فستق حلبي وتمر مديني فاخر.',
          price: '140,000 ل.س',
          basePriceValue: 140000,
          imageUrl: 'assets/images/products/Minibon 9-Pack Box.webp',
          calories: '1380 سعرة',
          rating: 4.9,
        ),
        MockMenuItemData(
          id: 706,
          restaurantId: 7,
          restaurantName: 'حلويات داوود ومهنا',
          category: 'معمول وغريبة وبرازق',
          title: 'علبة برازق شامية بالسمسم والفستق (١ كغ)',
          description: 'برازق دمشقية مقرمشة مغطاة بالسمسم المحمص ومحشوة بالفستق الأخضر.',
          price: '95,000 ل.س',
          basePriceValue: 95000,
          imageUrl: 'assets/images/products/Minibon 9-Pack Box.webp',
          calories: '1250 سعرة',
          rating: 4.9,
        ),
        MockMenuItemData(
          id: 707,
          restaurantId: 7,
          restaurantName: 'حلويات داوود ومهنا',
          category: 'مدلوقة وكنافة نابلسية',
          title: 'صحن كنافة نابلسية بالجبنة السايحة',
          description: 'كنافة خشنة محشوة جبنة عكاوية محلاة ومسقية بالقطر الساخن.',
          price: '40,000 ل.س',
          basePriceValue: 40000,
          imageUrl: 'assets/images/products/Classic Roll.webp',
          calories: '580 سعرة',
          rating: 4.8,
          optionGroups: _sweetsOptionGroups,
        ),
        MockMenuItemData(
          id: 708,
          restaurantId: 7,
          restaurantName: 'حلويات داوود ومهنا',
          category: 'معمول وغريبة وبرازق',
          title: 'علبة غريبة شامية بالسمن الحيواني (١ كغ)',
          description: 'غريبة بيضاء ناعمة تذوب بالفم ومزينة بحبة فستق حلبي أصلي.',
          price: '90,000 ل.س',
          basePriceValue: 90000,
          imageUrl: 'assets/images/products/Minibon 9-Pack Box.webp',
          calories: '1280 سعرة',
          rating: 4.8,
        ),
      ],
    ),

    // 8. أرت كافيه الشام (Art & Beans Cafe)
    MockRestaurantData(
      id: 4,
      name: 'أرت كافيه الشام',
      cuisine: 'قهوة مختصة، سبانش لاتيه، كولد برو وتشيزكيك التوت الشامي',
      categoryTag: 'كافيه ومشروبات',
      rating: 4.8,
      ratingCount: 1250,
      eta: '15-25 دقيقة',
      distance: '2.2 كم',
      deliveryFee: '3,500 ل.س',
      minOrder: 25000,
      hasOffers: true,
      isFast: true,
      coverUrl: 'assets/images/restaurants/art_cover.webp',
      logoUrl: 'assets/images/restaurants/art_logo.webp',
      categories: ['الأكثر طلباً', 'قهوة مختصة ساخنة', 'قهوة باردة ومثلجة', 'تشيزكيك وكيك فاخر', 'وافل وكريب'],
      menuItems: [
        MockMenuItemData(
          id: 801,
          restaurantId: 8,
          restaurantName: 'أرت كافيه الشام',
          category: 'الأكثر طلباً',
          title: 'آيسد سبانش لاتيه دمشقي فاخر',
          description: 'إسبريسو أرابيكا مزدوج مع حليب مكثف محلى وحليب بارد ومكعبات ثلج منعشة.',
          price: '32,000 ل.س',
          basePriceValue: 32000,
          imageUrl: 'assets/images/restaurants/art_dish.webp',
          calories: '310 سعرة',
          rating: 4.9,
          optionGroups: _artCafeOptionGroups,
        ),
        MockMenuItemData(
          id: 802,
          restaurantId: 8,
          restaurantName: 'أرت كافيه الشام',
          category: 'الأكثر طلباً',
          title: 'فلات وايت بالبن الإثيوبي المختص',
          description: 'دبل ريستريتو بنكهة فاكهية مع حليب مبخر برغوة مايكروفوم ناعمة جداً.',
          price: '26,000 ل.س',
          basePriceValue: 26000,
          imageUrl: 'https://images.unsplash.com/photo-1534778101976-62847782c213?auto=format&fit=crop&w=600&q=80',
          calories: '160 سعرة',
          rating: 4.8,
          optionGroups: _artCafeOptionGroups,
        ),
        MockMenuItemData(
          id: 803,
          restaurantId: 8,
          restaurantName: 'أرت كافيه الشام',
          category: 'قهوة باردة ومثلجة',
          title: 'آيس كراميل ماكياتو مثلج',
          description: 'طبقات الحليب البارد مع الفانيلا والإسبريسو ورذاذ صوص كراميل مركز.',
          price: '30,000 ل.س',
          basePriceValue: 30000,
          imageUrl: 'assets/images/products/Caramel Frappuccino.webp',
          calories: '280 سعرة',
          rating: 4.8,
          optionGroups: _artCafeOptionGroups,
        ),
        MockMenuItemData(
          id: 804,
          restaurantId: 8,
          restaurantName: 'أرت كافيه الشام',
          category: 'تشيزكيك وكيك فاخر',
          title: 'تشيز كيك التوت الشامي الطبيعي',
          description: 'تشيز كيك نيويورك مخبوز مغطى بصوص التوت الشامي البري الطبيعي.',
          price: '36,000 ل.س',
          basePriceValue: 36000,
          imageUrl: 'https://images.unsplash.com/photo-1533134242443-d4fd215305ad?auto=format&fit=crop&w=600&q=80',
          calories: '460 سعرة',
          rating: 4.9,
        ),
        MockMenuItemData(
          id: 805,
          restaurantId: 8,
          restaurantName: 'أرت كافيه الشام',
          category: 'وافل وكريب',
          title: 'وافل بلجيكي دافئ بالنوتيلا والفراولة',
          description: 'وافل مقرمش ومحشو بشوكولا نوتيلا مع قطع فراولة طازجة ومكسرات.',
          price: '38,000 ل.س',
          basePriceValue: 38000,
          imageUrl: 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?auto=format&fit=crop&w=600&q=80',
          calories: '540 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 806,
          restaurantId: 8,
          restaurantName: 'أرت كافيه الشام',
          category: 'وافل وكريب',
          title: 'كريب لوتس مقرمش مع آيس كريم',
          description: 'كريب رقيق محشو بصوص وزبدة اللوتس مع كرة آيس كريم فانيلا.',
          price: '36,000 ل.س',
          basePriceValue: 36000,
          imageUrl: 'https://images.unsplash.com/photo-1519869325930-281384150729?auto=format&fit=crop&w=600&q=80',
          calories: '510 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 807,
          restaurantId: 8,
          restaurantName: 'أرت كافيه الشام',
          category: 'قهوة باردة ومثلجة',
          title: 'كولد برو منقوع ٢٤ ساعة',
          description: 'قهوة باردة مستخلصة بالتقطير البطيء لنكهة نقية وسلسة خالية من المرارة.',
          price: '28,000 ل.س',
          basePriceValue: 28000,
          imageUrl: 'assets/images/products/Iced Spanish Latte.webp',
          calories: '15 سعرة',
          rating: 4.8,
        ),
        MockMenuItemData(
          id: 808,
          restaurantId: 8,
          restaurantName: 'أرت كافيه الشام',
          category: 'تشيزكيك وكيك فاخر',
          title: 'كوكيز الشوكولا المزدوجة بالكراميل',
          description: 'كوكي دافئة محشوة بقطع الشوكولا البلجيكية والكراميل الذائب.',
          price: '18,000 ل.س',
          basePriceValue: 18000,
          imageUrl: 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&w=600&q=80',
          calories: '340 سعرة',
          rating: 4.7,
        ),
      ],
    ),
  ];

    static MockRestaurantData getRestaurantById(int? id) {
    if (id == null) return restaurants.first;
    for (final r in restaurants) {
      if (r.id == id) return r;
    }
    // Mapping compatibility for 1-8 indexes:
    const legacyMap = {
      1: 8, // شاورما أنس
      2: 6, // مشاوي بوابة دمشق
      3: 10, // بوز الجدي
      4: 7, // بكداش
      5: 11, // النوفرة
      6: 9, // كلاسيك برغر
      7: 5, // داوود ومهنا
      8: 4, // أرت كافيه
    };
    if (legacyMap.containsKey(id)) {
      final backendId = legacyMap[id]!;
      for (final r in restaurants) {
        if (r.id == backendId) return r;
      }
    }
    return restaurants.first;
  }

  static MockRestaurantData? getMarketById(int? id) {
    if (id == null) return null;
    try {
      return restaurants.firstWhere((r) => r.id == id && r.isMarket);
    } catch (_) {
      return null;
    }
  }

  static MockRestaurantData getRestaurantByName(String name) {
    final q = name.toLowerCase().trim();
    if (q.contains('أنس') || q.contains('anas') || q.contains('شاورما')) {
      return restaurants.firstWhere((r) => r.id == 8, orElse: () => restaurants[0]);
    }
    if (q.contains('بوابة دمشق') || q.contains('مشاوي') || q.contains('كباب')) {
      return restaurants.firstWhere((r) => r.id == 6, orElse: () => restaurants[1]);
    }
    if (q.contains('بوز الجدي') || q.contains('فول') || q.contains('فلافل') || q.contains('فتات')) {
      return restaurants.firstWhere((r) => r.id == 10, orElse: () => restaurants[2]);
    }
    if (q.contains('بكداش') || q.contains('bakdash') || q.contains('بوظة')) {
      return restaurants.firstWhere((r) => r.id == 7, orElse: () => restaurants[3]);
    }
    if (q.contains('نوفرة') || q.contains('noufara') || q.contains('شاي')) {
      return restaurants.firstWhere((r) => r.id == 11, orElse: () => restaurants[4]);
    }
    if (q.contains('برغر') || q.contains('burger')) {
      return restaurants.firstWhere((r) => r.id == 9, orElse: () => restaurants[5]);
    }
    if (q.contains('داوود') || q.contains('مهنا') || q.contains('بقلاوة') || q.contains('مبرومة')) {
      return restaurants.firstWhere((r) => r.id == 5, orElse: () => restaurants[6]);
    }
    if (q.contains('أرت') || q.contains('art') || q.contains('beans')) {
      return restaurants.firstWhere((r) => r.id == 4, orElse: () => restaurants[7]);
    }
    return restaurants.firstWhere(
      (r) => r.name.toLowerCase().contains(q) || q.contains(r.name.toLowerCase()),
      orElse: () => restaurants.first,
    );
  }

  static const List<MockMenuItemData> allMarketMenuItems = [
    MockMenuItemData(
      id: 901,
      restaurantId: 6,
      restaurantName: 'جيتك ماركت',
      category: 'منتجات مبردة ومجمدة',
      title: 'لبنة بلدية سورية بالزيت والنعناع 500غ',
      description: 'لبنة بلدية سورية معصورة ومحفوظة بزيت الزيتون البكر.',
      price: '28,000 ل.س',
      basePriceValue: 28000,
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=300&q=80',
    ),
    MockMenuItemData(
      id: 902,
      restaurantId: 6,
      restaurantName: 'جيتك ماركت',
      category: 'منتجات مبردة ومجمدة',
      title: 'جبنة قشقوان سورية بلدية 400غ',
      description: 'جبنة قشقوان بلدية معتقة غنية بالطعم الشامي الأصيل.',
      price: '38,000 ل.س',
      basePriceValue: 38000,
      imageUrl: 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?auto=format&fit=crop&w=300&q=80',
    ),
    MockMenuItemData(
      id: 903,
      restaurantId: 6,
      restaurantName: 'جيتك ماركت',
      category: 'القهوة والشاي',
      title: 'بن الحموي الأصلي بالهيل الممتاز 250غ',
      description: 'قهوة سورية أصيلة محمصة بدرجة مثالية مع حب الهيل الفاخر.',
      price: '38,000 ل.س',
      basePriceValue: 38000,
      imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=300&q=80',
    ),
    MockMenuItemData(
      id: 904,
      restaurantId: 6,
      restaurantName: 'جيتك ماركت',
      category: 'الزيوت والمعلبات',
      title: 'زيت زيتون سوري بكر عصرة أولى 1 لتر',
      description: 'زيت زيتون بلدي معصور على البارد من حقول الزيتون السورية.',
      price: '85,000 ل.س',
      basePriceValue: 85000,
      imageUrl: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=300&q=80',
    ),
  ];

  static MockMenuItemData? getMenuItemById(int itemId) {
    for (final res in restaurants) {
      for (final item in res.menuItems) {
        if (item.id == itemId) return item;
      }
    }
    for (final marketItem in allMarketMenuItems) {
      if (marketItem.id == itemId) return marketItem;
    }
    return null;
  }

  static List<MockMenuItemData> getMenuItemsForRestaurant(int restaurantId, {String? category}) {
    final res = getRestaurantById(restaurantId);
    if (category == null || category.isEmpty || category == 'الكل') {
      return res.menuItems;
    }
    final filtered = res.menuItems.where((item) => item.category == category).toList();
    return filtered.isNotEmpty ? filtered : res.menuItems;
  }

  /// Showcase meals for Delivery Offers section (الأكثر طلباً)
  static List<MealItemData> get allDeliveryMeals {
    return const [
      MealItemData(
        id: 101,
        title: 'وجبة عربي سوبر دجاج أنس',
        price: '48,000 ل.س',
        coverUrl: 'assets/images/restaurants/anas_dish.webp',
        merchantLogoUrl: 'assets/images/restaurants/anas_logo.webp',
        merchantName: 'شاورما أنس الدمشقية',
        eta: '15-25 دقيقة',
        distance: '1.8 كم',
        merchantId: 8,
        numericPrice: 48000.0,
      ),
      MealItemData(
        id: 201,
        title: 'كيلو كباب حلبي مشوي عالفحم',
        price: '180,000 ل.س',
        coverUrl: 'assets/images/restaurants/damascus_dish.webp',
        merchantLogoUrl: 'assets/images/restaurants/damascus_logo.webp',
        merchantName: 'مشاوي وكباب بوابة دمشق',
        eta: '25-40 دقيقة',
        distance: '2.5 كم',
        merchantId: 6,
        numericPrice: 180000.0,
      ),
      MealItemData(
        id: 301,
        title: 'فتة حمص بالسمنة والصنوبر',
        price: '38,000 ل.س',
        coverUrl: 'assets/images/restaurants/bouz_dish.webp',
        merchantLogoUrl: 'assets/images/restaurants/bouz_logo.webp',
        merchantName: 'فطاير وفول بوز الجدي',
        eta: '15-20 دقيقة',
        distance: '1.2 كم',
        merchantId: 10,
        numericPrice: 38000.0,
      ),
      MealItemData(
        id: 401,
        title: 'بوظة بكداش شامية بالفستق',
        price: '95,000 ل.س',
        coverUrl: 'assets/images/restaurants/bakdash_dish.webp',
        merchantLogoUrl: 'assets/images/restaurants/bakdash_logo.webp',
        merchantName: 'حلويات بكداش التراثية',
        eta: '20-30 دقيقة',
        distance: '2.1 كم',
        merchantId: 7,
        numericPrice: 95000.0,
      ),
      MealItemData(
        id: 501,
        title: 'سحلب شامي بالقرفة والفستق',
        price: '22,000 ل.س',
        coverUrl: 'assets/images/restaurants/noufara_dish.webp',
        merchantLogoUrl: 'assets/images/restaurants/noufara_logo.webp',
        merchantName: 'مقهى النوفرة التراثي',
        eta: '15-25 دقيقة',
        distance: '2.8 كم',
        merchantId: 11,
        numericPrice: 22000.0,
      ),
      MealItemData(
        id: 601,
        title: 'برغر كلاسيك لحم بلدي وقشقوان',
        price: '46,000 ل.س',
        coverUrl: 'assets/images/restaurants/burger_dish.webp',
        merchantLogoUrl: 'assets/images/restaurants/burger_logo.webp',
        merchantName: 'كلاسيك برغر الشام',
        eta: '20-30 دقيقة',
        distance: '2.3 كم',
        merchantId: 9,
        numericPrice: 46000.0,
      ),
      MealItemData(
        id: 701,
        title: 'كيلو مبرومة بالفستق الحلبي البلدي',
        price: '220,000 ل.س',
        coverUrl: 'assets/images/restaurants/dawood_dish.webp',
        merchantLogoUrl: 'assets/images/restaurants/dawood_logo.webp',
        merchantName: 'حلويات داوود ومهنا',
        eta: '25-35 دقيقة',
        distance: '3.2 كم',
        merchantId: 5,
        numericPrice: 220000.0,
      ),
      MealItemData(
        id: 801,
        title: 'آيسد سبانش لاتيه دمشقي فاخر',
        price: '32,000 ل.س',
        coverUrl: 'assets/images/restaurants/art_dish.webp',
        merchantLogoUrl: 'assets/images/restaurants/art_logo.webp',
        merchantName: 'أرت كافيه الشام',
        eta: '15-25 دقيقة',
        distance: '2.2 كم',
        merchantId: 4,
        numericPrice: 32000.0,
      ),
    ];
  }

  static String formatCurrency(int amount) {
    final formatter = NumberFormat('#,###', 'en_US');
    return '${formatter.format(amount)} ل.س';
  }
}

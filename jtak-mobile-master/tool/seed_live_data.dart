import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> getAdminToken() async {
  final url = Uri.parse('https://api.jtak.app/connect/token');
  final body = {
    'grant_type': 'password',
    'username': 'admin@jtak.app',
    'password': 'P@ssw0rd',
    'scope': 'offline_access profile roles phone email',
  };
  final res = await http.post(
    url,
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: body,
  );
  if (res.statusCode != 200) {
    throw Exception('Login failed: ${res.statusCode} - ${res.body}');
  }
  final data = jsonDecode(res.body);
  return data['access_token'];
}

class LiveSeeder {
  final String token;
  late final Map<String, String> headers;

  LiveSeeder(this.token) {
    headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<int> createCategory(String title, {String icon = 'fas fa-utensils'}) async {
    final res = await http.post(
      Uri.parse('https://api.jtak.app/api/v1/Admin/ProductCategories'),
      headers: headers,
      body: jsonEncode({
        "title": title,
        "active": true,
        "icon": icon,
      }),
    );
    final id = int.tryParse(res.body) ?? 0;
    print('  ✓ Category created: "$title" (ID: $id)');
    return id;
  }

  Future<int> createMerchant({
    required String title,
    required String shortDescription,
    required String description,
    required String photo,
    required double lat,
    required double lng,
    required String address,
    required String phone,
  }) async {
    final res = await http.post(
      Uri.parse('https://api.jtak.app/api/v1/Admin/Merchants'),
      headers: headers,
      body: jsonEncode({
        "title": title,
        "shortDescription": shortDescription,
        "description": description,
        "photo": photo,
        "lat": lat,
        "lng": lng,
        "address": address,
        "phone1": phone,
        "shippingCoverageInMeters": 25000,
        "profitOutOfMerchantPricePercent": 10,
        "active": true,
      }),
    );
    final id = int.tryParse(res.body) ?? 0;

    // Ensure active is set to true via PUT
    if (id > 0) {
      await http.put(
        Uri.parse('https://api.jtak.app/api/v1/Admin/Merchants/$id'),
        headers: headers,
        body: jsonEncode({
          "id": id,
          "title": title,
          "shortDescription": shortDescription,
          "description": description,
          "photo": photo,
          "lat": lat,
          "lng": lng,
          "address": address,
          "phone1": phone,
          "shippingCoverageInMeters": 25000,
          "profitOutOfMerchantPricePercent": 10,
          "active": true,
        }),
      );
    }

    print('  🏪 Merchant created & activated: "$title" (ID: $id)');
    return id;
  }

  Future<int> createProduct({
    required String title,
    required int categoryId,
    required String unit,
    required String description,
    required String photo,
  }) async {
    final res = await http.post(
      Uri.parse('https://api.jtak.app/api/v1/Admin/Products'),
      headers: headers,
      body: jsonEncode({
        "title": title,
        "productCategoryId": categoryId,
        "unit": unit,
        "description": description,
        "photos": photo,
        "currency": 0,
        "active": true,
        "isFeatured": true,
      }),
    );
    final id = int.tryParse(res.body) ?? 0;
    return id;
  }

  Future<void> assignProductsToMerchant(int merchantId, List<Map<String, dynamic>> products) async {
    final res = await http.put(
      Uri.parse('https://api.jtak.app/api/v1/Admin/Merchants/Products/$merchantId'),
      headers: headers,
      body: jsonEncode(products),
    );
    print('  🔗 Linked ${products.length} products to Merchant #$merchantId (Status: ${res.statusCode})');
  }

  Future<void> createBanner({required String title, required String image}) async {
    final res = await http.post(
      Uri.parse('https://api.jtak.app/api/v1/Admin/Banner'),
      headers: headers,
      body: jsonEncode({
        "title": title,
        "image": image,
        "location": 0, // HomePage
        "active": true,
      }),
    );
    print('  🖼️ Banner created: "$title" (Status: ${res.statusCode})');
  }
}

void main() async {
  print('=====================================================');
  print('🚀 JTAK LIVE SERVER SEEDER — PUSHING AUTHENTIC DATA');
  print('=====================================================\n');

  final token = await getAdminToken();
  print('🔑 Admin Authenticated successfully!\n');

  final seeder = LiveSeeder(token);

  // 1. Create Categories
  print('--- 1. Creating Product Categories ---');
  final catFastFood = await seeder.createCategory('وجبات سريعة وبرغر', icon: 'fas fa-hamburger');
  final catShawarma = await seeder.createCategory('شاورما ومشويات', icon: 'fas fa-fire');
  final catSweets = await seeder.createCategory('حلويات ومخبوزات', icon: 'fas fa-cookie-bite');
  final catBreakfast = await seeder.createCategory('فطور شعبي وفلافل', icon: 'fas fa-egg');
  final catCoffee = await seeder.createCategory('قهوة ومشروبات', icon: 'fas fa-coffee');
  final catPizza = await seeder.createCategory('بيتزا وباستا', icon: 'fas fa-pizza-slice');
  final catGroceries = await seeder.createCategory('سوبرماركت ومواد غذائية', icon: 'fas fa-shopping-basket');

  // 2. Create Banners
  print('\n--- 2. Creating Promotional Banners ---');
  await seeder.createBanner(
    title: 'توصيل مجاني لطلبك الأول في دمشق',
    image: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=1000&auto=format&fit=crop&q=80',
  );
  await seeder.createBanner(
    title: 'عروض الشاورما الشامية الأصيلة - حسم 20%',
    image: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=1000&auto=format&fit=crop&q=80',
  );
  await seeder.createBanner(
    title: 'سينابون طازج يوصلك ساخن لباب بيتك',
    image: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=1000&auto=format&fit=crop&q=80',
  );

  // 3. Create Merchants & Menu Products
  print('\n--- 3. Creating Merchants & Menu Products ---');

  // Merchant 1: Cinnabon
  final mCinnabon = await seeder.createMerchant(
    title: 'سينابون - Cinnabon',
    shortDescription: 'حلويات ومخبوزات • 20-30 دقيقة',
    description: 'أشهر لفائف القرفة الساخنة مع صلصة الكريمة الجبنية اللذيذة.',
    photo: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800&auto=format&fit=crop&q=80',
    lat: 33.5138,
    lng: 36.2765,
    address: 'شارع أبو رمانة، دمشق',
    phone: '+96311332211',
  );

  final p1 = await seeder.createProduct(
    title: 'سينابون كلاسيك رول',
    categoryId: catSweets,
    unit: 'قطعة',
    description: 'لفافة القرفة الشهيرة المخبوزة طازجة والمغطاة بصلصة الكريمة الجبنية الغنية.',
    photo: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800&auto=format&fit=crop&q=80',
  );
  final p2 = await seeder.createProduct(
    title: 'ميني بون كراميل بيكان',
    categoryId: catSweets,
    unit: 'علبة 4 قطع',
    description: 'لفائف ميني بون هشة ومغطاة بالكراميل الغني وحبات جوز البيكان المحمص.',
    photo: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=800&auto=format&fit=crop&q=80',
  );
  final p3 = await seeder.createProduct(
    title: 'شوكابون فريش',
    categoryId: catSweets,
    unit: 'قطعة',
    description: 'لفافة سينابون محشوة ومغطاة بصلصة الشوكولاتة السويسرية الفاخرة.',
    photo: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=800&auto=format&fit=crop&q=80',
  );

  await seeder.assignProductsToMerchant(mCinnabon, [
    {"productId": p1, "price": 38000.0, "finalPrice": 38000.0, "additionalProfitPercent": 0, "isSelected": true},
    {"productId": p2, "price": 55000.0, "finalPrice": 55000.0, "additionalProfitPercent": 0, "isSelected": true},
    {"productId": p3, "price": 42000.0, "finalPrice": 42000.0, "additionalProfitPercent": 0, "isSelected": true},
  ]);

  // Merchant 2: Al-Midan Shawarma
  final mShawarma = await seeder.createMerchant(
    title: 'شاورما الميدان الشامية',
    shortDescription: 'شاورما ومشويات • 15-25 دقيقة',
    description: 'شاورما دجاج ولحم عالفحم على الأصول الشامية مع الثومية ومخلل اللفت المقرمش.',
    photo: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=800&auto=format&fit=crop&q=80',
    lat: 33.4985,
    lng: 36.2952,
    address: 'ساحة الميدان، جزماتية، دمشق',
    phone: '+96311887766',
  );

  final p4 = await seeder.createProduct(
    title: 'وجبة شاورما عربي دجاج إكسترا',
    categoryId: catShawarma,
    unit: 'وجبة كاملة',
    description: 'ساندويش شاورما مقطع بخبز الصاج مع بطاطا مقلية، كريم ثوم، مخلل، وصوص حار.',
    photo: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=800&auto=format&fit=crop&q=80',
  );
  final p5 = await seeder.createProduct(
    title: 'ساندويش شاورما لحم شامي صاج',
    categoryId: catShawarma,
    unit: 'ساندويش',
    description: 'لحم عجل ودوش غنم مع صلصة الطحينة، بيواز وبندورة مشوية.',
    photo: 'https://images.unsplash.com/photo-1561651823-34feb02250e4?w=800&auto=format&fit=crop&q=80',
  );
  final p6 = await seeder.createProduct(
    title: 'صحن مفركة شاورما دجاج بالجبنة',
    categoryId: catShawarma,
    unit: 'صحن عائلي',
    description: 'شاورما دجاج متبلة ومغطاة بطبقة وفيرة من جبنة القشقوان الذائبة.',
    photo: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&auto=format&fit=crop&q=80',
  );

  await seeder.assignProductsToMerchant(mShawarma, [
    {"productId": p4, "price": 45000.0, "finalPrice": 45000.0, "additionalProfitPercent": 0, "isSelected": true},
    {"productId": p5, "price": 32000.0, "finalPrice": 32000.0, "additionalProfitPercent": 0, "isSelected": true},
    {"productId": p6, "price": 68000.0, "finalPrice": 68000.0, "additionalProfitPercent": 0, "isSelected": true},
  ]);

  // Merchant 3: B-Burgers Gourmet
  final mBurgers = await seeder.createMerchant(
    title: 'بي-برغر دمشق - B-Burgers',
    shortDescription: 'برغر وبطاطا مقرمشة • 25-35 دقيقة',
    description: 'برغر لحم بقري أنغوس بلدي طازج يومياً مع خبز بريوش الزبدة وصلصات سرية خاصة.',
    photo: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&auto=format&fit=crop&q=80',
    lat: 33.5185,
    lng: 36.2820,
    address: 'شارع الشعلان، دمشق',
    phone: '+96311443322',
  );

  final p7 = await seeder.createProduct(
    title: 'سموك هاوس بيف برغر دبل',
    categoryId: catFastFood,
    unit: 'ساندويش دبل',
    description: 'قطعتين لحم أنغوس مع جبنة شيدر مدخنة، بصل مكرمل، وصوص الباربكيو المنزلي.',
    photo: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&auto=format&fit=crop&q=80',
  );
  final p8 = await seeder.createProduct(
    title: 'ترافل كرسبي تشيكن برغر',
    categoryId: catFastFood,
    unit: 'ساندويش',
    description: 'صدر دجاج مقرمش متبل بالأعشاب مع مايونيز الترافل الأسود وسلطة الكولسلو.',
    photo: 'https://images.unsplash.com/photo-1625813506062-0aeb1d7a094b?w=800&auto=format&fit=crop&q=80',
  );

  await seeder.assignProductsToMerchant(mBurgers, [
    {"productId": p7, "price": 58000.0, "finalPrice": 58000.0, "additionalProfitPercent": 0, "isSelected": true},
    {"productId": p8, "price": 48000.0, "finalPrice": 48000.0, "additionalProfitPercent": 0, "isSelected": true},
  ]);

  // Merchant 4: Falafel Al-Quds
  final mFalafel = await seeder.createMerchant(
    title: 'فلافل وفتات القدس',
    shortDescription: 'فطور شعبي وتساقي • 15-20 دقيقة',
    description: 'أعرق مطاعم الفطور الشامي: فتات بالسمنة البلدية، مسبحة ناعمة، وفلافل محشية بالجوز.',
    photo: 'https://images.unsplash.com/photo-1593001874117-c99c800e3eb7?w=800&auto=format&fit=crop&q=80',
    lat: 33.5110,
    lng: 36.2910,
    address: 'باب توما، دمشق القديمة',
    phone: '+96311554433',
  );

  final p9 = await seeder.createProduct(
    title: 'فتة حمص بالسمنة والصنوبر',
    categoryId: catBreakfast,
    unit: 'زبدية فخار',
    description: 'فتة حمص باللبن والطحينة مع خبز مقرمش ورشة سمنة عربية وصنوبر بلدي.',
    photo: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800&auto=format&fit=crop&q=80',
  );
  final p10 = await seeder.createProduct(
    title: 'دزينة فلافل شامي إكسترا',
    categoryId: catBreakfast,
    unit: '12 قرص',
    description: 'أقراص فلافل مقرمشة بالسمسم مع طرطور ومخللات مشكلة.',
    photo: 'https://images.unsplash.com/photo-1593001874117-c99c800e3eb7?w=800&auto=format&fit=crop&q=80',
  );

  await seeder.assignProductsToMerchant(mFalafel, [
    {"productId": p9, "price": 35000.0, "finalPrice": 35000.0, "additionalProfitPercent": 0, "isSelected": true},
    {"productId": p10, "price": 18000.0, "finalPrice": 18000.0, "additionalProfitPercent": 0, "isSelected": true},
  ]);

  // Merchant 5: Starbucks Coffee
  final mStarbucks = await seeder.createMerchant(
    title: 'ستاربكس كافيه - Starbucks',
    shortDescription: 'قهوة ممتازة ومشروبات • 15-25 دقيقة',
    description: 'قهوة الإسبريسو الفاخرة، فرابتشينو منعش، وكرواسون الزبدة الفرنسي.',
    photo: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800&auto=format&fit=crop&q=80',
    lat: 33.5170,
    lng: 36.2890,
    address: 'المالكي، دمشق',
    phone: '+96311665544',
  );

  final p11 = await seeder.createProduct(
    title: 'كراميل ماكياتو مثلج',
    categoryId: catCoffee,
    unit: 'كوب غراندي',
    description: 'إسبريسو طازج مع حليب بارد ونكهة الفانيلا مع خطوط صوص الكراميل.',
    photo: 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?w=800&auto=format&fit=crop&q=80',
  );
  final p12 = await seeder.createProduct(
    title: 'سبانش لاتيه دبل شوت',
    categoryId: catCoffee,
    unit: 'كوب وسط',
    description: 'إسبريسو مركز مع حليب مكثف محلى ناعم ورغوة غنية.',
    photo: 'https://images.unsplash.com/photo-1534778101976-62847782c213?w=800&auto=format&fit=crop&q=80',
  );

  await seeder.assignProductsToMerchant(mStarbucks, [
    {"productId": p11, "price": 28000.0, "finalPrice": 28000.0, "additionalProfitPercent": 0, "isSelected": true},
    {"productId": p12, "price": 26000.0, "finalPrice": 26000.0, "additionalProfitPercent": 0, "isSelected": true},
  ]);

  print('\n=====================================================');
  print('✅ SEEDING COMPLETE! ALL MERCHANTS & MENUS PUSHED LIVE');
  print('=====================================================');
}

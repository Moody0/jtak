import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> apiCall({
  required String method,
  required String path,
  String? token,
  dynamic body,
}) async {
  final args = <String>[
    '--resolve', 'api.jtak.app:443:172.67.149.162',
    '-s', '-k',
    '-X', method,
    'https://api.jtak.app$path',
  ];

  if (token != null) {
    args.addAll(['-H', 'Authorization: Bearer $token']);
  }

  if (body != null) {
    args.addAll(['-H', 'Content-Type: application/json']);
    if (body is String) {
      args.addAll(['-d', body]);
    } else {
      args.addAll(['-d', jsonEncode(body)]);
    }
  }

  final result = await Process.run('curl.exe', args);
  if (result.exitCode != 0) {
    throw Exception('Curl failed: ${result.stderr}');
  }

  final output = (result.stdout as String).trim();
  if (output.isEmpty) return {};
  try {
    return jsonDecode(output);
  } catch (_) {
    // If response is a number or primitive string (e.g. entity id)
    final numVal = int.tryParse(output);
    if (numVal != null) {
      return {'id': numVal};
    }
    return {'raw': output};
  }
}

Future<String> getAdminToken() async {
  final args = <String>[
    '--resolve', 'api.jtak.app:443:172.67.149.162',
    '-s', '-k',
    '-X', 'POST',
    'https://api.jtak.app/connect/token',
    '-d', 'grant_type=password&username=admin@jtak.app&password=P@ssw0rd&scope=offline_access',
  ];
  final result = await Process.run('curl.exe', args);
  final data = jsonDecode(result.stdout as String);
  return data['access_token'] as String;
}

void main() async {
  print('=====================================================');
  print('🛒 JTAK LIVE MARKETS SEEDER & SYNC');
  print('=====================================================');

  final token = await getAdminToken();
  print('🔑 Admin Authenticated successfully!');

  // 1. First, let's fetch all existing merchants to see what markets exist
  final tableRes = await apiCall(
    method: 'POST',
    path: '/api/v1/Admin/Merchants/DataTable',
    token: token,
    body: {
      "pageNumber": 0,
      "pageSize": 50,
      "sortField": "id",
      "sortOrder": "desc",
    },
  );

  final List existing = tableRes['items'] ?? [];
  print('Existing merchants in backend: ${existing.length}');

  // Markets definition
  final marketDefs = [
    {
      "title": "جيتك ماركت - JTAK Market",
      "shortDescription": "توصيل فوري فائق السرعة • 15-20 دقيقة",
      "description": "سوبرماركت ومقاضي سريعة، خضار وفواكه طازجة، ألبان وأجبان، ومستلزمات منزلية متكاملة.",
      "photo": "assets/images/markets/jtak_market.webp",
      "address": "شارع الثورة، وسط البلد، دمشق",
      "phone": "+96311223344",
      "lat": 33.5138,
      "lng": 36.2765,
    },
    {
      "title": "سوبرماركت أبناء شمسين",
      "shortDescription": "أكبر تشكيلة مونة ومقاضي • 20-30 دقيقة",
      "description": "تشكيلة واسعة من المونة السورية الفاخرة، معلبات، بقوليات، أجبان وزيوت بلدية.",
      "photo": "assets/images/markets/abnaa_shamsin.webp",
      "address": "ساحة الميدان، جزماتية، دمشق",
      "phone": "+96311334455",
      "lat": 33.5010,
      "lng": 36.2920,
    },
    {
      "title": "هايبرماركت قاسيون مول",
      "shortDescription": "عروض وتخفيضات أسبوعية • 25-35 دقيقة",
      "description": "هايبرماركت متكامل يقدم عروض وتخفيضات يومية وأسبوعية على كافة المنتجات الغذائية والمنزلية.",
      "photo": "assets/images/markets/qasioun_hypermarket.webp",
      "address": "مجمع قاسيون مول، برزة، دمشق",
      "phone": "+96311445566",
      "lat": 33.5420,
      "lng": 36.3110,
    },
    {
      "title": "سوبرماركت الهدى",
      "shortDescription": "أجبان، ألبان ومقاضي طازجة • 15-25 دقيقة",
      "description": "أفضل منتجات الألبان والأجبان البلدية الطازجة يومياً والخبز الساخن والبيض البلدي.",
      "photo": "assets/images/markets/al_huda.webp",
      "address": "شارع بغداد، دمشق",
      "phone": "+96311556677",
      "lat": 33.5210,
      "lng": 36.2980,
    },
    {
      "title": "سوبرماركت البركة",
      "shortDescription": "منتجات بلدية ومستوردة فاخرة • 20-35 دقيقة",
      "description": "أجود المنتجات الغذائية الطبيعية، خضار فريش، ومواد غذائية مستوردة عالية الجودة.",
      "photo": "assets/images/markets/al_baraka.webp",
      "address": "شارع المزرعة الرئيسي، دمشق",
      "phone": "+96311667788",
      "lat": 33.5280,
      "lng": 36.2890,
    },
    {
      "title": "سوبرماركت الدوحة",
      "shortDescription": "كل ما تحتاجه العائلة يومياً • 20-30 دقيقة",
      "description": "مقاضي الأسرة اليومية من المنظفات، العناية الشخصية، السناكات والمشروبات الباردة.",
      "photo": "assets/images/markets/al_dawha.webp",
      "address": "المزة فيلات غربية، دمشق",
      "phone": "+96311778899",
      "lat": 33.5040,
      "lng": 36.2610,
    },
  ];

  final createdMarketIds = <int>[];

  for (final m in marketDefs) {
    // Check if merchant already exists by title
    final match = existing.firstWhere(
      (e) => (e['title'] as String).trim() == (m['title'] as String).trim(),
      orElse: () => null,
    );

    int mid = 0;
    if (match != null) {
      mid = match['id'];
      print('  🏪 Market already exists: "${m['title']}" (ID: $mid). Updating details & ensuring active...');
      await apiCall(
        method: 'PUT',
        path: '/api/v1/Admin/Merchants/$mid',
        token: token,
        body: {
          "id": mid,
          "title": m['title'],
          "shortDescription": m['shortDescription'],
          "description": m['description'],
          "photo": m['photo'],
          "address": m['address'],
          "phone1": m['phone'],
          "shippingCoverageInMeters": 25000,
          "profitOutOfMerchantPricePercent": 10,
          "lat": m['lat'],
          "lng": m['lng'],
          "active": true,
        },
      );
    } else {
      print('  ➕ Creating new Market: "${m['title']}"...');
      final createRes = await apiCall(
        method: 'POST',
        path: '/api/v1/Admin/Merchants',
        token: token,
        body: {
          "title": m['title'],
          "shortDescription": m['shortDescription'],
          "description": m['description'],
          "photo": m['photo'],
          "address": m['address'],
          "phone1": m['phone'],
          "shippingCoverageInMeters": 25000,
          "profitOutOfMerchantPricePercent": 10,
          "lat": m['lat'],
          "lng": m['lng'],
          "active": true,
        },
      );

      mid = createRes['id'] ?? 0;
      if (mid > 0) {
        // Explicitly set active to true via PUT
        await apiCall(
          method: 'PUT',
          path: '/api/v1/Admin/Merchants/$mid',
          token: token,
          body: {
            "id": mid,
            "title": m['title'],
            "shortDescription": m['shortDescription'],
            "description": m['description'],
            "photo": m['photo'],
            "address": m['address'],
            "phone1": m['phone'],
            "shippingCoverageInMeters": 25000,
            "profitOutOfMerchantPricePercent": 10,
            "lat": m['lat'],
            "lng": m['lng'],
            "active": true,
          },
        );
        print('  ✓ Created and activated Market: "${m['title']}" (ID: $mid)');
      }
    }

    if (mid > 0) {
      createdMarketIds.add(mid);
    }
  }

  // 2. Fetch existing products from the database to assign to these markets
  print('\n--- 2. Assigning Grocery Catalog Products to Markets ---');
  final prodsRes = await apiCall(
    method: 'POST',
    path: '/api/v1/Admin/Products/DataTable',
    token: token,
    body: {
      "pageNumber": 0,
      "pageSize": 50,
      "sortField": "id",
      "sortOrder": "asc",
    },
  );

  final List allProds = prodsRes['items'] ?? [];
  print('Found ${allProds.length} catalog products available for assignment.');

  // Create assignments: each product gets a realistic price in Syrian Pounds (SYP)
  final priceMap = {
    1: 45000.0,  // ابتميل رقم 1
    2: 48000.0,  // ابتيمل رقم 4
    3: 15000.0,  // سكر ابيض
    4: 14000.0,  // عدس احمر
    5: 12000.0,  // برغل خشن
    6: 12000.0,  // برغل وسط
    7: 12500.0,  // برغل اسمر وسط
    8: 12500.0,  // برغل اسمر ناعم
    9: 12000.0,  // برغل ناعم
    10: 28000.0, // رز بالدو ممتاز
    11: 26000.0, // رز عثماني
    12: 18000.0, // ذرة
    13: 22000.0, // شفرات حلاقة جيليت
    14: 16000.0, // كتشاب و مايونيز
    15: 11000.0, // فرشاة اسنان للطفل
    16: 19000.0, // ممسحة
    17: 14000.0, // معجون اسنان سيجنال
    18: 8000.0,  // شمع مدور
  };

  for (final mid in createdMarketIds) {
    final assignments = <Map<String, dynamic>>[];
    for (final p in allProds) {
      final pid = p['id'] as int;
      final price = priceMap[pid] ?? (15000.0 + (pid * 1500));
      assignments.add({
        "productId": pid,
        "merchantPrice": price,
        "profitOutOfMerchantPricePercent": 10.0,
        "additionalProfitPercent": 0.0,
        "discount": 0.0,
      });
    }

    final assignRes = await apiCall(
      method: 'PUT',
      path: '/api/v1/Admin/Merchants/Products/$mid',
      token: token,
      body: assignments,
    );
    print('  📦 Assigned ${assignments.length} grocery products to Market #$mid (Status: ${assignRes})');
  }

  print('\n=====================================================');
  print('✅ ALL 6 MARKETS SEEDED & PRODUCTS ASSIGNED SUCCESSFULLY!');
  print('=====================================================');
}

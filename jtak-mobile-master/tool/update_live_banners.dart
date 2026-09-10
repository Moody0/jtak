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
  final data = jsonDecode(res.body);
  return data['access_token'];
}

void main() async {
  final token = await getAdminToken();
  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  print('Updating Banners with featuredImage ...');

  final banners = [
    {
      "id": 1,
      "title": "توصيل مجاني لطلبك الأول في دمشق",
      "featuredImage": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=1000&auto=format&fit=crop&q=80",
      "bannerLocation": 0,
      "active": true,
    },
    {
      "id": 2,
      "title": "عروض الشاورما الشامية الأصيلة - حسم 20%",
      "featuredImage": "https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=1000&auto=format&fit=crop&q=80",
      "bannerLocation": 0,
      "active": true,
    },
    {
      "id": 3,
      "title": "سينابون طازج يوصلك ساخن لباب بيتك",
      "featuredImage": "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=1000&auto=format&fit=crop&q=80",
      "bannerLocation": 0,
      "active": true,
    },
  ];

  for (var b in banners) {
    final res = await http.put(
      Uri.parse('https://api.jtak.app/api/v1/Admin/Banner/${b['id']}'),
      headers: headers,
      body: jsonEncode(b),
    );
    print('Banner ${b['id']} updated: ${res.statusCode}');
  }
}

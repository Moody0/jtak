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

  print('1. Assigning Cinnabon (ID: 2) products with merchantPrice ...');
  // p1=429, p2=430, p3=431
  final res = await http.put(
    Uri.parse('https://api.jtak.app/api/v1/Admin/Merchants/Products/2'),
    headers: headers,
    body: jsonEncode([
      {"productId": 429, "merchantPrice": 38000.0, "profitOutOfMerchantPricePercent": 10.0, "additionalProfitPercent": 0.0, "discount": 0.0},
      {"productId": 430, "merchantPrice": 55000.0, "profitOutOfMerchantPricePercent": 10.0, "additionalProfitPercent": 0.0, "discount": 0.0},
      {"productId": 431, "merchantPrice": 42000.0, "profitOutOfMerchantPricePercent": 10.0, "additionalProfitPercent": 0.0, "discount": 0.0},
    ]),
  );
  print('Assign products status: ${res.statusCode} - ${res.body}');

  print('\n2. Testing Customer Search API ...');
  final searchRes = await http.post(
    Uri.parse('https://api.jtak.app/api/v1/Customer/Products/Search'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      "lat": 33.5138,
      "lng": 36.2765,
      "page": 0,
      "take": 50,
    }),
  );
  print('Search status: ${searchRes.statusCode}');
  print('Search body: ${searchRes.body}');
}

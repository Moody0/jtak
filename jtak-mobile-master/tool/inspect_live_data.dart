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

  print('--- 1. Fetching Merchants ---');
  final mRes = await http.post(
    Uri.parse('https://api.jtak.app/api/v1/Admin/Merchants/DataTable'),
    headers: headers,
    body: jsonEncode({
      "pageNumber": 1,
      "pageSize": 50,
      "searchTerm": "",
      "sortField": "id",
      "sortOrder": "ASC"
    }),
  );
  print('Merchants: ${mRes.statusCode} - ${mRes.body}');

  print('\n--- 2. Fetching Product Categories ---');
  final cRes = await http.get(
    Uri.parse('https://api.jtak.app/api/v1/Customer/Catalog/ProductCategories'),
    headers: headers,
  );
  print('Categories: ${cRes.statusCode} - ${cRes.body}');

  print('\n--- 3. Fetching Banners ---');
  final bRes = await http.get(
    Uri.parse('https://api.jtak.app/api/v1/Customer/Banners'),
    headers: headers,
  );
  print('Banners: ${bRes.statusCode} - ${bRes.body}');
}

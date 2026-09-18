import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final tokenRes = await http.post(
    Uri.parse('https://api.jtak.app/connect/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'grant_type': 'password',
      'username': 'admin@jtak.app',
      'password': 'P@ssw0rd',
      'scope': 'offline_access profile roles phone email',
    },
  );
  final token = jsonDecode(tokenRes.body)['access_token'];
  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  print('=== ADMIN PRODUCT CATEGORIES ===');
  final catRes = await http.post(
    Uri.parse('https://api.jtak.app/api/v1/Admin/ProductCategories/DataTable'),
    headers: headers,
    body: jsonEncode({'pageNumber': 1, 'pageSize': 200, 'searchTerm': '', 'sortField': 'id', 'sortOrder': 'ASC'}),
  );
  if (catRes.statusCode == 200) {
    final catData = jsonDecode(catRes.body);
    final items = catData['items'] as List? ?? [];
    print('Total categories in DB: ${items.length}');
    Map<String, List<dynamic>> byName = {};
    for (var c in items) {
      final name = (c['name'] ?? c['title'] ?? '').toString().trim();
      byName.putIfAbsent(name, () => []).add(c);
      print('  ID: ${c['id']} | Name: "$name" | ParentId: ${c['parentId']} | Order: ${c['order']} | Active: ${c['active']}');
    }
    print('\n=== DUPLICATE NAMES IN DB ===');
    for (var entry in byName.entries) {
      if (entry.value.length > 1) {
        print('  Duplicate Name: "${entry.key}" -> IDs: ${entry.value.map((x) => x['id']).toList()}');
      }
    }
  }

  print('\n=== CUSTOMER PRODUCT CATEGORIES (Public API) ===');
  final pubRes = await http.get(Uri.parse('https://api.jtak.app/api/v1/Customer/ProductCategories'));
  if (pubRes.statusCode == 200) {
    final list = jsonDecode(pubRes.body) as List? ?? [];
    print('Total public categories: ${list.length}');
    for (var c in list) {
      print('  ID: ${c['id']} | Title: "${c['title']}" | ParentId: ${c['parentId']} | Order: ${c['order']}');
    }
  }
}

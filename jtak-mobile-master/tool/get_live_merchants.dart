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

  print('=== 1. CUSTOMER PRODUCTS MERCHANTS ===');
  final res = await http.get(Uri.parse('https://api.jtak.app/api/v1/Customer/Products/Merchants'), headers: headers);
  if (res.statusCode == 200) {
    final list = jsonDecode(res.body) as List? ?? [];
    print('Total merchants: ${list.length}');
    for (var m in list) {
      print('  ID: ${m['id']} | Title: "${m['title']}" | Kind: ${m['merchantKind']} | Active: ${m['active']} | Photo: ${m['photo']} | ShortDesc: "${m['shortDescription']}"');
    }
  } else {
    print('Customer merchants failed with status: ${res.statusCode}');
  }
}

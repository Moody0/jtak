import 'package:http/http.dart' as http;

void main() async {
  final endpoints = [
    'https://api.jtak.app/api/v1/Customer/Merchants',
    'https://api.jtak.app/api/v1/Customer/Catalog/Merchants',
    'https://api.jtak.app/api/v1/Customer/Home',
    'https://api.jtak.app/api/v1/Customer/Catalog/Products/Search',
  ];

  for (final ep in endpoints) {
    try {
      final res = await http.get(Uri.parse(ep));
      print('$ep => GET: ${res.statusCode}');
    } catch (e) {
      print('$ep => GET error: $e');
    }
  }
}

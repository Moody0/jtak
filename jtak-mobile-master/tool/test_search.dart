import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://api.jtak.app/api/v1/Customer/Products/Search');
  final body = {
    "lat": 33.5138,
    "lng": 36.2765,
    "page": 0,
    "take": 50,
  };

  final res = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  print('Search status: ${res.statusCode}');
  print('Search body: ${res.body}');
}

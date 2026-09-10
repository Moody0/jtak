import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://api.jtak.app/api/v1/Customer/Home'));
  final data = jsonDecode(res.body);
  print('Banners in Home: ${data['banners']}');
}

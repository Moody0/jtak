import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://api.jtak.app/api/v1/Customer/Home'));
  print('Customer Home status: ${res.statusCode}');
  print('Customer Home body: ${res.body}');
}

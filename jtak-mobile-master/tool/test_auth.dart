import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing Admin Authentication on https://api.jtak.app/connect/token ...');

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

  print('Status code: ${res.statusCode}');
  print('Response body: ${res.body}');
}

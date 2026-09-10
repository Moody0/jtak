import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createClient() {
  final ioClient = HttpClient()
    ..connectionFactory = (uri, proxyHost, proxyPort) async {
      if (uri.host == 'api.jtak.app') {
        return Socket.startConnect('172.67.149.162', uri.port);
      }
      return Socket.startConnect(uri.host, uri.port);
    }
    ..badCertificateCallback = (cert, host, port) => true;
  return IOClient(ioClient);
}

Future<String> getAdminToken(http.Client client) async {
  final url = Uri.parse('https://api.jtak.app/connect/token');
  final body = {
    'grant_type': 'password',
    'username': 'admin@jtak.app',
    'password': 'P@ssw0rd',
    'scope': 'offline_access profile roles phone email',
  };
  final res = await client.post(
    url,
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: body,
  );
  if (res.statusCode != 200) {
    throw Exception('Login failed: ${res.statusCode} - ${res.body}');
  }
  final data = jsonDecode(res.body);
  return data['access_token'];
}

void main() async {
  final client = createClient();
  final token = await getAdminToken(client);
  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final res = await client.post(
    Uri.parse('https://api.jtak.app/api/v1/Admin/Merchants/DataTable'),
    headers: headers,
    body: jsonEncode({
      "pageNumber": 0,
      "pageSize": 50,
      "sortField": "id",
      "sortOrder": "desc"
    }),
  );

  print('Status: ${res.statusCode}');
  final data = jsonDecode(res.body);
  final items = data['items'] ?? data['data'] ?? [];
  print('Total merchants: ${items.length}');
  for (var m in items) {
    print('ID: ${m['id']} | Title: "${m['title']}" | Active: ${m['active']} | ShortDesc: "${m['shortDescription']}" | Photo: "${m['photo']}" | ShippingCov: ${m['shippingCoverageInMeters']}');
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';

void main() {
  group('GlobalVar Image URL Normalization', () {
    test('Handles empty and null strings safely', () {
      expect(GlobalVar.getImageUrl(''), equals(''));
      expect(GlobalVar.getImageUrl('null'), equals(''));
    });

    test('Normalizes backslashes and leading slashes in paths', () {
      final url = GlobalVar.getImageUrl(r'\Uploads\products\item1.jpg');
      expect(url.contains(r'\'), isFalse);
      expect(url.contains('Uploads/products/item1.jpg'), isTrue);
    });

    test('Preserves full HTTP/HTTPS and assets URLs', () {
      expect(GlobalVar.getImageUrl('https://example.com/pic.png'), equals('https://example.com/pic.png'));
      expect(GlobalVar.getImageUrl('assets/images/logo.png'), equals('assets/images/logo.png'));
    });
  });
}

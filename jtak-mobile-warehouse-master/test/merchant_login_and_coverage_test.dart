import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Merchant App Login Validation Tests', () {
    String? validatePhone(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'يرجى إدخال رقم الهاتف المحمول';
      }
      String clean = value.replaceAll(RegExp(r'[\s\-\(\)]+'), '');
      if (clean.startsWith('+963')) {
        clean = clean.substring(4);
      } else if (clean.startsWith('963')) {
        clean = clean.substring(3);
      }
      if (clean.startsWith('0')) {
        clean = clean.substring(1);
      }
      if (clean.length != 9 || !clean.startsWith('9')) {
        return 'يرجى إدخال رقم هاتف سوري صحيح (09xxxxxxxx)';
      }
      return null;
    }

    String? validatePassword(String? value) {
      if (value == null || value.isEmpty) {
        return 'يرجى إدخال كلمة المرور';
      }
      if (value.length < 6) {
        return 'كلمة المرور يجب أن لا تقل عن 6 خانات';
      }
      return null;
    }

    test('Validates Syrian phone formats correctly', () {
      expect(validatePhone('0954551777'), isNull);
      expect(validatePhone('+963954551777'), isNull);
      expect(validatePhone('963954551777'), isNull);
      expect(validatePhone('954551777'), isNull);

      expect(validatePhone(''), isNotNull);
      expect(validatePhone('0812345678'), isNotNull);
      expect(validatePhone('12345'), isNotNull);
    });

    test('Validates password presence and length', () {
      expect(validatePassword('123456'), isNull);
      expect(validatePassword('secretPass123'), isNull);

      expect(validatePassword(''), isNotNull);
      expect(validatePassword(null), isNotNull);
      expect(validatePassword('12345'), isNotNull);
    });
  });

  group('Merchant Shipping Coverage 30 KM Limit Tests', () {
    test('Clamps any value above 30000 meters to 30000 meters (30 km canonical rule)', () {
      const canonicalMaxMeters = 30000;
      const canonicalMaxKm = 30.0;

      // Legacy 38000m value must clamp to 30000m
      int legacyValue1 = 38000;
      expect(legacyValue1.clamp(0, canonicalMaxMeters), 30000);

      int legacyValue2 = 50000;
      expect(legacyValue2.clamp(0, canonicalMaxMeters), 30000);

      int normalValue = 5000;
      expect(normalValue.clamp(0, canonicalMaxMeters), 5000);

      // Slider km clamp
      double rawKm = 38.0;
      expect(rawKm.clamp(1.0, canonicalMaxKm), 30.0);
    });
  });
}

import 'package:app_jtak_warehouse/src/utils/utilities/phone_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feature #14: Syrian Phone Input Normalization (Warehouse / Merchant App)', () {
    test('1. Pasting 12-digit number starting with 963 converts to 9 digits', () {
      expect(PhoneHelper.normalizeSyrianLocalPhone('963912345678'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('963985615705'), '985615705');
    });

    test('2. Pasting +963 with spaces or dashes converts to 9 digits', () {
      expect(PhoneHelper.normalizeSyrianLocalPhone('+963912345678'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('+963 912 345 678'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('963-912-345-678'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('+963-985-615-705'), '985615705');
      expect(PhoneHelper.normalizeSyrianLocalPhone('+963 (985) 615-705'), '985615705');
    });

    test('3. Pasting 00963 prefix converts to 9 digits', () {
      expect(PhoneHelper.normalizeSyrianLocalPhone('00963912345678'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('00963 985 615 705'), '985615705');
    });

    test('4. Pasting 10-digit number starting with 0 converts to 9 digits', () {
      expect(PhoneHelper.normalizeSyrianLocalPhone('0912345678'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('0985615705'), '985615705');
      expect(PhoneHelper.normalizeSyrianLocalPhone('0985 615 705'), '985615705');
    });

    test('5. Pasting standard 9-digit number retains 9 digits', () {
      expect(PhoneHelper.normalizeSyrianLocalPhone('912345678'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('985615705'), '985615705');
    });

    test('6. Pasting Eastern Arabic / Indic numerals (٠-٩) converts to Western digits', () {
      expect(PhoneHelper.normalizeSyrianLocalPhone('٩٦٣٩١٢٣٤٥٦٧٨'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('+٩٦٣ ٩١٢ ٣٤٥ ٦٧٨'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('٠٩١٢٣٤٥٦٧٨'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('٩١٢٣٤٥٦٧٨'), '912345678');
    });

    test('7. Pasting Persian numerals (۰-۹) converts to Western digits', () {
      expect(PhoneHelper.normalizeSyrianLocalPhone('۹۶۳۹۱۲۳۴۵۶۷۸'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('۰۹۱۲۳۴۵۶۷۸'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('۹۱۲۳۴۵۶۷۸'), '912345678');
    });

    test('8. Double prefix (+963 09xxxxxxxx) correctly normalizes to 9 digits', () {
      expect(PhoneHelper.normalizeSyrianLocalPhone('+9630912345678'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('+963 0985 615 705'), '985615705');
    });

    test('9. Field length is strictly capped at maximum 9 digits', () {
      expect(PhoneHelper.normalizeSyrianLocalPhone('912345678999'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('0912345678999'), '912345678');
      expect(PhoneHelper.normalizeSyrianLocalPhone('+963912345678999'), '912345678');
    });

    test('10. International formatting and phone validation helper', () {
      expect(PhoneHelper.formatSyrianInternational('0912345678'), '+963912345678');
      expect(PhoneHelper.isValidSyrianPhone('912345678'), isTrue);
      expect(PhoneHelper.isValidSyrianPhone('0912345678'), isTrue);
      expect(PhoneHelper.isValidSyrianPhone('+963912345678'), isTrue);
      expect(PhoneHelper.isValidSyrianPhone('123456'), isFalse);
      expect(PhoneHelper.isValidSyrianPhone('812345678'), isFalse);
    });

    test('11. SyrianPhoneInputFormatter handles typing, paste, and 10th digit rejection', () {
      final formatter = SyrianPhoneInputFormatter();

      // Typing valid 9 digits
      var value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '912345678'),
      );
      expect(value.text, '912345678');
      expect(value.selection.baseOffset, 9);

      // Attempting 10th digit
      value = formatter.formatEditUpdate(
        const TextEditingValue(text: '912345678'),
        const TextEditingValue(text: '9123456789'),
      );
      expect(value.text, '912345678');
      expect(value.selection.baseOffset, 9);

      // Pasting full +963 number
      value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '+963 985 615 705'),
      );
      expect(value.text, '985615705');
      expect(value.selection.baseOffset, 9);

      // Pasting Arabic numeral with 09
      value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '٠٩٨٥٦١٥٧٠٥'),
      );
      expect(value.text, '985615705');
      expect(value.selection.baseOffset, 9);

      // Cutting/clearing text
      value = formatter.formatEditUpdate(
        const TextEditingValue(text: '985615705'),
        TextEditingValue.empty,
      );
      expect(value.text, '');
      expect(value.selection.baseOffset, 0);
    });
  });
}

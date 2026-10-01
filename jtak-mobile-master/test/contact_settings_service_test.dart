import 'package:flutter_test/flutter_test.dart';
import 'package:jtek_app/src/core/models/contact_settings_model.dart';

void main() {
  group('ContactSettingsModel Unit Tests', () {
    test('Default values fallback correctly', () {
      const model = ContactSettingsModel();
      expect(model.phoneNumber, '0985615705');
      expect(model.phoneInternational, '+963985615705');
      expect(model.phoneFormatted, '0985 615 705');
      expect(model.whatsAppNumber, '963985615705');
      expect(model.supportEmail, 'contact@jtak.app');
      expect(model.facebookUrl, 'https://www.facebook.com/app.jtak/');
      expect(model.instagramUrl, 'https://www.instagram.com/JTAKcompany/');
      expect(model.youtubeUrl,
          'https://www.youtube.com/channel/UCXEnrIm0euKKFEQOROAQPSQ');
      expect(model.telegramUrl, '');
      expect(model.workingHoursAr, 'يومياً 9:00 ص - 12:00 منتصف الليل');
    });

    test('Parses backend json and normalizes phone variations', () {
      final json = {
        'phoneNumber': '0912345678',
        'phoneInternational': '+963912345678',
        'phoneFormatted': '0912 345 678',
        'whatsAppNumber': '963912345678',
        'supportEmail': 'support@custom.com',
        'facebookUrl': 'https://facebook.com/custom',
        'instagramUrl': 'https://instagram.com/custom',
        'youtubeUrl': 'https://youtube.com/custom',
        'telegramUrl': 'https://t.me/custom_jtak',
        'workingHoursAr': 'على مدار الساعة',
        'workingHoursEn': '24/7 Support',
        'addressAr': 'دمشق',
        'addressEn': 'Damascus',
      };

      final model = ContactSettingsModel.fromJson(json);
      expect(model.phoneNumber, '0912345678');
      expect(model.phoneInternational, '+963912345678');
      expect(model.phoneFormatted, '0912 345 678');
      expect(model.whatsAppNumber, '963912345678');
      expect(model.supportEmail, 'support@custom.com');
      expect(model.facebookUrl, 'https://facebook.com/custom');
      expect(model.instagramUrl, 'https://instagram.com/custom');
      expect(model.youtubeUrl, 'https://youtube.com/custom');
      expect(model.telegramUrl, 'https://t.me/custom_jtak');
      expect(model.workingHoursAr, 'على مدار الساعة');
    });

    test('Json roundtrip preserves values', () {
      final json = {
        'phoneNumber': '0999888777',
        'phoneInternational': '+963999888777',
        'phoneFormatted': '0999 888 777',
        'whatsAppNumber': '963999888777',
        'supportEmail': 'test@jtak.app',
        'facebookUrl': 'https://facebook.com/jtak',
        'instagramUrl': 'https://instagram.com/jtak',
        'youtubeUrl': 'https://youtube.com/jtak',
        'telegramUrl': 'https://t.me/jtak',
        'workingHoursAr': 'يومياً',
        'workingHoursEn': 'Daily',
        'addressAr': 'حمص',
        'addressEn': 'Homs',
      };

      final model = ContactSettingsModel.fromJson(json);
      final raw = model.toJsonString();
      final restored = ContactSettingsModel.fromJsonString(raw);

      expect(restored.phoneNumber, model.phoneNumber);
      expect(restored.whatsAppNumber, model.whatsAppNumber);
      expect(restored.telegramUrl, model.telegramUrl);
    });
  });
}

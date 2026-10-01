import 'dart:convert';
import '../../config/constants/app_constant.dart';

class ContactSettingsModel {
  final String phoneNumber;
  final String phoneInternational;
  final String phoneFormatted;
  final String whatsAppNumber;
  final String supportEmail;
  final String facebookUrl;
  final String instagramUrl;
  final String youtubeUrl;
  final String telegramUrl;
  final String workingHoursAr;
  final String workingHoursEn;
  final String addressAr;
  final String addressEn;

  const ContactSettingsModel({
    this.phoneNumber = '0985615705',
    this.phoneInternational = kSupportPhoneInternational,
    this.phoneFormatted = '0985 615 705',
    this.whatsAppNumber = '963985615705',
    this.supportEmail = 'contact@jtak.app',
    this.facebookUrl = 'https://www.facebook.com/app.jtak/',
    this.instagramUrl = 'https://www.instagram.com/JTAKcompany/',
    this.youtubeUrl =
        'https://www.youtube.com/channel/UCXEnrIm0euKKFEQOROAQPSQ',
    this.telegramUrl = '',
    this.workingHoursAr = 'يومياً 9:00 ص - 12:00 منتصف الليل',
    this.workingHoursEn = 'Daily 9:00 AM - 12:00 Midnight',
    this.addressAr = 'سوريا - حمص',
    this.addressEn = 'Syria - Homs',
  });

  factory ContactSettingsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ContactSettingsModel();

    String normalize(String? value, String fallback) {
      if (value == null) return fallback;
      final trimmed = value.trim();
      return trimmed.isNotEmpty ? trimmed : fallback;
    }

    final phone = normalize(json['phoneNumber']?.toString(), '0985615705');
    final intl = normalize(
        json['phoneInternational']?.toString(),
        phone.startsWith('0')
            ? '+963${phone.substring(1)}'
            : (phone.startsWith('+') ? phone : '+963$phone'));
    final formatted = normalize(
        json['phoneFormatted']?.toString(),
        phone.length == 10
            ? '${phone.substring(0, 4)} ${phone.substring(4, 7)} ${phone.substring(7)}'
            : phone);
    final wa = normalize(json['whatsAppNumber']?.toString(), '963985615705');

    return ContactSettingsModel(
      phoneNumber: phone,
      phoneInternational: intl,
      phoneFormatted: formatted,
      whatsAppNumber: wa,
      supportEmail: normalize(json['supportEmail']?.toString(), 'contact@jtak.app'),
      facebookUrl: normalize(
          json['facebookUrl']?.toString(), 'https://www.facebook.com/app.jtak/'),
      instagramUrl: normalize(json['instagramUrl']?.toString(),
          'https://www.instagram.com/JTAKcompany/'),
      youtubeUrl: normalize(json['youtubeUrl']?.toString(),
          'https://www.youtube.com/channel/UCXEnrIm0euKKFEQOROAQPSQ'),
      telegramUrl: json['telegramUrl']?.toString().trim() ?? '',
      workingHoursAr: normalize(
          json['workingHoursAr']?.toString(), 'يومياً 9:00 ص - 12:00 منتصف الليل'),
      workingHoursEn: normalize(
          json['workingHoursEn']?.toString(), 'Daily 9:00 AM - 12:00 Midnight'),
      addressAr: normalize(json['addressAr']?.toString(), 'سوريا - حمص'),
      addressEn: normalize(json['addressEn']?.toString(), 'Syria - Homs'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'phoneInternational': phoneInternational,
      'phoneFormatted': phoneFormatted,
      'whatsAppNumber': whatsAppNumber,
      'supportEmail': supportEmail,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
      'youtubeUrl': youtubeUrl,
      'telegramUrl': telegramUrl,
      'workingHoursAr': workingHoursAr,
      'workingHoursEn': workingHoursEn,
      'addressAr': addressAr,
      'addressEn': addressEn,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory ContactSettingsModel.fromJsonString(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return ContactSettingsModel.fromJson(decoded);
      }
    } catch (_) {}
    return const ContactSettingsModel();
  }
}

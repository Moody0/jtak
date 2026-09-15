import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:app_jtak_warehouse/src/config/constants/app_constant.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/syrian_flag.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/lunch_url.dart';

/// Modern, clean, flat bottom sheet displayed when an entered phone number
/// is not registered as an authorized merchant in JTAK.
class MerchantUnregisteredSheet extends StatelessWidget {
  final String phoneNumber;

  const MerchantUnregisteredSheet({
    Key? key,
    required this.phoneNumber,
  }) : super(key: key);

  static Future<bool?> show(BuildContext context, {required String phoneNumber}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MerchantUnregisteredSheet(phoneNumber: phoneNumber),
    );
  }

  void _openWhatsApp(BuildContext context) {
    final cleanPhone = kSupportWhatsApp.replaceAll('+', '').replaceAll(' ', '');
    final message = Uri.encodeComponent(
      'مرحباً إدارة جيتك، أود الاستفسار عن تسجيل وتفعيل حساب التاجر لرقم الهاتف: $phoneNumber',
    );
    final url = 'https://wa.me/$cleanPhone?text=$message';
    LunchUrl.canLaunch(url);
  }

  void _callSupport(BuildContext context) {
    LunchUrl.canLaunch('tel:$kSupportPhone');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top pill handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Icon Badge (Flat, no shadow)
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFEDD5), width: 1.5),
            ),
            child: const Center(
              child: Icon(
                PhosphorIconsBold.storefront,
                color: Color(0xFFEA580C),
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            'هذا الرقم غير مسجل كتاجر',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),

          // Explanation
          Text(
            'لوحة تحكم المستودع مخصصة لتجار وشركاء جيتك المعتمدين فقط. إذا كنت صاحب متجر وترغب بالانضمام إلينا أو تفعيل حسابك، يمكنك التواصل مباشرة مع فريق العمليات.',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),

          // Phone Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                  child: SyrianFlag(width: 20, height: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  phoneNumber,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action 1: WhatsApp Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _openWhatsApp(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsFill.whatsappLogo, size: 22, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'تواصل عبر واتساب مع العمليات',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Action 2: Phone Call Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => _callSupport(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                foregroundColor: const Color(0xFF1E293B),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsBold.phoneCall, size: 20, color: Color(0xFF1E293B)),
                  const SizedBox(width: 10),
                  Text(
                    'اتصال هاتفي: $kSupportPhone',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ),

          // Debug test option (only in debug mode)
          if (kDebugMode) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(PhosphorIconsBold.shieldCheck, size: 18, color: Color(0xFFEA580C)),
                label: Text(
                  'المتابعة كتاجر تجريبي (وضع التطوير - Debug)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEA580C),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7ED),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Cancel / Edit button
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'تصحيح رقم الهاتف',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

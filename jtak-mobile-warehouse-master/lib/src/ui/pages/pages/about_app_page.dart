import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../config/constants/constants.dart';
import '../../../config/themes/colors.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/lunch_url.dart';
import 'app_page.dart';

/// ---------------------------------------------------------------------------
/// Dedicated About App & Merchant Support Page
/// Provides app details, technical support links, version info and company bio.
/// ---------------------------------------------------------------------------

class AboutAppPage extends StatelessWidget {
  static const String routeName = '/AboutAppPage';

  const AboutAppPage({super.key});

  static const String appVersion = '1.0.3';
  static const String appBuild = '15';
  static const String supportPhone = '+963987654321';
  static const String supportWhatsApp = 'https://wa.me/963987654321';
  static const String officialWebsite = 'https://jtak.sy';

  void _openUrl(BuildContext context, String url) async {
    HapticFeedback.lightImpact();
    final ok = await LunchUrl.canLaunch(url);
    if (!ok && context.mounted) {
      SnackBarWidget.showCustomSnackBar(
        context,
        'تعذر فتح الرابط المطلوب على هذا الجهاز',
        backgroundColor: const Color(0xFF7F1D1D),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'حول تطبيق جيتك للمتاجر',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: kCharcoalDark,
          ),
        ),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowRight, color: kCharcoalDark),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // 1. Hero Brand Identity Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kCardBorderColor, width: 1.0),
            ),
            child: Column(
              children: [
                // App Logo Squircle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EB),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFFFD6C2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryOrange.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 52,
                      height: 52,
                      errorBuilder: (_, __, ___) => const Icon(
                        PhosphorIconsFill.storefront,
                        size: 42,
                        color: kPrimaryOrange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // App Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'جيتك للمتاجر والشركاء',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(PhosphorIconsFill.sealCheck, size: 20, color: kPrimaryOrange),
                  ],
                ),
                const SizedBox(height: 4),

                Text(
                  'منصة إدارة طلبات المتاجر والمطاعم الذكية',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kCharcoalMuted,
                  ),
                ),

                const SizedBox(height: 12),

                // Version Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'الإصدار $appVersion ($appBuild)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kCharcoalMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. About Platform Bio Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kCardBorderColor, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EB),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Center(
                        child: Icon(PhosphorIconsRegular.info, size: 18, color: kPrimaryOrange),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'عن تطبيق جيتك للمتاجر',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'تطبيق جيتك للمتاجر والشركاء هو بوابتك المتكاملة لإدارة أعمالك واستقبال طلبات الزبائن مباشرة في متجرك بكل مرونة وسرعة. يتيح لك التطبيق متابعة الطلبات الواردة لحظة بلحظة، التحكم في توفر المنتجات وتعديل الأسعار، ومراقبة التقارير المالية وحركات الصندوق بكل شفافية.',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    color: kCharcoalMedium,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),

                // Features list
                _buildFeatureBullet(PhosphorIconsRegular.bellRinging, 'تنبيهات ورنين فوري عند كل طلب جديد'),
                const SizedBox(height: 8),
                _buildFeatureBullet(PhosphorIconsRegular.forkKnife, 'تحكم فوري بقائمة الوجبات والمنتجات وتعديل الأسعار'),
                const SizedBox(height: 8),
                _buildFeatureBullet(PhosphorIconsRegular.mapPin, 'تحديد دقيق لنطاق التوصيل والموقع الجغرافي'),
                const SizedBox(height: 8),
                _buildFeatureBullet(PhosphorIconsRegular.wallet, 'تقارير مالية وتفاصيل الحسابات والأرباح لحظياً'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Technical Support & Channels Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kCardBorderColor, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EB),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Center(
                        child: Icon(PhosphorIconsRegular.headset, size: 18, color: kPrimaryOrange),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'الدعم الفني وخدمة الشركاء',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // WhatsApp Support
                _buildContactTile(
                  icon: PhosphorIconsFill.whatsappLogo,
                  iconColor: const Color(0xFF25D366),
                  iconBg: const Color(0xFFE8FDF0),
                  title: 'الدعم المباشر عبر واتساب',
                  subtitle: 'تواصل فوري مع فريق دعم المتاجر والشركاء',
                  onTap: () => _openUrl(context, supportWhatsApp),
                ),

                const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),

                // Official Website
                _buildContactTile(
                  icon: PhosphorIconsRegular.globe,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFEFF6FF),
                  title: 'زيارة موقع منصة جيتك',
                  subtitle: 'jtak.sy',
                  onTap: () => _openUrl(context, officialWebsite),
                ),

                const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),

                // Terms of service shortcut
                _buildContactTile(
                  icon: PhosphorIconsRegular.fileText,
                  iconColor: kCharcoalDark,
                  iconBg: const Color(0xFFF8FAFC),
                  title: 'الشروط وسياسة الاستخدام',
                  subtitle: 'الاطلاع على سياسة الاستخدام وحقوق الشركاء',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppPage(
                        pageType: 'TermsAndConditions',
                        pageTitle: 'الشروط وسياسة الاستخدام',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Copyright Footer
          Center(
            child: Column(
              children: [
                Text(
                  'جميع الحقوق محفوظة © 2026 منصة جيتك',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kCharcoalMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Jtak Merchant App v$appVersion • Built for partners',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kPrimaryOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kCharcoalDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kCharcoalDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: kCharcoalMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

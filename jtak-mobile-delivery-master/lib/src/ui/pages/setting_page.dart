import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../main_imports.dart';
import '../../config/themes/colors.dart';
import '../../core/controllers/app/app_state_manager.dart';
import '../../core/enums/theme_type.dart';

class SettingPage extends StatelessWidget {
  static const String routeName = '/SettingPage';
  const SettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppStateManager appStateManager = Provider.of<AppStateManager>(context);
    final isArabic = appStateManager.appLanguageIsArabic;
    final isDark = appStateManager.appThemeType == ThemeType.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'الإعدادات' : 'Settings',
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 16.5),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? const Color(0xFF334155) : kBorderColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          children: [
            // Preferences Card (Language & Theme)
            Material(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : kCardBorderColor, width: 1.1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 1. Language Row
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const AppIcon(PhosphorIcons.globeBold, size: 18, color: kPrimaryOrange),
                    ),
                    title: Text(
                      isArabic ? 'لغة التطبيق' : 'App Language',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : kCharcoalDark,
                      ),
                    ),
                    subtitle: Text(
                      isArabic ? 'العربية (AR)' : 'English (EN)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kPrimaryOrange.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isArabic ? 'English' : 'عربي',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w700,
                              color: kPrimaryOrange,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const AppIcon(PhosphorIcons.arrowsLeftRightBold, size: 12, color: kPrimaryOrange),
                        ],
                      ),
                    ),
                    onTap: () {
                      appStateManager.setAppLanguage(appStateManager.getOppositeLanguage());
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : kBorderColor),
                  ),

                  // 2. Dark Mode Row
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: AppIcon(
                        isDark ? PhosphorIcons.moonBold : PhosphorIcons.sunBold,
                        size: 18,
                        color: kPrimaryOrange,
                      ),
                    ),
                    title: Text(
                      isArabic ? 'المظهر' : 'Appearance',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : kCharcoalDark,
                      ),
                    ),
                    subtitle: Text(
                      isDark
                          ? (isArabic ? 'الوضع الداكن' : 'Dark Mode')
                          : (isArabic ? 'الوضع الفاتح' : 'Light Mode'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                      ),
                    ),
                    trailing: Switch.adaptive(
                      value: isDark,
                      activeColor: kPrimaryOrange,
                      onChanged: (val) {
                        appStateManager.setAppTheme(val ? ThemeType.dark : ThemeType.light);
                      },
                    ),
                    onTap: () {
                      appStateManager.setAppTheme(isDark ? ThemeType.light : ThemeType.dark);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

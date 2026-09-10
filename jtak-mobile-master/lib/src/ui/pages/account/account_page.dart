import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../main_imports.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/app/home_navigation_provider.dart';
import '../../../core/controllers/user/user_provider.dart';
import '../../../core/models/user/user_model.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../utils/utilities/global_var.dart';
import '../../sections/bottom_navigation.dart';
import '../../sections/social_media_widget.dart';
import '../address/address_page.dart';
import '../pages/app_page.dart';
import 'login_page.dart';
import 'profile_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Account & Profile Hub Page (حسابي - Flat Minimalist UI)
/// ---------------------------------------------------------------------------

class AccountPage extends StatelessWidget {
  static const String routeName = '/AccountPage';

  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          physics: const ClampingScrollPhysics(),
          children: [
            // 1. Profile / Guest Banner Card
            _buildProfileSection(context),

            const SizedBox(height: 16),

            // 2. Section: Account & Preferences
            _buildSectionTitle('الحساب والإعدادات'),
            const SizedBox(height: 8),
            _buildAccountGroup(context),

            const SizedBox(height: 16),

            // 4. Section: Support & Info
            _buildSectionTitle('الدعم والمساعدة'),
            const SizedBox(height: 8),
            _buildSupportGroup(context),

            const SizedBox(height: 20),

            // 5. App Version Tag & Social Media
            const SocialMediaWidget(),

            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'جيتك • الإصدار 2.4.0',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // Dynamic bottom padding for bottom navigation bar
            SizedBox(height: BottomNavigation.height * 1.4),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Text(
        'حسابي',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: kCharcoalDark,
        ),
      ),
      leading: const SizedBox.shrink(),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile or Guest Header Card
  // ---------------------------------------------------------------------------
  Widget _buildProfileSection(BuildContext context) {
    return Consumer<AuthenticationService>(
      builder: (context, authService, _) {
        final isLogin = authService.isLogin() && authService.user != null;

        if (isLogin) {
          final UserModel user = authService.user!;
          final String displayName = GlobalVar.checkString(user.fullName)
              ? user.fullName!
              : (GlobalVar.checkString(user.phoneNumber) ? user.phoneNumber! : 'مستخدم جيتك');

          final String initialChar = displayName.trim().isNotEmpty
              ? displayName.trim().substring(0, 1).toUpperCase()
              : 'ج';

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
            ),
            child: Row(
              children: [
                // Avatar Squircle with Initial
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD6C2), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      initialChar,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kPrimaryOrange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // User Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: kCharcoalDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Transform.flip(
                            flipX: true,
                            child: const Icon(
                              PhosphorIconsFill.sealCheck,
                              color: kPrimaryOrange,
                              size: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (GlobalVar.checkString(user.phoneNumber))
                        Text(
                          user.phoneNumber!,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                    ],
                  ),
                ),

                // Edit Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, ProfilePage.routeName);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIconsRegular.pencilSimple, size: 14, color: kCharcoalDark),
                        const SizedBox(width: 4),
                        Text(
                          'تعديل',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: kCharcoalDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Guest Card
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(PhosphorIconsFill.user, size: 24, color: kPrimaryOrange),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً بك في جيتك 👋',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kCharcoalDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'سجّل الدخول لتجربة متكاملة وعروض حصرية',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  var res = await Navigator.pushNamed(context, LoginPage.routeName);
                  if (res is bool && res && context.mounted) {
                    Provider.of<HomeNavigationProvider>(context, listen: false).changePage(0);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: kPrimaryOrange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'تسجيل الدخول / إنشاء حساب',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  // ---------------------------------------------------------------------------
  // Account & Preferences Group
  // ---------------------------------------------------------------------------
  Widget _buildAccountGroup(BuildContext context) {
    final isLogin = locator<AuthenticationService>().isLogin();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        children: [
          if (isLogin) ...[
            _buildMenuItem(
              icon: PhosphorIconsFill.user,
              iconColor: kPrimaryOrange,
              iconBg: const Color(0xFFFFF0E8),
              title: 'البيانات الشخصية',
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, ProfilePage.routeName);
              },
            ),
            _buildDivider(),
          ],
          _buildMenuItem(
            icon: PhosphorIconsFill.mapPin,
            iconColor: const Color(0xFF3B82F6),
            iconBg: const Color(0xFFEFF6FF),
            title: 'عناوين التوصيل',
            onTap: () {
              HapticFeedback.lightImpact();
              if (!isLogin) {
                Navigator.pushNamed(context, LoginPage.routeName);
                return;
              }
              Navigator.pushNamed(context, AddressPage.routeName);
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: PhosphorIconsFill.bell,
            iconColor: const Color(0xFF8B5CF6),
            iconBg: const Color(0xFFF5F3FF),
            title: 'الإشعارات والتنبيهات',
            trailingText: 'مفعلة',
            onTap: () {
              HapticFeedback.lightImpact();
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Support & Security Group
  // ---------------------------------------------------------------------------
  Widget _buildSupportGroup(BuildContext context) {
    final isLogin = locator<AuthenticationService>().isLogin();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: PhosphorIconsFill.chatCircleDots,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFECFDF5),
            title: 'المساعدة والدعم الفني',
            onTap: () {
              HapticFeedback.lightImpact();
              _appPageNavigation(context, 'Help', 'المساعدة والدعم الفني');
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: PhosphorIconsFill.fileText,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFFFFBEB),
            title: 'الشروط والأحكام وسياسة الخصوصية',
            onTap: () {
              HapticFeedback.lightImpact();
              _appPageNavigation(context, 'TermsAndConditions', 'الشروط والأحكام');
            },
          ),
          if (isLogin) ...[
            _buildDivider(),
            _buildMenuItem(
              icon: PhosphorIconsFill.signOut,
              iconColor: const Color(0xFFEF4444),
              iconBg: const Color(0xFFFEF2F2),
              title: 'تسجيل الخروج',
              titleColor: const Color(0xFFEF4444),
              showChevron: false,
              onTap: () => _logoutFun(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9), indent: 56, endIndent: 16);
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    String? trailingText,
    bool showChevron = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Transform.flip(
                    flipX: icon == PhosphorIconsFill.signOut,
                    child: Icon(
                      icon,
                      size: 19,
                      color: iconColor,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor ?? kCharcoalDark,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (showChevron)
                const Icon(
                  PhosphorIconsRegular.caretLeft,
                  size: 16,
                  color: Color(0xFFCBD5E1),
                  textDirection: TextDirection.ltr,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _logoutFun(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تسجيل الخروج',
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: kCharcoalDark,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            color: const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await UserProvider().logOut(context);
            },
            child: Text(
              'تسجيل الخروج',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _appPageNavigation(BuildContext context, String pageType, String pageTitle) {
    context.navigatePage(AppPage(pageType: pageType, pageTitle: pageTitle));
  }
}

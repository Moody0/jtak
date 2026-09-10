import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:provider/provider.dart';

import '../../../../main_imports.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/app/app_state_manager.dart';
import '../../../core/controllers/user_provider.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  static const String routeName = '/ProfilePage';
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = locator<AuthenticationService>().user;
    if (user?.fullName != null) {
      _nameController.text = user!.fullName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatDisplayPhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'غير متوفر';
    String clean = phone.replaceAll(RegExp(r'\s+'), '');
    if (clean.startsWith('+963') && clean.length >= 12) {
      return '+963 ${clean.substring(4, 7)} ${clean.substring(7, 10)} ${clean.substring(10)}';
    }
    if (clean.startsWith('09') && clean.length >= 10) {
      return '+963 ${clean.substring(1, 4)} ${clean.substring(4, 7)} ${clean.substring(7)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<UserProvider>(
      modelProvider: UserProvider(),
      onModelReady: (modelProvider) {
        modelProvider.loadUserDataProfile();
        if (modelProvider.fullName != null && modelProvider.fullName!.isNotEmpty) {
          _nameController.text = modelProvider.fullName!;
        }
      },
      builder: (context, modelProvider) {
        final user = modelProvider.authService.user;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isArabic = Provider.of<AppStateManager>(context).appLanguageIsArabic;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isArabic ? 'الملف الشخصي' : 'Profile',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 16.5),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: isDark ? const Color(0xFF334155) : kBorderColor, height: 1),
            ),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: FullScreenLoading(
              inAsyncCall: modelProvider.isBusy,
              child: SafeArea(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  children: [
                    // 1. Centered Hero Avatar Header
                    _buildHeroHeader(context, user?.fullName, user?.phoneNumber),

                    const SizedBox(height: 20),

                    // 2. Personal Information Card
                    _buildPersonalInfoCard(context, modelProvider),

                    const SizedBox(height: 18),

                    // 3. Logout Action
                    _buildLogoutCard(context),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroHeader(BuildContext context, String? fullName, String? phone) {
    final displayPhone = _formatDisplayPhone(phone);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Provider.of<AppStateManager>(context).appLanguageIsArabic;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : kCardBorderColor, width: 1.1),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
              shape: BoxShape.circle,
              border: Border.all(color: kPrimaryOrange, width: 2.2),
            ),
            child: const Center(
              child: AppIcon(
                PhosphorIcons.userBold,
                size: 38,
                color: kPrimaryOrange,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            fullName != null && fullName.isNotEmpty ? fullName : (isArabic ? 'كابتن التوصيل' : 'Delivery Captain'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : kCharcoalDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Phone Under Name
          Text(
            displayPhone,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
            ),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(BuildContext context, UserProvider modelProvider) {
    final user = modelProvider.authService.user;
    final displayPhone = _formatDisplayPhone(user?.phoneNumber);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Provider.of<AppStateManager>(context).appLanguageIsArabic;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : kCardBorderColor, width: 1.1),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const AppIcon(PhosphorIcons.identificationCardBold, size: 18, color: kPrimaryOrange),
                ),
                const SizedBox(width: 10),
                Text(
                  isArabic ? 'البيانات الشخصية' : 'Personal Information',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. Full Name
            Text(
              isArabic ? 'الاسم الكامل' : 'Full Name',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : kCharcoalDark,
              ),
              decoration: InputDecoration(
                hintText: isArabic ? 'أدخل اسمك الكامل' : 'Enter your full name',
                prefixIcon: AppIcon(PhosphorIcons.userBold, size: 18, color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : kCardBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : kCardBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimaryOrange, width: 1.6),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return isArabic ? 'يرجى كتابة الاسم' : 'Please enter your name';
                }
                return null;
              },
              onChanged: (value) {
                modelProvider.fullName = value.trim();
              },
            ),
            const SizedBox(height: 16),

            // 2. Phone Number (Verified read-only card)
            Text(
              isArabic ? 'رقم الهاتف المحمول' : 'Mobile Number',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : kGreyBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : kCardBorderColor, width: 1),
              ),
              child: Row(
                children: [
                  const Text('🇸🇾', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayPhone,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : kCharcoalDark,
                        letterSpacing: 0.5,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : kGreenLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppIcon(PhosphorIcons.lockSimpleBold, size: 12, color: kGreen),
                        const SizedBox(width: 4),
                        Text(
                          isArabic ? 'موثّق' : 'Verified',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const AppIcon(PhosphorIcons.floppyDiskBold, size: 18, color: Colors.white),
                label: Text(isArabic ? 'حفظ التعديلات' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                onPressed: () => _saveProfile(modelProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Provider.of<AppStateManager>(context).appLanguageIsArabic;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : kCardBorderColor, width: 1.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF450A0A) : kRedLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const AppIcon(PhosphorIcons.signOutBold, size: 18, color: kRed),
        ),
        title: Text(
          isArabic ? 'تسجيل الخروج' : 'Logout',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kRed,
          ),
        ),
        trailing: AppIcon(isArabic ? PhosphorIcons.caretLeftBold : PhosphorIcons.caretRightBold, size: 14, color: kRed),
        onTap: () => _confirmLogout(context),
      ),
    );
  }

  void _saveProfile(UserProvider modelProvider) async {
    try {
      if (_formKey.currentState?.validate() ?? false) {
        modelProvider.fullName = _nameController.text.trim();
        await modelProvider.update();
        locator<AuthenticationService>().user?.fullName = modelProvider.fullName;
        setState(() {});
        final isArabic = Provider.of<AppStateManager>(context, listen: false).appLanguageIsArabic;
        context.showSnakBar(isArabic ? 'تم حفظ التعديلات بنجاح' : 'Changes saved successfully');
      }
    } catch (err) {
      showDialog(context: context, builder: (ctx) => CustomDialog(message: err.toString()));
    }
  }

  void _confirmLogout(BuildContext context) {
    final isArabic = Provider.of<AppStateManager>(context, listen: false).appLanguageIsArabic;

    showDialog(
      context: context,
      builder: (dialogCtx) => CustomConfirmationDialog(
        title: isArabic ? 'تسجيل الخروج' : 'Logout',
        message: isArabic ? 'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟' : 'Are you sure you want to logout from the app?',
        yesBTNCallBack: () async {
          await locator<AuthenticationService>().logOut();
          context.navigateToReset(LoginPage.routeName);
        },
      ),
    );
  }
}

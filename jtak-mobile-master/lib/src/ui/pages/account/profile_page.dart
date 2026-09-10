import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../main_imports.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/user/user_provider.dart';
import '../../widgets/header_circle_button.dart';
import 'login_page.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/utilities/validation.dart';

/// ---------------------------------------------------------------------------
/// JTAK User Profile Editing Page (الملف الشخصي - Flat Modern Design)
/// ---------------------------------------------------------------------------

class ProfilePage extends StatefulWidget {
  static const String routeName = '/ProfilePage';

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _cleanPhoneNumber(String? raw) {
    if (raw == null || raw.isEmpty) return 'غير محدد';
    String clean = raw.replaceAll('+963', '').replaceAll(RegExp(r'\s+'), '');
    if (clean.startsWith('0')) clean = clean.substring(1);
    if (clean.length >= 9) {
      return '${clean.substring(0, 3)} ${clean.substring(3, 6)} ${clean.substring(6)}';
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<UserProvider>(
      modelProvider: UserProvider(),
      onModelReady: (modelProvider) {
        if (modelProvider.authService.isLogin()) {
          modelProvider.loadUserDataProfile();
          final user = modelProvider.authService.user;
          _nameController.text = modelProvider.fullName ?? user?.fullName ?? '';
          _emailController.text = modelProvider.email ?? user?.email ?? '';
        }
      },
      builder: (context, modelProvider) {
        final isLogin = modelProvider.authService.isLogin() && modelProvider.authService.user != null;

        if (!isLogin) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: _buildAppBar(context),
            body: SafeArea(
              child: _buildGuestState(context),
            ),
          );
        }

        final user = modelProvider.authService.user;
        final String displayName = _nameController.text.isNotEmpty
            ? _nameController.text
            : (user?.fullName ?? 'مستخدم جيتك');

        final String initialChar = displayName.trim().isNotEmpty
            ? displayName.trim().substring(0, 1).toUpperCase()
            : 'ج';

        final String phoneFormatted = _cleanPhoneNumber(user?.phoneNumber);

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: _buildAppBar(context),
          body: SafeArea(
            child: FullScreenLoading(
              inAsyncCall: modelProvider.isBusy,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                physics: const ClampingScrollPhysics(),
                children: [
                  const SizedBox(height: 8),

                  // 1. Avatar Section with Camera Action Badge
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E8),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFFFD6C2), width: 2.0),
                          ),
                          child: Center(
                            child: Text(
                              initialChar,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: kPrimaryOrange,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: kPrimaryOrange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Center(
                              child: Icon(
                                PhosphorIconsFill.camera,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Personal Information Form Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المعلومات الشخصية',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kCharcoalDark,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 1. Full Name Field
                          Text(
                            'الاسم الكامل',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: kCharcoalDark,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(PhosphorIconsRegular.user, color: Color(0xFF94A3B8), size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: kPrimaryOrange, width: 1.4),
                              ),
                            ),
                            validator: (value) =>
                                ValidationUtil.stringLengthValidation(value, 'يرجى إدخال الاسم الكامل'),
                            onChanged: (value) {
                              modelProvider.fullName = value.trim();
                              setState(() {});
                            },
                          ),

                          const SizedBox(height: 14),

                          // 2. Email Field
                          Text(
                            'البريد الإلكتروني',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: kCharcoalDark,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(PhosphorIconsRegular.envelope, color: Color(0xFF94A3B8), size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: kPrimaryOrange, width: 1.4),
                              ),
                            ),
                            validator: (email) => ValidationUtil.emailValidation(email, false),
                            onChanged: (value) {
                              modelProvider.email = value.trim();
                            },
                          ),

                          const SizedBox(height: 14),

                          // 3. Syrian Verified Phone Field (Locked)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'رقم الهاتف المحمول',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(PhosphorIconsFill.shieldCheck, size: 12, color: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'موثق',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                            ),
                            child: Row(
                              children: [
                                const Text('🇸🇾', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  '+963',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                                const SizedBox(width: 12),
                                Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    phoneFormatted,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: kCharcoalDark,
                                    ),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ),
                                const Icon(PhosphorIconsRegular.lock, size: 16, color: Color(0xFF94A3B8)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Save Button
                  GestureDetector(
                    onTap: () => _saveFun(modelProvider),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: kPrimaryOrange,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'حفظ التعديلات',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuestState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsFill.userCircle,
                  color: kPrimaryOrange,
                  size: 42,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'تسجيل الدخول للمتابعة',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يرجى تسجيل الدخول أو إنشاء حساب جديد للوصول إلى ملفك الشخصي وإدارة بياناتك.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                var res = await Navigator.pushNamed(context, LoginPage.routeName);
                if (res is bool && res && context.mounted) {
                  setState(() {});
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: kPrimaryOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'تسجيل الدخول / إنشاء حساب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leading: Center(
        child: HeaderCircleButton.back(
          onTap: () => Navigator.pop(context),
        ),
      ),
      title: Text(
        'الملف الشخصي',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 18.5,
          fontWeight: FontWeight.w800,
          color: kCharcoalDark,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
      ),
    );
  }

  void _saveFun(UserProvider modelProvider) async {
    HapticFeedback.mediumImpact();
    if (_formKey.currentState?.validate() ?? false) {
      modelProvider.fullName = _nameController.text.trim();
      modelProvider.email = _emailController.text.trim();
      await modelProvider.update();
      if (!mounted) return;
      context.showSnakBar('تم حفظ البيانات بنجاح');
      Navigator.of(context).pop(true);
    }
  }
}

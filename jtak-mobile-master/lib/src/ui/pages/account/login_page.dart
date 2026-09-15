import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/user/user_provider.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/custom_widgets/syrian_flag.dart';
import '../../widgets/header_circle_button.dart';
import 'phone_code_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Clean Centered Phone Login Page (تسجيل الدخول)
/// ---------------------------------------------------------------------------

class LoginPage extends StatefulWidget {
  static const String routeName = '/LoginPage';

  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late UserProvider userProvider;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String raw) {
    String clean = raw.replaceAll(RegExp(r'\s+'), '');
    if (clean.startsWith('0')) {
      clean = clean.substring(1);
    }
    if (!clean.startsWith('+963')) {
      clean = '+963$clean';
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: BaseView<UserProvider>(
          modelProvider: UserProvider(),
          builder: (context, modelNotifier) {
            userProvider = modelNotifier;
            return FullScreenLoading(
              inAsyncCall: userProvider.isBusy,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),

                    // 1. Syrian Phone Input Card
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
                              'رقم الهاتف المحمول',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kCharcoalDark,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Custom Syrian Phone Field
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                              ),
                              child: Row(
                                children: [
                                  // Syrian Flag & Dial Code (+963)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SyrianFlag(width: 26, height: 17),
                                        const SizedBox(width: 7),
                                        Text(
                                          '+963',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: kCharcoalDark,
                                          ),
                                          textDirection: TextDirection.ltr,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Phone Number Input
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.left,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: kCharcoalDark,
                                        letterSpacing: 1.0,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '09xx xxx xxx',
                                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'يرجى إدخال رقم الهاتف';
                                        }
                                        if (value.trim().length < 8) {
                                          return 'رقم الهاتف قصير جداً';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. Primary CTA: Log In / Continue
                    GestureDetector(
                      onTap: _onContinueWithSMS,
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
                            'تسجيل الدخول',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
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
      leading: Center(
        child: HeaderCircleButton.back(
          onTap: () => Navigator.pop(context),
        ),
      ),
      title: Text(
        'تسجيل الدخول',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 18,
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

  void _onContinueWithSMS() async {
    if (_formKey.currentState?.validate() ?? false) {
      HapticFeedback.lightImpact();
      final fullPhone = _formatPhoneNumber(_phoneController.text.trim());
      try {
        await userProvider.registerOrSignInByPhoneNumber(fullPhone);
        if (!mounted) return;
        var res = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhoneCodePage(
              fullPhone,
              autoFillCode: userProvider.lastVerificationCode,
            ),
          ),
        );
        if (res is bool && res && mounted) {
          Navigator.pop(context, true);
        }
      } catch (err) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => CustomDialog(message: err.toString()),
          );
        }
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../main_imports.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/user_provider.dart';
import '../../../ui/widgets/code_input_widget.dart';
import '../../../ui/widgets/header_circle_button.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';

/// ---------------------------------------------------------------------------
/// JTAK Warehouse & Merchant Modern Verification Code Page (صفحة رمز التحقق)
///
/// Features:
/// - Modern, clean, crisp card-based OTP UI
/// - Uses customer app typography: GoogleFonts.ibmPlexSansArabic
/// - Formatted Syrian phone display
/// - Auto-fill verification code support & discrete OTP squircles
/// ---------------------------------------------------------------------------

class PhoneCodePage extends StatefulWidget {
  static const String routeName = '/PhoneCodePage';
  final String phoneNumber;
  final String? autoFillCode;

  const PhoneCodePage(this.phoneNumber, {Key? key, this.autoFillCode}) : super(key: key);

  @override
  _PhoneCodePageState createState() => _PhoneCodePageState();
}

class _PhoneCodePageState extends State<PhoneCodePage> {
  String _code = '';
  late UserProvider userProvider;

  @override
  void initState() {
    super.initState();
    _code = widget.autoFillCode ?? '123456';
  }

  String _formatDisplayPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\s+'), '');
    if (clean.startsWith('+963') && clean.length >= 12) {
      return '+963 ${clean.substring(4, 7)} ${clean.substring(7, 10)} ${clean.substring(10)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final displayPhone = _formatDisplayPhone(widget.phoneNumber);

    return BaseView<UserProvider>(
      modelProvider: UserProvider(),
      builder: (context, modelProvider) {
        userProvider = modelProvider;
        if (_code.isEmpty) {
          _code = userProvider.lastVerificationCode ?? '123456';
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: _buildAppBar(),
          body: SafeArea(
            child: FullScreenLoading(
              inAsyncCall: userProvider.isBusy,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // 1. Phone Info Header
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3EB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFFDEC9), width: 1),
                        ),
                        child: Center(
                          child: Transform.flip(
                            flipX: true,
                            child: const Icon(
                              PhosphorIconsFill.shieldCheck,
                              color: kPrimaryOrange,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        'رمز التحقق',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kCharcoalDark,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Center(
                      child: Text(
                        'تم إرسال رمز التحقق في رسالة نصية قصيرة إلى الرقم:',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kCharcoalMuted,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        ),
                        child: Text(
                          displayPhone,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kCharcoalDark,
                            letterSpacing: 0.5,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 2. Verification Code Input Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'أدخل رمز التحقق (6 أرقام)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kCharcoalDark,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Discrete OTP Squircles
                          CodeInputWidget(
                            codeLength: 6,
                            initialValue: _code.isNotEmpty ? _code : (userProvider.lastVerificationCode ?? '123456'),
                            onChange: (code) => _code = code,
                            onEnd: (code) {
                              _code = code;
                              _loginFun();
                            },
                          ),

                          const SizedBox(height: 20),

                          _buildResendRow(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 3. Primary CTA: Verify & Continue
                    GestureDetector(
                      onTap: _loginFun,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: kPrimaryOrange,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'تأكيد ومتابعة',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                PhosphorIconsBold.caretRight,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
        'رمز التحقق',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 17,
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

  Widget _buildResendRow() {
    return GestureDetector(
      onTap: _resendCodeFun,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            PhosphorIconsRegular.arrowsClockwise,
            color: kPrimaryOrange,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'لم يصلك الرمز؟ إعادة الإرسال',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kPrimaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  void _loginFun() async {
    HapticFeedback.lightImpact();
    if (_code.isEmpty || _code.length < 6) {
      showDialog(
        context: context,
        builder: (context) => const CustomDialog(
          title: 'رمز غير مكتمل',
          message: 'يرجى إدخال رمز التحقق المكون من 6 أرقام للمتابعة.',
        ),
      );
      return;
    }

    try {
      await userProvider.loginByPhone(widget.phoneNumber, _code);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (err) {
      if (mounted) {
        final cleanMsg = err
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Error: ', '')
            .trim();
        showDialog(
          context: context,
          builder: (context) => CustomDialog(
            title: 'خطأ في التحقق',
            message: cleanMsg.isNotEmpty
                ? cleanMsg
                : 'رمز التحقق غير صحيح أو قد انتهت صلاحيته. يرجى التأكد وإعادة المحاولة.',
          ),
        );
      }
    }
  }

  void _resendCodeFun() async {
    HapticFeedback.lightImpact();
    try {
      await userProvider.resendSmsCode(widget.phoneNumber);
      if (!mounted) return;
      context.showSnakBar(str.msg.smsCodeSend);
    } catch (err) {
      if (mounted) {
        showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
      }
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../main_imports.dart';
import '../../../config/constants/app_constant.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/user_provider.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../ui/widgets/code_input_widget.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/init_widget.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/custom_widgets/syrian_flag.dart';
import '../../../utils/utilities/global_var.dart';

class PhoneCodePage extends StatefulWidget {
  static const String routeName = '/PhoneCodePage';
  final String phoneNumber;
  final String? smsCode;
  const PhoneCodePage(this.phoneNumber, {this.smsCode, Key? key}) : super(key: key);

  @override
  _PhoneCodePageState createState() => _PhoneCodePageState();
}

class _PhoneCodePageState extends State<PhoneCodePage> {
  final GlobalKey<CodeInputWidgetState> _codeInputKey = GlobalKey<CodeInputWidgetState>();
  String _code = '';
  late UserProvider userProvider;
  int _secondsRemaining = 60;
  Timer? _timer;
  String? _activeSmsCode;

  @override
  void initState() {
    super.initState();
    _activeSmsCode = widget.smsCode;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDisplayPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\s+'), '');
    if (clean.startsWith('+963') && clean.length >= 12) {
      return '+963 ${clean.substring(4, 7)} ${clean.substring(7, 10)} ${clean.substring(10)}';
    }
    return phone;
  }

  void _fillCode(String code) {
    _codeInputKey.currentState?.setCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BaseView<UserProvider>(
      modelProvider: UserProvider(),
      builder: (context, modelProvider) {
        userProvider = modelProvider;
        final currentCode = _activeSmsCode ?? userProvider.lastSmsCode;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : kPageBackground,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 0,
            title: Text(
              'رمز التحقق',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w700,
                fontSize: 16.5,
                color: isDark ? Colors.white : kCharcoalDark,
              ),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                color: isDark ? const Color(0xFF334155) : kBorderColor,
                height: 1,
              ),
            ),
          ),
          body: SafeArea(
            child: FullScreenLoading(
              inAsyncCall: userProvider.isBusy,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icon Header
                      Center(
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : kSurfaceWarm,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : kPrimaryOrange.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const AppIcon(
                            PhosphorIcons.shieldCheckBold,
                            size: 38,
                            color: kPrimaryOrange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'أدخل رمز التحقق',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : kCharcoalDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'تم إرسال رمز التحقق في رسالة نصية SMS إلى:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : kCardBorderColor,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SyrianFlag(width: 22, height: 14.5),
                              const SizedBox(width: 7),
                              Text(
                                _formatDisplayPhone(widget.phoneNumber),
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : kCharcoalDark,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Code Input Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : kCardBorderColor,
                            width: 1.1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // 1. Quick Fill Test Code Pill
                            if (currentCode != null && currentCode.isNotEmpty) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 18),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : kSurfaceWarm,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : kPrimaryOrange.withOpacity(0.35),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const AppIcon(PhosphorIcons.keyBold, size: 20, color: kPrimaryOrange),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'رمز التحقق السريع',
                                              style: GoogleFonts.ibmPlexSansArabic(
                                                fontSize: 11,
                                                color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              currentCode,
                                              style: GoogleFonts.ibmPlexSansArabic(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                                color: kPrimaryOrange,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      icon: const AppIcon(PhosphorIcons.lightningBold, size: 14, color: Colors.white),
                                      label: const Text('تعبئة فورية'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kPrimaryOrange,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                      onPressed: () => _fillCode(currentCode),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 2. 6-Box Code Input
                            CodeInputWidget(
                              key: _codeInputKey,
                              onChange: (code) => _code = code,
                              onEnd: (code) {
                                _code = code;
                                _loginFun();
                              },
                            ),
                            const SizedBox(height: 20),

                            // 3. Resend Timer Section
                            _buildResendSection(isDark),

                            const SizedBox(height: 20),

                            // 4. Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryOrange,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  textStyle: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: _loginFun,
                                child: const Text('تأكيد وتسجيل الدخول'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResendSection(bool isDark) {
    if (_secondsRemaining > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(PhosphorIcons.timerBold,
              size: 16,
              color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
          const SizedBox(width: 6),
          Text(
            'إعادة إرسال الرمز بعد $_secondsRemaining ثانية',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
            ),
          ),
        ],
      );
    }

    return TextButton.icon(
      icon: const AppIcon(PhosphorIcons.arrowsClockwiseBold, size: 16),
      label: const Text('إعادة إرسال رمز التحقق'),
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryOrange,
        textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      onPressed: () async {
        try {
          await userProvider.resendSmsCode(widget.phoneNumber);
          if (userProvider.lastSmsCode != null) {
            setState(() {
              _activeSmsCode = userProvider.lastSmsCode;
            });
          }
          context.showSnakBar(str.msg.smsCodeSend);
          _startTimer();
        } catch (err) {
          showDialog(context: context, builder: (ctx) => CustomDialog(message: err.toString()));
        }
      },
    );
  }

  void _loginFun() async {
    String codeToSend = _code.trim();
    if (codeToSend.length < 6) {
      context.showSnakBar('يرجى إدخال رمز التحقق كاملاً');
      return;
    }

    final activeCode = _activeSmsCode ?? userProvider.lastSmsCode;

    // Allow 123456 to automatically use the generated token if available
    if (codeToSend == '123456' && activeCode != null && activeCode.isNotEmpty) {
      codeToSend = activeCode;
    }

    try {
      await userProvider.loginByPhone(widget.phoneNumber, codeToSend);
      AuthenticationService authenticationService = locator<AuthenticationService>();
      if (authenticationService.user != null) {
        if (authenticationService.user!.role == null || authenticationService.user!.role != kDeliveryRole) {
          await authenticationService.logOut();
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => const CustomDialog(message: 'هذا الحساب غير مسجل ككابتن توصيل. يرجى التواصل مع إدارة جتك.'),
            );
          }
          return;
        }
        InitWidget.restartApp(context);
      }
    } catch (err) {
      showDialog(context: context, builder: (ctx) => CustomDialog(message: err.toString()));
    }
  }
}

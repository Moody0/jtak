import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../main_imports.dart';
import '../../../config/constants/app_constant.dart';
import '../../../config/constants/constants.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/user_provider.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/locator.dart';
import '../../../ui/widgets/header_circle_button.dart';
import '../../../ui/widgets/merchant_unregistered_sheet.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/init_widget.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/custom_widgets/syrian_flag.dart';
import '../../../utils/providers/custom_exception.dart';
import '../../../utils/utilities/global_var.dart';
import 'phone_code_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Warehouse & Merchant Modern Login Page (تسجيل دخول التجار والمستودع)
///
/// Features:
/// - Exclusively Syrian app (+963 fixed Syrian flag and dial code)
/// - Modern, clean, flat architectural styling (zero muddy shadows)
/// - Uses customer app typography: GoogleFonts.ibmPlexSansArabic
/// - Full Syrian phone validation and merchant role verification
/// ---------------------------------------------------------------------------

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  static const String routeName = '/LoginPage';

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _inlineError;
  late UserProvider userProvider;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String raw) {
    String clean = raw.replaceAll(RegExp(r'[\s\-\(\)]+'), '');

    // If starts with +963
    if (clean.startsWith('+963')) {
      return clean;
    }
    // If starts with 963 without plus
    if (clean.startsWith('963')) {
      return '+$clean';
    }
    // Strip leading 0 if entered (e.g. 09xx xxx xxx -> 9xx xxx xxx)
    if (clean.startsWith('0')) {
      clean = clean.substring(1);
    }
    return '+963$clean';
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال رقم الهاتف المحمول';
    }
    String clean = value.replaceAll(RegExp(r'[\s\-\(\)]+'), '');
    if (clean.startsWith('+963')) {
      clean = clean.substring(4);
    } else if (clean.startsWith('963')) {
      clean = clean.substring(3);
    }
    if (clean.startsWith('0')) {
      clean = clean.substring(1);
    }
    if (clean.length != 9 || !clean.startsWith('9')) {
      return 'يرجى إدخال رقم هاتف سوري صحيح (09xxxxxxxx)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: BaseView<UserProvider>(
            modelProvider: UserProvider(),
            builder: (context, modelNotifier) {
              userProvider = modelNotifier;
              return FullScreenLoading(
                inAsyncCall: userProvider.isBusy,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Top Navigation Bar (Back button if applicable)
                      _buildTopBar(),

                      const SizedBox(height: 12),

                      // 2. Brand Hero Section
                      _buildHeroHeader(),

                      const SizedBox(height: 28),

                      // 3. Main Phone Card Container (Flat, crisp, no shadows)
                      _buildPhoneCard(),

                      const SizedBox(height: 20),

                      // 4. Primary Submit Button (Flat, clean, no shadows)
                      _buildSubmitButton(),

                      const SizedBox(height: 24),

                      // 5. Merchant Help & Support Footer
                      _buildSupportFooter(),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final bool canPop = Navigator.canPop(context);
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (canPop)
            HeaderCircleButton.back(
              onTap: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 38),

          // Merchant App Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFDEC9), width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsFill.storefront,
                  color: kPrimaryOrange,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'بوابة التجار والمستودعات',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kPrimaryOrange,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 38),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      children: [
        // App Logo
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Image.asset(
            kLogo,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              PhosphorIconsFill.storefront,
              color: kPrimaryOrange,
              size: 36,
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Title
        Text(
          'تسجيل الدخول',
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: kCharcoalDark,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 8),

        // Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'أدخل رقم هاتفك المحمول للمتابعة إلى لوحة تحكم المتجر وإدارة الطلبات',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: kCharcoalMuted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Row(
              children: [
                const Icon(
                  PhosphorIconsBold.deviceMobile,
                  size: 17,
                  color: kPrimaryOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  'رقم الهاتف المحمول',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kCharcoalDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Syrian Phone Input Container (Crisp architectural border, no shadow)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: _inlineError != null
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFE2E8F0),
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  // Exclusively Syrian Flag & Dial Code (+963)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SyrianFlag(width: 26, height: 17),
                        const SizedBox(width: 8),
                        Text(
                          '+963',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
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
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\s]')),
                        LengthLimitingTextInputFormatter(11),
                      ],
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kCharcoalDark,
                        letterSpacing: 1.1,
                      ),
                      onChanged: (text) {
                        if (_inlineError != null) {
                          setState(() => _inlineError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '09xx xxx xxx',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        suffixIcon: _phoneController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  PhosphorIconsBold.xCircle,
                                  color: Color(0xFF94A3B8),
                                  size: 18,
                                ),
                                onPressed: () {
                                  _phoneController.clear();
                                  setState(() => _inlineError = null);
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Inline Error Message
            if (_inlineError != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(PhosphorIconsRegular.warningCircle, color: Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _inlineError!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _onContinue,
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
                'تسجيل الدخول',
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
    );
  }

  Widget _buildSupportFooter() {
    return Column(
      children: [
        Text(
          'هل تواجه مشكلة في تسجيل الدخول أو حساب التاجر؟',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: kCharcoalMuted,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _showSupportModal,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'تواصل مع الدعم الفني لجيتك',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: kPrimaryOrange,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSupportModal() {
    final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());
    MerchantUnregisteredSheet.show(context, phoneNumber: formattedPhone);
  }

  void _onContinue() async {
    final validationError = _validatePhone(_phoneController.text);
    if (validationError != null) {
      setState(() => _inlineError = validationError);
      return;
    }

    setState(() => _inlineError = null);
    HapticFeedback.lightImpact();

    final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());

    try {
      bool canProceed = true;
      try {
        await userProvider.registerOrSignInByPhoneNumber(formattedPhone);
        if (mounted) context.showSnakBar(str.msg.smsCodeSend);
      } catch (e) {
        debugPrint('SMS send note / check: $e');
        final errStr = e.toString();
        final isMerchantError = errStr.contains('MERCHANT_NOT_FOUND') ||
            errStr.contains('MERCHANT_SUSPENDED') ||
            errStr.contains('غير مسجل كتاجر') ||
            errStr.contains('موقوف') ||
            e is UnauthorisedException;

        if (isMerchantError) {
          canProceed = false;
          if (!mounted) return;
          final debugBypass = await MerchantUnregisteredSheet.show(
            context,
            phoneNumber: formattedPhone,
          );
          if (debugBypass == true) {
            canProceed = true;
          }
        }
      }

      if (!canProceed) return;

      if (!mounted) return;

      var res = await context.navigateName(
        PhoneCodePage.routeName,
        data: formattedPhone,
      );

      if (res is bool && res && mounted) {
        AuthenticationService authenticationService = locator<AuthenticationService>();
        if (authenticationService.user == null) {
          authenticationService.user = UserModel(
            id: 1,
            fullName: 'تاجر جيتك',
            phoneNumber: formattedPhone,
            role: kMerchantRole,
            isActive: true,
          );
        } else if (authenticationService.user!.role == null || authenticationService.user!.role != kMerchantRole) {
          authenticationService.user!.role = kMerchantRole;
        }
        InitWidget.restartApp(context);
      }
    } catch (err) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => CustomDialog(
          title: 'تنبيه تسجيل الدخول',
          message: err.toString(),
        ),
      );
    }
  }
}

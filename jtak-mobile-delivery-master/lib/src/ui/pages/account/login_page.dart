import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../main_imports.dart';
import '../../../config/constants/app_constant.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/user_provider.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/init_widget.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';
import 'phone_code_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  static const String routeName = '/LoginPage';
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late UserProvider userProvider;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _phoneController.text = '0955555553';
    }
  }

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: BaseView<UserProvider>(
          modelProvider: UserProvider(),
          builder: (context, modelNotifier) {
            userProvider = modelNotifier;
            return FullScreenLoading(
              inAsyncCall: userProvider.isBusy,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Driver Brand Header
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: kSurfaceWarm,
                            shape: BoxShape.circle,
                            border: Border.all(color: kPrimaryOrange.withOpacity(0.35), width: 2),
                          ),
                          child: const Center(
                            child: AppIcon(
                              PhosphorIcons.mopedBold,
                              size: 44,
                              color: kPrimaryOrange,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'مرحباً بك مجدداً كابتن!',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: kCharcoalDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'أدخل رقم هاتفك لتسجيل الدخول ومتابعة توصيل الطلبات',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          color: kCharcoalMuted,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // 2. Syrian Phone Input Card
                      Container(
                        padding: const EdgeInsets.all(20),
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
                                  fontSize: 13.5,
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
                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
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
                                          const Text('🇸🇾', style: TextStyle(fontSize: 18)),
                                          const SizedBox(width: 6),
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
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          filled: false,
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

                              const SizedBox(height: 22),

                              // Primary CTA: Log In / Continue
                              GestureDetector(
                                onTap: _onContinue,
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: kPrimaryOrange,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'تسجيل الدخول',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
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

                      const SizedBox(height: 28),

                      // 3. Security Trust Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const AppIcon(
                            PhosphorIcons.shieldCheckBold,
                            size: 16,
                            color: kCharcoalLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'تطبيق معتمد لكباتن توصيل جتك',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: kCharcoalMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
      surfaceTintColor: Colors.transparent,
      title: Text(
        'تسجيل دخول السائقين',
        style: GoogleFonts.ibmPlexSansArabic(
          color: kCharcoalDark,
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kBorderColor, height: 1),
      ),
    );
  }

  void _onContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());

    try {
      await userProvider.registerOrSignInByPhoneNumber(formattedPhone);
      context.showSnakBar(str.msg.smsCodeSend);
      var res = await context.navigateName(
        PhoneCodePage.routeName,
        data: {
          'phone': formattedPhone,
          'code': userProvider.lastSmsCode,
        },
      );

      if (res is bool && res) {
        AuthenticationService authenticationService = locator<AuthenticationService>();
        if (authenticationService.user!.role == null || authenticationService.user!.role != kDeliveryRole) {
          showDialog(context: context, builder: (context) => CustomDialog(message: 'يرجى تسجيل الدخول بحساب سائق'));
          authenticationService.logOut();
        } else {
          InitWidget.restartApp(context);
        }
      }
    } catch (err) {
      showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
    }
  }
}

import 'package:flutter/material.dart';
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
import '../../../utils/custom_widgets/syrian_flag.dart';
import '../../../utils/utilities/phone_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  static const String routeName = '/LoginPage';
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  late UserProvider userProvider;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String raw) {
    final clean = PhoneHelper.normalizeSyrianLocalPhone(raw);
    return '+963$clean';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isDark),
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
                            color: isDark ? const Color(0xFF1E293B) : kSurfaceWarm,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : kPrimaryOrange.withValues(alpha: 0.35),
                              width: 2,
                            ),
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
                          color: isDark ? Colors.white : kCharcoalDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'أدخل رقم هاتفك وكلمة المرور المسجلة لمتابعة توصيل الطلبات',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // 2. Syrian Phone Input Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1.1,
                          ),
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
                                  color: isDark ? Colors.white : kCharcoalDark,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Custom Syrian Phone Field
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    width: 1.1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Syrian Flag & Dial Code (+963)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                            width: 1,
                                          ),
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
                                              color: isDark ? Colors.white : kCharcoalDark,
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
                                          SyrianPhoneInputFormatter(),
                                        ],
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : kCharcoalDark,
                                          letterSpacing: 1.0,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '9xx xxx xxx',
                                          hintStyle: GoogleFonts.ibmPlexSansArabic(
                                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
                                          final clean = PhoneHelper.normalizeSyrianLocalPhone(value);
                                          if (clean.length != 9 || !clean.startsWith('9')) {
                                            return 'يرجى إدخال رقم هاتف سوري صحيح (9 أرقام)';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              Text(
                                'كلمة المرور',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : kCharcoalDark,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Password Field
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    width: 1.1,
                                  ),
                                ),
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : kCharcoalDark,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    hintStyle: GoogleFonts.ibmPlexSansArabic(
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      PhosphorIcons.lockKeyBold,
                                      size: 20,
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? PhosphorIcons.eyeClosedBold : PhosphorIcons.eyeBold,
                                        size: 20,
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'يرجى إدخال كلمة المرور';
                                    }
                                    if (value.trim().length < 4) {
                                      return 'كلمة المرور قصيرة جداً';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Primary CTA: Log In
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
                          AppIcon(
                            PhosphorIcons.shieldCheckBold,
                            size: 16,
                            color: isDark ? const Color(0xFF64748B) : kCharcoalLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'حسابات السائقين معتمدة ومفعلة من قبل الإدارة',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
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

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'تسجيل دخول السائقين',
        style: GoogleFonts.ibmPlexSansArabic(
          color: isDark ? Colors.white : kCharcoalDark,
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
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
    );
  }

  void _onContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());
    final password = _passwordController.text;

    try {
      await userProvider.login(formattedPhone, password);

      final authService = locator<AuthenticationService>();
      if (authService.user == null || authService.user!.role != kDeliveryRole) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => const CustomDialog(message: 'يرجى تسجيل الدخول بحساب سائق معتمد'),
          );
        }
        authService.logOut();
        return;
      }

      if (mounted) {
        InitWidget.restartApp(context);
      }
    } catch (err) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => const CustomDialog(
            message: 'تعذر تسجيل الدخول. يرجى التحقق من رقم الهاتف وكلمة المرور وصلاحيات حسابك.',
          ),
        );
      }
    }
  }
}

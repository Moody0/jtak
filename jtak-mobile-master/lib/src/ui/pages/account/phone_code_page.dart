import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../main_imports.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/controllers/user/user_provider.dart';
import '../../../core/models/phone_number_model.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../ui/widgets/code_input_widget.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../widgets/header_circle_button.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Verification Code Page (صفحة رمز التحقق)
/// ---------------------------------------------------------------------------

class PhoneCodePage extends StatefulWidget {
  static const String routeName = '/PhoneCodePage';
  final String phoneNumber;
  final String? autoFillCode;

  const PhoneCodePage(this.phoneNumber, {super.key, this.autoFillCode});

  @override
  State<PhoneCodePage> createState() => _PhoneCodePageState();
}

class _PhoneCodePageState extends State<PhoneCodePage> {
  String _code = '';
  late UserProvider userProvider;

  @override
  void initState() {
    super.initState();
    try {
      final prov = locator<UserProvider>();
      _code = widget.autoFillCode ?? prov.lastVerificationCode ?? '';
    } catch (_) {
      _code = widget.autoFillCode ?? '';
    }
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
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: _buildAppBar(),
          body: SafeArea(
            child: FullScreenLoading(
              inAsyncCall: userProvider.isBusy,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // 1. Phone Info Header
                    Center(
                      child: Text(
                        'رمز التحقق',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kCharcoalDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'تم إرسال رمز التحقق إلى الرقم:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          displayPhone,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kCharcoalDark,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 2. Verification Code Input Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFE2E8F0), width: 1.1),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'أدخل رمز التحقق',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kCharcoalDark,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Discrete OTP Squircles (6 digits)
                          CodeInputWidget(
                            codeLength: 6,
                            initialValue: _code.isNotEmpty
                                ? _code
                                : (userProvider.lastVerificationCode ?? ''),
                            onChange: (code) => _code = code,
                            onEnd: (code) {
                              _code = code;
                              _loginFun();
                            },
                          ),

                          const SizedBox(height: 18),
                          _buildResendRow(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 3. Primary CTA: Verify & Login
                    GestureDetector(
                      onTap: _loginFun,
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
                            'تأكيد ومتابعة',
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

  Widget _buildResendRow() {
    return GestureDetector(
      onTap: _resendCodeFun,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(PhosphorIconsRegular.arrowsClockwise,
              color: kPrimaryOrange, size: 16),
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
    HapticFeedback.mediumImpact();
    if (_code.isEmpty || _code.length < 4) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => CustomDialog(message: 'يرجى إدخال رمز التحقق'),
        );
      }
      return;
    }
    try {
      await userProvider.loginByPhone(widget.phoneNumber, _code);
      if (!mounted) return;

      final authService = locator<AuthenticationService>();
      final bool isReturningUser = authService.hasCompletedProfile;

      if (!isReturningUser) {
        await _promptUserNameBottomSheet();
        if (!authService.hasCompletedProfile) {
          throw Exception('يرجى إدخال اسمك الكامل لإكمال الحساب.');
        }
      }

      await locator<CartProvider>().cartInfo.initData();

      if (!mounted) return;
      final currentUser = authService.user;
      final String greeting = (isReturningUser &&
              currentUser?.fullName != null &&
              currentUser!.fullName!.isNotEmpty)
          ? 'أهلاً بك مجدداً، ${currentUser.fullName}'
          : 'تم تسجيل الدخول بنجاح';

      context.showSnakBar(greeting);
      Navigator.pop(context, true);
    } catch (err) {
      if (mounted) {
        final cleanMsg = err
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Exception:', '')
            .replaceAll('Error: ', '')
            .trim();
        showDialog(
          context: context,
          builder: (context) => CustomDialog(
            title: 'تنبيه التحقق',
            message: cleanMsg.isNotEmpty
                ? cleanMsg
                : 'رمز التحقق غير صحيح أو انتهت صلاحيته. يرجى التأكد من الرمز والمحاولة مجدداً.',
          ),
        );
      }
    }
  }

  Future<void> _promptUserNameBottomSheet() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (isSubmitting) return;
              if (formKey.currentState?.validate() ?? false) {
                HapticFeedback.mediumImpact();
                setSheetState(() => isSubmitting = true);
                try {
                  final enteredName = nameController.text.trim();
                  userProvider.fullName = enteredName;
                  userProvider.phoneNumber = PhoneNumberModel(
                    phoneNumber: widget.phoneNumber,
                    dialCode: '+963',
                    isoCode: 'SY',
                  );
                  await userProvider.update();
                  locator<CartProvider>().cartInfo.name = enteredName;
                  if (sheetCtx.mounted) {
                    Navigator.pop(sheetCtx);
                  }
                } catch (e) {
                  if (sheetCtx.mounted) {
                    setSheetState(() => isSubmitting = false);
                    final message =
                        e.toString().replaceAll('Exception: ', '').trim();
                    showDialog(
                      context: sheetCtx,
                      builder: (context) => CustomDialog(
                        title: 'تعذر حفظ الاسم',
                        message: message.isEmpty
                            ? 'تعذر حفظ الاسم، يرجى المحاولة مجدداً.'
                            : message,
                      ),
                    );
                  }
                }
              }
            }

            return PopScope(
              canPop: false,
              child: GestureDetector(
                onTap: () => FocusScope.of(sheetCtx).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Drag Handle Indicator
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),

                              // Icon
                              Center(
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0E8),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      PhosphorIconsFill.user,
                                      color: kPrimaryOrange,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Title & Subtitle
                              Text(
                                'أهلاً بك في جيتك!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: kCharcoalDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'يرجى إدخال اسمك الكامل لإكمال حسابك وتسهيل التوصيل',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Name Input Field
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1.1,
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: TextFormField(
                                  controller: nameController,
                                  autofocus: true,
                                  textInputAction: TextInputAction.done,
                                  textCapitalization: TextCapitalization.words,
                                  onFieldSubmitted: (_) => submit(),
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: kCharcoalDark,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'الاسم الكامل',
                                    hintStyle: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 13.5,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    border: InputBorder.none,
                                    icon: const Icon(
                                      PhosphorIconsRegular.user,
                                      size: 20,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().length < 2) {
                                      return 'يرجى إدخال اسم صحيح';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Submit Button
                              GestureDetector(
                                onTap: isSubmitting ? null : submit,
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isSubmitting
                                        ? kPrimaryOrange.withValues(alpha: 0.7)
                                        : kPrimaryOrange,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: isSubmitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Text(
                                            'متابعة إلى التطبيق',
                                            style:
                                                GoogleFonts.ibmPlexSansArabic(
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
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _resendCodeFun() async {
    HapticFeedback.lightImpact();
    try {
      await userProvider.resendSmsCode(widget.phoneNumber);
      if (!mounted) return;
      context.showSnakBar('تمت إعادة إرسال رمز التحقق بنجاح');
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

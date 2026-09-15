import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/user_provider.dart';
import '../../../utils/custom_widgets/messages.dart';

/// ---------------------------------------------------------------------------
/// Merchant Change Password Page
/// Secure form for updating password with validation & confirmation checks.
/// ---------------------------------------------------------------------------

class ChangePasswordPage extends StatefulWidget {
  static const String routeName = '/ChangePasswordPage';

  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave(UserProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      provider.oldPassword = _oldPasswordController.text.trim();
      provider.newPassword = _newPasswordController.text.trim();
      await provider.changePassword();

      if (!mounted) return;

      SnackBarWidget.showCustomSnackBar(
        context,
        'تم تغيير كلمة المرور بنجاح 🟢',
        backgroundColor: const Color(0xFF064E3B),
      );
      Navigator.pop(context, true);
    } catch (err) {
      if (!mounted) return;
      SnackBarWidget.showCustomSnackBar(
        context,
        'تعذر تغيير كلمة المرور، يرجى التأكد من صحة كلمة المرور الحالية والمحاولة ثانية',
        backgroundColor: const Color(0xFF7F1D1D),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: Consumer<UserProvider>(
        builder: (context, userProv, _) {
          final isBusy = _isSaving || userProv.isBusy;

          return Scaffold(
            backgroundColor: kPageBackground,
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.white,
              title: Text(
                'تغيير كلمة المرور',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
              leading: IconButton(
                icon: const Icon(PhosphorIconsRegular.arrowRight, color: kCharcoalDark),
                onPressed: () => Navigator.pop(context),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Security Header Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kCardBorderColor, width: 1.0),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(PhosphorIconsFill.shieldCheck, color: kPrimaryOrange, size: 24),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تأمين حساب المتجر',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: kCharcoalDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'احرص على استخدام كلمة مرور قوية تحتوي على ٦ أحرف أو أرقام على الأقل للحفاظ على أمان حسابك.',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 11.5,
                                  color: kCharcoalMuted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Password Fields Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kCardBorderColor, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Old Password Field
                        _buildFieldLabel('كلمة المرور الحالية *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _oldPasswordController,
                          obscureText: _obscureOld,
                          validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال كلمة المرور الحالية' : null,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kCharcoalDark,
                          ),
                          decoration: _buildPasswordDecoration(
                            hint: 'أدخل كلمة المرور الحالية',
                            isObscured: _obscureOld,
                            onToggle: () => setState(() => _obscureOld = !_obscureOld),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // New Password Field
                        _buildFieldLabel('كلمة المرور الجديدة *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNew,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'يرجى إدخال كلمة المرور الجديدة';
                            }
                            if (v.trim().length < 6) {
                              return 'كلمة المرور يجب أن لا تقل عن ٦ خانات';
                            }
                            return null;
                          },
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kCharcoalDark,
                          ),
                          decoration: _buildPasswordDecoration(
                            hint: '٦ خانات على الأقل',
                            isObscured: _obscureNew,
                            onToggle: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Confirm New Password Field
                        _buildFieldLabel('تأكيد كلمة المرور الجديدة *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'يرجى إعادة إدخال كلمة المرور الجديدة للتأكيد';
                            }
                            if (v.trim() != _newPasswordController.text.trim()) {
                              return 'كلمتا المرور غير متطابقتين';
                            }
                            return null;
                          },
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kCharcoalDark,
                          ),
                          decoration: _buildPasswordDecoration(
                            hint: 'أعد كتابة كلمة المرور الجديدة',
                            isObscured: _obscureConfirm,
                            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Save Button
                  ElevatedButton(
                    onPressed: isBusy ? null : () => _handleSave(userProv),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(PhosphorIconsRegular.lockKey, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'تحديث كلمة المرور',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.ibmPlexSansArabic(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: kCharcoalMedium,
      ),
    );
  }

  InputDecoration _buildPasswordDecoration({
    required String hint,
    required bool isObscured,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.ibmPlexSansArabic(
        fontSize: 12.5,
        color: const Color(0xFF94A3B8),
      ),
      prefixIcon: const Icon(PhosphorIconsRegular.lockSimple, size: 18, color: kCharcoalMuted),
      suffixIcon: IconButton(
        icon: Icon(
          isObscured ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye,
          size: 18,
          color: kCharcoalMuted,
        ),
        onPressed: onToggle,
      ),
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
        borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/user_provider.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/messages.dart';

/// ---------------------------------------------------------------------------
/// Merchant Account Owner Personal Profile Page
/// Displays owner credentials, verified mobile phone, and contact email.
/// ---------------------------------------------------------------------------

class ProfilePage extends StatefulWidget {
  static const String routeName = '/ProfilePage';

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final authService = locator<AuthenticationService>();
    final user = authService.user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave(UserProvider modelProvider) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      modelProvider.fullName = _nameController.text.trim();
      modelProvider.email = _emailController.text.trim();
      await modelProvider.update();

      if (!mounted) return;

      SnackBarWidget.showCustomSnackBar(
        context,
        'تم حفظ البيانات الشخصية للمالك بنجاح 🟢',
        backgroundColor: const Color(0xFF064E3B),
      );
      Navigator.pop(context, true);
    } catch (err) {
      if (!mounted) return;
      SnackBarWidget.showCustomSnackBar(
        context,
        'حدث خطأ أثناء حفظ البيانات، يرجى المحاولة ثانية',
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
      create: (_) => UserProvider()..loadUserDataProfile(),
      child: Consumer<UserProvider>(
        builder: (context, userProv, _) {
          final authUser = locator<AuthenticationService>().user;
          final phone = authUser?.phoneNumber ?? '';
          final displayName = _nameController.text.isNotEmpty
              ? _nameController.text
              : (authUser?.fullName ?? 'مالك المتجر');

          return Scaffold(
            backgroundColor: kPageBackground,
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.white,
              title: Text(
                'البيانات الشخصية للمالك',
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
              actions: [
                TextButton(
                  onPressed: (_isSaving || userProv.isBusy) ? null : () => _handleSave(userProv),
                  child: (_isSaving || userProv.isBusy)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryOrange),
                        )
                      : Text(
                          'حفظ',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kPrimaryOrange,
                          ),
                        ),
                ),
              ],
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
                  // 1. Owner Identity Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kCardBorderColor, width: 1.0),
                    ),
                    child: Column(
                      children: [
                        // Avatar Squircle with Initials
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3EB),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFFFD6C2), width: 1.5),
                          ),
                          child: Center(
                            child: Icon(
                              PhosphorIconsFill.userCheck,
                              size: 36,
                              color: kPrimaryOrange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Full Name
                        Text(
                          displayName,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: kCharcoalDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),

                        // Owner Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIconsFill.shieldCheck, size: 14, color: Color(0xFF059669)),
                              const SizedBox(width: 5),
                              Text(
                                'مالك المتجر المعتمد (Verified Merchant)',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Personal Details Form Card
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
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3EB),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Center(
                                child: Icon(PhosphorIconsRegular.userList, color: kPrimaryOrange, size: 18),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'بيانات الحساب والاتصال',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: kCharcoalDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Full Name Field
                        _buildFieldLabel('الاسم الكامل للمالك *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: kCharcoalDark,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'الاسم الثلاثي لمالك الحساب',
                            prefixIcon: PhosphorIconsRegular.user,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Verified Phone Number Field (Read Only)
                        _buildFieldLabel('رقم الهاتف المعتمد (اسم المستخدم)'),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(PhosphorIconsRegular.phoneCall, size: 18, color: kCharcoalMuted),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    phone.isNotEmpty ? phone : 'غير مسجل',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kCharcoalDark,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(PhosphorIconsFill.lockKey, size: 12, color: kCharcoalMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      'موثق',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: kCharcoalMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'يستخدم رقم الهاتف لتسجيل الدخول ولا يمكن تغييره إلا بالتواصل مع الدعم الفني.',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              color: kCharcoalMuted,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Email Field
                        _buildFieldLabel('البريد الإلكتروني للتقارير والإشعارات'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: kCharcoalDark,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'example@domain.com',
                            prefixIcon: PhosphorIconsRegular.envelopeSimple,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Security Advisory Notice Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(PhosphorIconsRegular.shieldCheck, color: Color(0xFFD97706), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'بيانات المالك محمية وتُستخدم فقط للتواصل الرسمي، إرسال تقارير التسويات المالية، وتأكيد عمليات الأمان والتحقق.',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF92400E),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Save Button
                  ElevatedButton(
                    onPressed: (_isSaving || userProv.isBusy) ? null : () => _handleSave(userProv),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: (_isSaving || userProv.isBusy)
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(PhosphorIconsRegular.checkCircle, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'حفظ التعديلات',
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

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.ibmPlexSansArabic(
        fontSize: 12.5,
        color: const Color(0xFF94A3B8),
      ),
      prefixIcon: Icon(prefixIcon, size: 18, color: kCharcoalMuted),
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

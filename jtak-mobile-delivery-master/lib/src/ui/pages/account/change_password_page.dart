import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../main_imports.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/user_provider.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/custom_widgets/text_field.dart';
import '../../../utils/utilities/global_var.dart';

class ChangePasswordPage extends StatefulWidget {
  static const String routeName = '/ChangePasswordPage';
  const ChangePasswordPage({Key? key}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late UserProvider provider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BaseView<UserProvider>(
      modelProvider: UserProvider(),
      builder: (context, modelProvider) {
        provider = modelProvider;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : kPageBackground,
          appBar: AppBar(
            title: const Text(
              'تغيير كلمة المرور',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            centerTitle: true,
          ),
          body: FullScreenLoading(
            inAsyncCall: modelProvider.isBusy,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : kCardBorderColor,
                        width: 1.1,
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const AppIcon(PhosphorIcons.lockKeyBold, size: 20, color: kPrimaryOrange),
                              const SizedBox(width: 8),
                              Text(
                                'تحديث كلمة المرور',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : kCharcoalDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'كلمة المرور الحالية',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          PasswordTextFormField(
                            lable: str.formAndAction.oldPassword,
                            onChanged: (value) => provider.oldPassword = value.trim(),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'كلمة المرور الجديدة',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          PasswordTextFormField(
                            lable: str.formAndAction.newPassword,
                            onChanged: (value) => provider.newPassword = value.trim(),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              onPressed: _savePassword,
                              child: const Text('حفظ كلمة المرور'),
                            ),
                          ),
                        ],
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

  void _savePassword() async {
    try {
      if (_formKey.currentState?.validate() ?? false) {
        await provider.changePassword();
        context.showSnakBar(str.msg.saveSucceeded);
        context.pop();
      }
    } catch (err) {
      showDialog(context: context, builder: (ctx) => CustomDialog(message: err.toString()));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:app_jtak_delivery/src/config/themes/app_theme.dart';
import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';
import 'package:app_jtak_delivery/src/utils/utilities/validation.dart';

class TextFormFieldWidget extends StatelessWidget {
  final String? initialValue;
  final String? lable;
  final String? hint;
  final void Function(String value)? onChanged;
  final String? Function(String?)? validator;

  const TextFormFieldWidget({this.initialValue, this.lable, this.hint, this.onChanged, this.validator});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      initialValue: initialValue,
      style: TextStyle(color: isDark ? Colors.white : null),
      decoration: AppTheme.getBorderdTextFieldDecoration(context: context, lable: lable, hint: hint),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class PasswordTextFormField extends StatefulWidget {
  final String? initValue;
  final String? lable;
  final String? hint;

  final Function(String val)? onChanged;
  const PasswordTextFormField({this.initValue, this.onChanged, this.lable, this.hint});
  @override
  _PasswordTextFormFieldState createState() => _PasswordTextFormFieldState();
}

class _PasswordTextFormFieldState extends State<PasswordTextFormField> {
  bool _obscureText = true;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      textDirection: TextDirection.ltr,
      initialValue: widget.initValue,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      style: TextStyle(color: isDark ? Colors.white : null),
      decoration: AppTheme.getBorderdTextFieldDecoration(context: context, lable: widget.lable, hint: widget.hint).copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        prefixIcon: Icon(Icons.lock_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
        suffixIcon: InkWell(
          child: Icon(
            _obscureText ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
          ),
          onTap: () => setState(
            () => _obscureText = !_obscureText,
          ),
        ),
      ),
      validator: (val) => ValidationUtil.stringLengthValidation(val, str.msg.passwordShort),
      onChanged: widget.onChanged,
    );
  }
}

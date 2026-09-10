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
    return TextFormField(
      initialValue: initialValue,
      decoration: AppTheme.getBorderdTextFieldDecoration(lable: lable, hint: hint),
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
    return TextFormField(
      textDirection: TextDirection.ltr,
      initialValue: widget.initValue,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      decoration: AppTheme.getBorderdTextFieldDecoration(lable: widget.lable, hint: widget.hint).copyWith(
        contentPadding: const EdgeInsets.all(0),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: InkWell(
          child: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
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

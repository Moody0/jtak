import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/themes/app_theme.dart';
import '../utilities/global_var.dart';
import '../utilities/validation.dart';

import '../../config/themes/colors.dart';

class TextFormFieldWidget extends StatelessWidget {
  final String? initialValue;
  final TextEditingController? controller;
  final TextStyle textStyle;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? counterText;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final String? suffixText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final bool? autofocus;
  final double? height;
  final bool? enabled;
  final bool readOnly;
  final String? Function(String? val)? validator;
  final String Function(String? val)? onSaved;
  final String Function(String? val)? onSubmitted;
  final String Function()? onTap;
  final Function(String val)? onChanged;

  const TextFormFieldWidget({
    Key? key,
    this.initialValue,
    this.controller,
    this.textStyle = const TextStyle(fontSize: 14),
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.labelText,
    this.hintText,
    this.helperText,
    this.counterText,
    this.inputFormatters,
    this.prefixText,
    this.suffixText,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.keyboardType,
    this.height,
    this.enabled,
    this.readOnly = false,
    this.validator,
    this.onSaved,
    this.onSubmitted,
    this.onTap,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textAlign: textAlign,
      maxLines: maxLines,
      minLines: minLines,
      style: textStyle,
      maxLength: maxLength,
      autofocus: autofocus ?? false,
      textDirection: textDirection,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600]!)),
        focusColor: kAccentColor,
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.grey[700]),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[700]),
        helperText: helperText,
        counterText: counterText,
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: Colors.red, fontSize: 22),
        suffixIcon: suffixIcon,
        prefixText: prefixText,
        prefixStyle: const TextStyle(color: Colors.red, fontSize: 22),
        prefixIcon: prefixIcon,
      ),
      enabled: enabled,
      readOnly: readOnly,
      validator: validator,
      onSaved: onSaved,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      onChanged: onChanged,
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
      decoration: AppTheme.getTextFieldDecoration(lable: widget.lable, hint: widget.hint).copyWith(
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

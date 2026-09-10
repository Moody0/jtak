import 'dart:developer';

import 'package:app_jtak_delivery/src/config/constants/app_constant.dart';
import 'package:app_jtak_delivery/src/config/themes/app_theme.dart';
import 'package:app_jtak_delivery/src/config/themes/theme.dart';
import 'package:app_jtak_delivery/src/core/controllers/app/app_state_manager.dart';
import 'package:app_jtak_delivery/src/core/models/phone_number_model.dart';
import 'package:app_jtak_delivery/src/core/services/locator.dart';
import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class PhoneWidget extends StatefulWidget {
  final PhoneNumberModel? initValue;
  final bool isEnabled;
  final void Function(PhoneNumberModel phone) onChanged;
  final void Function(bool isValid)? onInputValidated;
  final String? Function(String? value)? validator;

  const PhoneWidget({this.initValue, required this.onChanged, this.onInputValidated, this.validator, this.isEnabled = true});

  @override
  _PhoneWidgetState createState() => _PhoneWidgetState();
}

class _PhoneWidgetState extends State<PhoneWidget> {
  PhoneNumberModel _phoneNumber = PhoneNumberModel();
  bool _isPhoneNumberValid = true;
  @override
  Widget build(BuildContext context) {
    return InternationalPhoneNumberInput(
      initialValue: PhoneNumber(
        phoneNumber: widget.initValue?.phoneNumber,
        isoCode: widget.initValue?.isoCode,
        dialCode: widget.initValue?.dialCode,
      ),
      onInputValidated: (value) {
        log(value.toString());
        if (widget.onInputValidated != null) {
          widget.onInputValidated!(value);
        }
        _isPhoneNumberValid = value;
      },
      maxLength: 13,
      textStyle: const TextStyle(fontSize: 18, fontFamily: ''),
      spaceBetweenSelectorAndTextField: 0,
      locale: locator<AppStateManager>().appLanguage,
      hintText: str.formAndAction.phone,
      isEnabled: widget.isEnabled,
      countries: kCountriesCode.values.toList(),
      selectorTextStyle: const TextStyle(fontSize: 18, fontFamily: '', color: colorGrey),
      searchBoxDecoration: InputDecoration(labelText: str.main.search),
      selectorConfig: const SelectorConfig(selectorType: PhoneInputSelectorType.DIALOG),
      inputDecoration: AppTheme.getBorderdTextFieldDecoration(lable: str.formAndAction.phone).copyWith(
        prefixIcon: const RotatedBox(quarterTurns: 3, child: Icon(Icons.call, color: Colors.grey)),
        errorText: _isPhoneNumberValid ? null : str.msg.invalidPhoneNumber,
        contentPadding: EdgeInsets.only(left: 8, right: 8),
      ),
      validator: widget.validator,
      onInputChanged: (PhoneNumber value) {
        _phoneNumber = PhoneNumberModel(
          phoneNumber: value.phoneNumber,
          isoCode: value.isoCode,
          dialCode: value.dialCode,
        );
        widget.onChanged(_phoneNumber);
      },
    );
  }
}

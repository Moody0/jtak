import 'package:app_jtak_warehouse/src/config/themes/app_theme.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/material.dart';

class AmountTextFieldWidget extends StatefulWidget {
  final double? initValue;
  final String? lable;
  final String? hint;
  final void Function(double amount) onChanged;
  final String? Function(String? val)? validator;
  final Function()? onEditingComplete;
  final Function()? onLostFocus;
  AmountTextFieldWidget({
    this.initValue,
    this.lable,
    this.hint,
    required this.onChanged,
    this.validator,
    this.onEditingComplete,
    this.onLostFocus,
  });

  @override
  _AmountTextFieldWidgetState createState() => _AmountTextFieldWidgetState();
}

class _AmountTextFieldWidgetState extends State<AmountTextFieldWidget> {
  late TextEditingController _amountTextEditingController;
  final _amountFocusNode = FocusNode();
  String? initValue;

  @override
  void initState() {
    initValue = widget.initValue?.toStringAsFixed(2);
    _amountTextEditingController = TextEditingController(text: initValue);
    _amountFocusNode.addListener(() {
      if (_amountFocusNode.hasFocus) {
        _amountTextEditingController.selection = TextSelection(baseOffset: 0, extentOffset: _amountTextEditingController.text.length);
      } else {
        if (widget.onLostFocus != null) widget.onLostFocus!();
      }
    });

    super.initState();
  }

  @override
  void didUpdateWidget(covariant AmountTextFieldWidget oldWidget) {
    initValue = widget.initValue?.toStringAsFixed(2);
    _amountTextEditingController = TextEditingController(text: initValue);
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _amountTextEditingController,
      key: GlobalKey(),
      focusNode: _amountFocusNode,
      decoration: AppTheme.getBorderdTextFieldDecoration(
        hint: widget.hint,
        lable: widget.lable,
      ).copyWith(
        errorStyle: TextStyle(fontSize: 9),
        constraints: BoxConstraints(maxHeight: 35),
      ),
      textAlign: TextAlign.end,
      keyboardType: TextInputType.number,
      validator: widget.validator ?? validator,
      onChanged: (val) {
        widget.onChanged(double.tryParse(val.trim()) ?? widget.initValue ?? 0.0);
      },
      onEditingComplete: widget.onEditingComplete,
    );
  }

  String? validator(String? val) {
    if (GlobalVar.checkString(val)) {
      var amount = double.tryParse(val!);
      if (amount != null && amount >= 0)
        return null;
      else
        return str.msg.invalidPhoneNumber;
    }
    _amountTextEditingController.text = '0';
    return null;
  }

  @override
  void dispose() {
    _amountTextEditingController.dispose();
    super.dispose();
  }
}

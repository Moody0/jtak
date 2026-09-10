import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jtek_app/src/config/constants/constants.dart';
import 'package:jtek_app/src/config/themes/app_theme.dart';
import 'package:jtek_app/src/core/controllers/order/cart_provider.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';
import 'package:provider/provider.dart';
import '../../../main_imports.dart';

class PaymentFormSection extends StatefulWidget {
  const PaymentFormSection();
  @override
  _PaymentFormSectionState createState() => _PaymentFormSectionState();
}

class _PaymentFormSectionState extends State<PaymentFormSection> {
  late CartProvider provider;

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<CartProvider>(context);
    return Padding(
      padding: AppTheme.standardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: provider.orderPayment.nameOnCard,
                  decoration: AppTheme.getBorderdTextFieldDecoration(lable: str.app.nameOnCard),
                  validator: (value) => !GlobalVar.checkString(value) ? str.msg.invalidName : null,
                  onChanged: (String value) => provider.orderPayment.nameOnCard = value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    initialValue: provider.orderPayment.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(19),
                      CardNumberInputFormatter(),
                    ],
                    keyboardType: TextInputType.number,
                    decoration: AppTheme.getBorderdTextFieldDecoration(lable: str.app.creditCardNumber),
                    validator: (value) =>
                        GlobalVar.checkString(value) || (int.tryParse(getCleanedNumber(value!)) == null) ? str.msg.fillFieldInt : null,
                    onChanged: (String value) => provider.orderPayment.number = getCleanedNumber(value),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: provider.orderPayment.cvc,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  keyboardType: TextInputType.number,
                  decoration: AppTheme.getBorderdTextFieldDecoration(lable: str.app.cardCode),
                  validator: (value) => GlobalVar.checkString(value) || (int.tryParse(value!) == null) ? str.msg.fillFieldInt : null,
                  onChanged: (String value) => provider.orderPayment.cvc = getCleanedNumber(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(str.app.cardExpireDate, style: context.textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: provider.orderPayment.month,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                    LengthLimitingTextInputFormatter(2),
                    CardMonthInputFormatter(),
                  ],
                  keyboardType: TextInputType.number,
                  decoration: AppTheme.getBorderdTextFieldDecoration(lable: str.app.month),
                  validator: (value) => GlobalVar.checkString(value) || (int.tryParse(value!) == null) ? str.msg.fillFieldInt : null,
                  onChanged: (String value) => provider.orderPayment.month = value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: provider.orderPayment.year,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                    LengthLimitingTextInputFormatter(4),
                    CardMonthInputFormatter(),
                  ],
                  keyboardType: TextInputType.number,
                  decoration: AppTheme.getBorderdTextFieldDecoration(lable: str.app.month),
                  validator: (value) => GlobalVar.checkString(value) || (int.tryParse(value!) == null) ? str.msg.fillFieldInt : null,
                  onChanged: (String value) => provider.orderPayment.year = value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(child: Image.asset(kAssetsImageBase + 'credit_cards.png')),
        ],
      ),
    );
  }

  String getCleanedNumber(String text) {
    RegExp regExp = RegExp(r"[^0-9]");
    log('getCleanerNumber : ${text.replaceAll(regExp, '')}');
    return text.replaceAll(regExp, '');
  }
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write('  '); // Add double spaces.
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}

class CardMonthInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var newText = newValue.text;
    int month = int.tryParse(newText) ?? 1;
    if (month > 1 && month > 12) newText = oldValue.text;
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}

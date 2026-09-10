import 'package:flutter/material.dart';
import 'package:jtek_app/src/config/constants/app_constant.dart';
import 'package:jtek_app/src/config/themes/app_theme.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';

class PriceTextWidget extends StatelessWidget {
  final double? price;
  final String currencyString;

  final TextStyle textStyle;

  const PriceTextWidget.large({
    required this.price,
    this.currencyString = kMainCurrencySymbol,
    this.textStyle = AppTheme.currencyIntegerStyleLarg,
  });

  const PriceTextWidget.small({
    required this.price,
    this.currencyString = kMainCurrencySymbol,
    this.textStyle = AppTheme.currencyIntegerStyleSmall,
  });

  @override
  Widget build(BuildContext context) {
    // var p = GlobalVar.doubleToString(price, "0.0").split('.');
    var price1 = GlobalVar.currencyForamt(price ?? 0);
    return Text(
      '$price1$currencyString',
      style: textStyle,
      overflow: TextOverflow.ellipsis,
      textScaler: const TextScaler.linear(1),
    );
  }
}

class DiscountWidget extends StatelessWidget {
  final double? price;
  final String currencyString;
  final TextStyle? textStyle;

  const DiscountWidget({
    required this.price,
    this.textStyle,
    this.currencyString = kMainCurrencySymbol,
  });
  @override
  Widget build(BuildContext context) {
    if (price == null) return const SizedBox();
    var price1 = GlobalVar.currencyForamt(price ?? 0);
    return Text('$price1$currencyString', style: textStyle ?? AppTheme.discountCurrencyStyle);
  }
}

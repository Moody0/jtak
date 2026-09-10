import 'package:app_jtak_delivery/src/config/constants/app_constant.dart';
import 'package:app_jtak_delivery/src/config/themes/app_theme.dart';
import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';
import 'package:flutter/material.dart';

class PriceTextWidget extends StatelessWidget {
  final double? price;
  final String currencyString;

  final TextStyle currencyIntegerStyle;
  final TextStyle currencyStringStyle;

  const PriceTextWidget.large({
    required this.price,
    this.currencyString = kMainCurrencySymbol,
    this.currencyIntegerStyle = AppTheme.currencyIntegerStyleLarg,
    this.currencyStringStyle = AppTheme.currencyStringStyleLarg,
  });

  const PriceTextWidget.small({
    required this.price,
    this.currencyString = kMainCurrencySymbol,
    this.currencyIntegerStyle = AppTheme.currencyIntegerStyleSmall,
    this.currencyStringStyle = AppTheme.currencyStringStyleSmall,
  });

  @override
  Widget build(BuildContext context) {
    // var p = GlobalVar.doubleToString(price, "0.0").split('.');
    var price1 = GlobalVar.currencyForamt(price ?? 0, currencySymbol: currencyString);
    return Text(
      price1,
      style: currencyIntegerStyle,
      overflow: TextOverflow.ellipsis,
      textScaleFactor: 1,
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
    return Text(GlobalVar.currencyForamt(price!, currencySymbol: currencyString), style: textStyle ?? AppTheme.discountCurrencyStyle);
  }
}

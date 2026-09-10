import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:jtek_app/src/config/constants/constants.dart';
import 'package:jtek_app/src/config/themes/app_theme.dart';
import 'package:jtek_app/src/config/themes/colors.dart';
import 'package:jtek_app/src/core/controllers/order/order_provider.dart';
import 'package:jtek_app/src/core/models/order/order_model.dart';
import 'package:jtek_app/src/ui/widgets/catalog/price_widgets.dart';
import 'package:jtek_app/src/utils/custom_widgets/messages.dart';
import 'package:jtek_app/src/utils/custom_widgets/rating_bar.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../main_imports.dart';

class RateOrder extends StatelessWidget {
  final OrderModel item;
  const RateOrder(this.item);
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 24.0),
      children: [
        Stack(
          children: [
            Container(
              padding: AppTheme.standardPadding,
              child: Column(
                children: [
                  Text(
                    'تقييمك للطلب',
                    style: context.textTheme.displaySmall?.copyWith(color: kPrimaryColor, fontWeight: FontWeight.bold),
                  ),
                  context.addHeight(12),
                  Align(
                      alignment: Alignment.centerRight,
                      child: Text('يعتمد على سرعة الخدمة وعلى مدى سهولة استخدام التطبيق', style: context.textTheme.bodyLarge)),
                  context.addHeight(12),
                  Align(alignment: Alignment.centerRight, child: Text('معلومات الطلب', style: context.textTheme.bodyLarge)),
                  context.addHeight(8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(GlobalVar.dateForamt(item.createdDate, kDateFormat) ?? '', style: context.textTheme.headlineMedium),
                      PriceTextWidget.small(price: item.price, textStyle: AppTheme.currencyIntegerStyleSmall.copyWith(height: 0.4)),
                      Text(GlobalVar.dateForamt(item.createdDate, kTimeFormat) ?? '', style: context.textTheme.headlineMedium),
                    ],
                  ),
                  context.addHeight(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('سيء', style: context.textTheme.titleSmall),
                      RatingBarWidget(
                        rate: 3,
                        onRatingUpdateHandler: (rating) async {
                          try {
                            OrderProvider provider = Provider.of<OrderProvider>(context, listen: false);
                            await provider.rateOrder(item.id ?? 0, rating);
                            Navigator.pop(context);
                            context.showSnakBar('تم ارسال التقييم');
                          } catch (err) {
                            showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
                          }
                        },
                        itemSize: 30,
                      ),
                      Text('ممتاز', style: context.textTheme.bodySmall),
                    ],
                  ),
                  context.addHeight(24),
                  GestureDetector(
                    onTap: (() => whatsappFun(context)),
                    child: Text(
                      'لم يصلك الطلب؟ انقر هنا',
                      style: AppTheme.linkStyle.copyWith(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w300),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
                child: IconButton(
              icon: const Icon(Icons.close, color: kPrimaryColor),
              onPressed: () => Navigator.pop(context),
            ))
          ],
        )
      ],
    );
  }

  void whatsappFun(BuildContext context) async {
    var whatsappPhone = "+905300888301";
    var whatsappURlAndroid = "whatsapp://send?phone=" + whatsappPhone + "&text=";
    var whatappURLIOS = "https://wa.me/$whatsappPhone?text=${Uri.parse("")}";
    var url = (!kIsWeb && Platform.isIOS) ? whatappURLIOS : whatsappURlAndroid;
    try {
      await launch(url);
    } catch (e) {
      GlobalVar.log(e.toString());
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لايوجد تطبيق واتس اب !')));
    }
  }
}

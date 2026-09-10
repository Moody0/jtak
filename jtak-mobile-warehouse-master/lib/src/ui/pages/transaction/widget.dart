import 'package:app_jtak_warehouse/src/config/constants/constants.dart';
import 'package:app_jtak_warehouse/src/core/controllers/payment_provider.dart';
import 'package:app_jtak_warehouse/src/core/enums/payment_method_enum.dart';
import 'package:app_jtak_warehouse/src/core/models/bill_model.dart';
import 'package:app_jtak_warehouse/src/core/models/payment_model.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/price_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/button.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/messages.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../main_imports.dart';

class PaymentSingleItem extends StatelessWidget {
  final PaymentModel item;
  const PaymentSingleItem(this.item);
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                PriceTextWidget.small(price: item.amount ?? 0.0),
                const Spacer(),
                Text('#${item.id}', style: context.textTheme.caption),
              ],
            ),
            Row(
              children: [
                Text(GlobalVar.dateForamt(item.handoverDate, kDateTimeFormat) ?? '', style: context.textTheme.bodyText1),
                const Spacer(),
                _status(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _status(BuildContext context) {
    if (item.handoverDate == null) {
      return ButtonWidget(
          text: 'استلام',
          onPressed: () {
            try {
              PaymentProvider provider = Provider.of<PaymentProvider>(context, listen: false);
              provider.recivePayment(item.id!);
            } catch (err) {
              showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
            }
          });
    }

    return Text('تم الاستلام من ${item.byUser}', style: context.textTheme.headline6);
  }
}

class BillSingleItem extends StatelessWidget {
  final BillModel item;
  const BillSingleItem(this.item);
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                PriceTextWidget.small(price: item.merchantAmount ?? 0.0),
                const Spacer(),
                RichText(
                  text: TextSpan(
                    text: 'الطلب: #${item.orderId}',
                    style: context.textTheme.caption,
                    children: [
                      TextSpan(
                        text: '#${item.id}',
                        style: context.textTheme.caption?.copyWith(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(GlobalVar.dateForamt(item.dueDate, kDateTimeFormat) ?? '', style: context.textTheme.caption),
                const Spacer(),
                _paymentMethod(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethod(BuildContext context) {
    if (item.paymentMethod == PaymentMethod.creditCardPayment) {
      return Row(
        children: [
          Icon(Icons.credit_card, size: 15),
          Text(item.paymentMethod?.value ?? ''),
        ],
      );
    } else if (item.paymentMethod == PaymentMethod.payOnDelivery) {
      return Row(
        children: [
          Icon(Icons.money, size: 15),
          Text(item.paymentMethod?.value ?? ''),
        ],
      );
    }
    return const SizedBox();
  }
}

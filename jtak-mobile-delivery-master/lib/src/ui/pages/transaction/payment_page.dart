import 'package:app_jtak_delivery/src/core/controllers/payment_provider.dart';
import 'package:app_jtak_delivery/src/ui/pages/transaction/widget.dart';
import 'package:app_jtak_delivery/src/utils/custom_widgets/base_view.dart';
import 'package:app_jtak_delivery/src/utils/custom_widgets/infinite_listview.dart';
import 'package:flutter/material.dart';

class PaymentPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseView<PaymentProvider>(
      modelProvider: PaymentProvider(),
      onModelReady: (modelProvider) => modelProvider.loadPayments(),
      builder: (context, modelProvider) {
        return InfiniteListview(
          modelProvider: modelProvider,
          loadDataFun: modelProvider.loadPayments,
          listItemWidget: (item) => PaymentSingleItem(item),
        );
      },
    );
  }
}

import 'package:app_jtak_delivery/src/core/controllers/bill_provider.dart';
import 'package:app_jtak_delivery/src/ui/pages/transaction/widget.dart';
import 'package:app_jtak_delivery/src/utils/custom_widgets/base_view.dart';
import 'package:app_jtak_delivery/src/utils/custom_widgets/infinite_listview.dart';
import 'package:flutter/material.dart';

class BillsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseView<BillProvider>(
      modelProvider: BillProvider(),
      onModelReady: (modelProvider) => modelProvider.loadBills(),
      builder: (context, modelProvider) {
        return InfiniteListview(
          modelProvider: modelProvider,
          loadDataFun: modelProvider.loadBills,
          listItemWidget: (item) => BillSingleItem(item),
        );
      },
    );
  }
}

import 'package:app_jtak_delivery/src/core/controllers/payment_provider.dart';
import 'package:app_jtak_delivery/src/ui/pages/transaction/widget.dart';
import 'package:app_jtak_delivery/src/ui/widgets/app_widgets.dart';
import 'package:app_jtak_delivery/src/utils/custom_widgets/base_view.dart';
import 'package:app_jtak_delivery/src/utils/custom_widgets/infinite_listview.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class PaymentPage extends StatelessWidget {
  final Future<void> Function()? onRefreshBalances;
  const PaymentPage({Key? key, this.onRefreshBalances}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return BaseView<PaymentProvider>(
      modelProvider: PaymentProvider(),
      onModelReady: (modelProvider) => modelProvider.loadPayments(),
      builder: (context, modelProvider) {
        return InfiniteListview(
          modelProvider: modelProvider,
          loadDataFun: () async {
            if (onRefreshBalances != null) {
              await onRefreshBalances!();
            }
            return modelProvider.loadPayments();
          },
          emptyWidget: NoDataAvailableWidget(
            icon: PhosphorIcons.receiptBold,
            msg: isArabic ? 'لا توجد دفعات أو تسويات مسجلة' : 'No payments or remittances recorded',
            subMsg: isArabic
                ? 'ستظهر هنا سجلات المبالغ الموردة للمحاسب بعد إجراء أول تسوية لحسابك'
                : 'Records of funds deposited with the cashier will appear here after your first settlement',
          ),
          listItemWidget: (item) => PaymentSingleItem(item),
        );
      },
    );
  }
}

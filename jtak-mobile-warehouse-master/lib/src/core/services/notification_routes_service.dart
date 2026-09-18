import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/notifications_payload_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:app_jtak_warehouse/src/ui/pages/transaction/payment_page.dart';
import 'package:flutter/material.dart';

class NotificationRoutesService {
  BuildContext context;
  NotificationRoutesService(this.context);

  void parseNotificationUrl(NotificationPayloadModel payload) {
    GlobalVar.log('######## NotificationRoutesService parseNotification : payload \n $payload');
    String? url = payload.url;
    if (url != null) {
      var urlContent = url.split('/');
      if (urlContent.length > 3) {
        String type = urlContent[3];
        switch (type) {
          case 'Orders':
            if (urlContent.length > 4) {
              String actionType = urlContent[4];
              List<String> parameters = urlContent.length > 5 ? urlContent.sublist(5) : [];
              orderModelParser(actionType, parameters);
            }
            break;
          case 'Settlement':
          case 'Payment':
          case 'reconciliation':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentPage()),
            );
            break;
          default:
        }
      }
    }
  }

  void orderModelParser(String type, List<String> parameters) {
    int orderId = -1;
    if (parameters.isNotEmpty) {
      orderId = int.tryParse(parameters[0]) ?? -1;
    }
    switch (type) {
      case 'NewMerchantOrder':
        OrderProvider orderProvider = locator<OrderProvider>();
        orderProvider.page = 0;
        orderProvider.loadPagedData();
        break;
      default:
    }
    GlobalVar.log('orderId : $orderId');
  }
}

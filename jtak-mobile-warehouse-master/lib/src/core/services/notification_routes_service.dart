import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/notifications_payload_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/material.dart';

class NotificationRoutesService {
  BuildContext context;
  NotificationRoutesService(this.context);

  void parseNotificationUrl(NotificationPayloadModel payload) {
    GlobalVar.log('######## NotificationRoutesService parseNotification : payload \n $payload');
    String? url = payload.url;
    if (url != null) {
      var urlContent = url.split('/');
      String type = urlContent[3];
      switch (type) {
        case 'Orders':
          String actionType = urlContent[4];
          List<String> parameters = urlContent.sublist(5);
          orderModelParser(actionType, parameters);
          break;
        default:
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

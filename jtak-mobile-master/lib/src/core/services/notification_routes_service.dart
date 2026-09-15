import 'package:flutter/material.dart';
import 'package:jtek_app/src/core/controllers/order/cart_provider.dart';
import 'package:jtek_app/src/core/models/notifications_payload_model.dart';
import 'package:jtek_app/src/core/models/order/order_model.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/ui/pages/orders/order_details_page.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';
import '../../../main_imports.dart';

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
    OrderModel order = OrderModel(id: orderId);
    switch (type) {
      case 'ItemsNotFound':
      case 'ItemsChanged':
      case 'ShippingStarted':
      case 'CustomerReady':
      case 'Rejected':
      case 'Cancel':
        if (type == 'Rejected' || type == 'Cancel' || type == 'ItemsNotFound') {
          locator<CartProvider>().clearCart();
        }
        context.navigateName(OrderDetailsPage.routeName, data: order);
        break;
      default:
    }
  }
}

import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';

enum OrderDetailsStatus {
  pending,
  merchantAccepted,
  shipping,
  delivered,
  merchantRejected,
  customerPending,
  customerCanceled,
  deliveryCanceled,
}

extension StringValueExtention on OrderDetailsStatus {
  String get value {
    switch (this) {
      case OrderDetailsStatus.pending:
        return str.app.orderDetailsStatusPending;

      case OrderDetailsStatus.merchantAccepted:
        return str.app.orderDetailsStatusMerchantAccepted;

      case OrderDetailsStatus.shipping:
        return str.app.orderDetailsStatusShipping;

      case OrderDetailsStatus.delivered:
        return str.app.orderDetailsStatusDelivered;

      case OrderDetailsStatus.merchantRejected:
        return str.app.orderDetailsStatusMerchantRejected;

      case OrderDetailsStatus.customerPending:
        return str.app.orderDetailsStatusCustomerPending;

      case OrderDetailsStatus.customerCanceled:
        return str.app.orderDetailsStatusCustomerCanceled;

      case OrderDetailsStatus.deliveryCanceled:
        return str.app.orderDetailsStatusDeliveryCanceled;
    }
  }
}

extension ParseEnumExtention on int {
  OrderDetailsStatus get parseOrderDetailsStatus {
    switch (this) {
      case 0:
        return OrderDetailsStatus.pending;
      case 1:
        return OrderDetailsStatus.merchantAccepted;
      case 2:
        return OrderDetailsStatus.shipping;
      case 3:
        return OrderDetailsStatus.delivered;
      case 4:
        return OrderDetailsStatus.merchantRejected;
      case 5:
        return OrderDetailsStatus.customerPending;
      case 6:
        return OrderDetailsStatus.customerCanceled;
      case 7:
        return OrderDetailsStatus.deliveryCanceled;
      default:
        throw Exception('order details status not recognized');
    }
  }
}

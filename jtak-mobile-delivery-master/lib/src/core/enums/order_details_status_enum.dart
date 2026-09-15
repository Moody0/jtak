import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';

enum OrderDetailsStatus {
  pending,
  merchantAccepted,
  shipping,
  delivered,
  merchantRejected,
  customerPending,
  customerCanceled,
  deliveryCanceled,
  readyForPickup,
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
        return 'تم الإلغاء من قبل التوصيل';
      case OrderDetailsStatus.readyForPickup:
        return 'جاهز للاستلام';
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
      case 8:
        return OrderDetailsStatus.readyForPickup;
      default:
        // An unrecognized backend status code must never be silently
        // treated as a terminal cancellation; fall back to the safe,
        // still-active default like OrderStatus.parseOrderStatus does.
        return OrderDetailsStatus.pending;
    }
  }
}

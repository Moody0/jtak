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
        return str.app.orderDetailsStatusDeliveryCanceled;
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
        return OrderDetailsStatus.pending;
    }
  }
}

OrderDetailsStatus parseOrderDetailsStatusSafe(dynamic val) {
  if (val == null) return OrderDetailsStatus.pending;
  if (val is OrderDetailsStatus) return val;
  if (val is int) return val.parseOrderDetailsStatus;
  if (val is num) return val.toInt().parseOrderDetailsStatus;
  if (val is String) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null) return parsed.parseOrderDetailsStatus;
    final s = val.trim().toLowerCase();
    switch (s) {
      case 'pending':
        return OrderDetailsStatus.pending;
      case 'merchantaccepted':
        return OrderDetailsStatus.merchantAccepted;
      case 'shipping':
        return OrderDetailsStatus.shipping;
      case 'delivered':
        return OrderDetailsStatus.delivered;
      case 'merchantrejected':
        return OrderDetailsStatus.merchantRejected;
      case 'customerpending':
        return OrderDetailsStatus.customerPending;
      case 'customercanceled':
        return OrderDetailsStatus.customerCanceled;
      case 'deliverycanceled':
        return OrderDetailsStatus.deliveryCanceled;
      case 'readyforpickup':
        return OrderDetailsStatus.readyForPickup;
      default:
        return OrderDetailsStatus.pending;
    }
  }
  return OrderDetailsStatus.pending;
}

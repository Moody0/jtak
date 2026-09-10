import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';

enum OrderStatus { pending, success }

extension StringValueExtention on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.pending:
        return str.app.orderStatusPending;

      case OrderStatus.success:
        return str.app.orderStatusSuccess;

      default:
        return '';
    }
  }
}

extension ParseEnumExtention on int {
  OrderStatus get parseOrderStatus {
    switch (this) {
      case 0:
        return OrderStatus.pending;
      case 1:
        return OrderStatus.success;

      default:
        return OrderStatus.pending;
    }
  }
}

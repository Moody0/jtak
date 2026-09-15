import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';

enum OrderStatus { pending, success }

extension StringValueExtention on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.pending:
        return str.app.orderStatusPending;

      case OrderStatus.success:
        return str.app.orderStatusSuccess;
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

OrderStatus parseOrderStatusSafe(dynamic val) {
  if (val == null) return OrderStatus.pending;
  if (val is OrderStatus) return val;
  if (val is int) return val.parseOrderStatus;
  if (val is num) return val.toInt().parseOrderStatus;
  if (val is String) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null) return parsed.parseOrderStatus;
    final s = val.trim().toLowerCase();
    if (s == 'success' || s == '1') return OrderStatus.success;
    return OrderStatus.pending;
  }
  return OrderStatus.pending;
}

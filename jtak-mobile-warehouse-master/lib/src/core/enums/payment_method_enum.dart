import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';

enum PaymentMethod { payOnDelivery, creditCardPayment }

extension StringValueExtention on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.payOnDelivery:
        return str.app.payOnDelivery;

      case PaymentMethod.creditCardPayment:
        return str.app.creditCardPayment;
    }
  }
}

extension ParseEnumExtention on int {
  PaymentMethod get parsePaymentMethod {
    switch (this) {
      case 0:
        return PaymentMethod.payOnDelivery;
      case 1:
        return PaymentMethod.creditCardPayment;

      default:
        return PaymentMethod.payOnDelivery;
    }
  }
}

PaymentMethod parsePaymentMethodSafe(dynamic val) {
  if (val == null) return PaymentMethod.payOnDelivery;
  if (val is PaymentMethod) return val;
  if (val is int) return val.parsePaymentMethod;
  if (val is num) return val.toInt().parsePaymentMethod;
  if (val is String) {
    final s = val.trim().toLowerCase();
    if (s == '0' || s.contains('delivery') || s.contains('cash') || s.contains('كاش') || s.contains('استلام')) {
      return PaymentMethod.payOnDelivery;
    }
    if (s == '1' || s == '2' || s.contains('credit') || s.contains('card') || s.contains('electronic') || s.contains('online') || s.contains('إلكتروني')) {
      return PaymentMethod.creditCardPayment;
    }
    final parsed = int.tryParse(s);
    if (parsed != null) return parsed.parsePaymentMethod;
  }
  return PaymentMethod.payOnDelivery;
}

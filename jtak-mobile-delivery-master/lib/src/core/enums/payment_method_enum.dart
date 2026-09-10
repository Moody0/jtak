import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';

enum PaymentMethod { payOnDelivery, creditCardPayment }

extension StringValueExtention on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.payOnDelivery:
        return str.app.payOnDelivery;

      case PaymentMethod.creditCardPayment:
        return str.app.creditCardPayment;

      default:
        return '';
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

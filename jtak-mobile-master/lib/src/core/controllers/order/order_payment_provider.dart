import 'package:jtek_app/src/core/enums/payment_method_enum.dart';

class OrderPaymentProvider {
  PaymentMethod paymentMethod = PaymentMethod.payOnDelivery;
  String? nameOnCard, month, year, cvc, number;
}

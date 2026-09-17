import 'package:flutter_test/flutter_test.dart';
import 'package:app_jtak_delivery/src/utils/utilities/phone_helper.dart';
import 'package:app_jtak_delivery/src/core/models/order_model.dart';
import 'package:app_jtak_delivery/src/core/models/merchant_order_details.dart';
import 'package:app_jtak_delivery/src/core/enums/order_details_status_enum.dart';
import 'package:app_jtak_delivery/src/core/enums/payment_method_enum.dart';

void main() {
  group('PhoneHelper - Syrian Phone & WhatsApp Normalization', () {
    test('Converts Eastern Arabic and Persian numerals to Western digits', () {
      expect(PhoneHelper.cleanDigits('٠٩٣٣١٢٣٤٥٦'), equals('0933123456'));
      expect(PhoneHelper.cleanDigits('۰۹۸۷۶۵۴۳۲۱'), equals('0987654321'));
      expect(PhoneHelper.cleanDigits('+٩٦٣ (٩٣٣) ١٢-٣٤-٥٦'), equals('+963933123456'));
    });

    test('Strips non-phone characters correctly', () {
      expect(PhoneHelper.cleanDigits('  +963 933 123 456  '), equals('+963933123456'));
      expect(PhoneHelper.cleanDigits('0933-123-456'), equals('0933123456'));
      expect(PhoneHelper.cleanDigits(null), equals(''));
    });

    test('Formats Syrian local numbers for WhatsApp (wa.me/9639...)', () {
      expect(PhoneHelper.formatForWhatsApp('0985615705'), equals('963985615705'));
      expect(PhoneHelper.formatForWhatsApp('985615705'), equals('963985615705'));
      expect(PhoneHelper.formatForWhatsApp('+963985615705'), equals('963985615705'));
      expect(PhoneHelper.formatForWhatsApp('00963985615705'), equals('963985615705'));
      expect(PhoneHelper.formatForWhatsApp('٠٩٨٥٦١٥٧٠٥'), equals('963985615705'));
    });

    test('Formats Syrian phone numbers for direct tel: dialing', () {
      expect(PhoneHelper.formatForCalling('0985615705'), equals('tel:0985615705'));
      expect(PhoneHelper.formatForCalling('+963985615705'), equals('tel:+963985615705'));
      expect(PhoneHelper.formatForCalling('٠٩٨٥٦١٥٧٠٥'), equals('tel:0985615705'));
    });
  });

  group('OrderModel - Delivery Lifecycle & State Machine', () {
    test('Order with readyForPickup items requires driver pickup first', () {
      final order = OrderModel(
        id: 101,
        address: 'Damascus, Mezzeh',
        paymentMethod: PaymentMethod.payOnDelivery,
        orderDetails: [
          MerchentOrderDetailsModel(
            merchantId: 1,
            merchantTitle: 'Restaurant Al-Sham',
            orderDetailStatus: OrderDetailsStatus.readyForPickup,
          ),
        ],
      );

      expect(order.deliveryStatus, equals(OrderDetailsStatus.readyForPickup));
      expect(order.canDeliverToCustomer, isFalse);
      expect(order.hasPendingPickups, isTrue);
      expect(order.isDelivered, isFalse);
      expect(order.isCanceled, isFalse);
      expect(order.isTerminal, isFalse);
      expect(order.isCod, isTrue);
    });

    test('Order with all items in shipping state enables customer drop-off PoD', () {
      final order = OrderModel(
        id: 102,
        address: 'Damascus, Malki',
        paymentMethod: PaymentMethod.creditCardPayment,
        orderDetails: [
          MerchentOrderDetailsModel(
            merchantId: 1,
            merchantTitle: 'Cafe Vienna',
            orderDetailStatus: OrderDetailsStatus.shipping,
          ),
        ],
      );

      expect(order.deliveryStatus, equals(OrderDetailsStatus.shipping));
      expect(order.canDeliverToCustomer, isTrue);
      expect(order.hasPendingPickups, isFalse);
      expect(order.isDelivered, isFalse);
      expect(order.isTerminal, isFalse);
      expect(order.isCod, isFalse); // Credit card is prepaid
    });

    test('Multi-merchant order requires ALL active stores picked up before customer delivery', () {
      final order = OrderModel(
        id: 103,
        address: 'Damascus, Abu Rummaneh',
        paymentMethod: PaymentMethod.payOnDelivery,
        orderDetails: [
          MerchentOrderDetailsModel(
            merchantId: 1,
            merchantTitle: 'Bakery Al-Naim',
            orderDetailStatus: OrderDetailsStatus.shipping, // Store 1 picked up
          ),
          MerchentOrderDetailsModel(
            merchantId: 2,
            merchantTitle: 'Sweet Shop',
            orderDetailStatus: OrderDetailsStatus.readyForPickup, // Store 2 still waiting
          ),
        ],
      );

      expect(order.totalMerchantsCount, equals(2));
      expect(order.pickedUpMerchantsCount, equals(1));
      expect(order.canDeliverToCustomer, isFalse);
      expect(order.hasPendingPickups, isTrue);
      expect(order.nextPendingMerchant?.merchantTitle, equals('Sweet Shop'));
      expect(order.deliveryStatus, equals(OrderDetailsStatus.readyForPickup));
    });

    test('Multi-merchant order enables delivery once all merchants are picked up', () {
      final order = OrderModel(
        id: 104,
        address: 'Damascus, Abu Rummaneh',
        paymentMethod: PaymentMethod.payOnDelivery,
        orderDetails: [
          MerchentOrderDetailsModel(
            merchantId: 1,
            merchantTitle: 'Bakery Al-Naim',
            orderDetailStatus: OrderDetailsStatus.shipping,
          ),
          MerchentOrderDetailsModel(
            merchantId: 2,
            merchantTitle: 'Sweet Shop',
            orderDetailStatus: OrderDetailsStatus.shipping,
          ),
        ],
      );

      expect(order.totalMerchantsCount, equals(2));
      expect(order.pickedUpMerchantsCount, equals(2));
      expect(order.canDeliverToCustomer, isTrue);
      expect(order.hasPendingPickups, isFalse);
      expect(order.deliveryStatus, equals(OrderDetailsStatus.shipping));
    });

    test('Delivered order is marked as terminal and completed', () {
      final order = OrderModel(
        id: 105,
        address: 'Damascus, Shaalan',
        orderDetails: [
          MerchentOrderDetailsModel(
            merchantId: 1,
            merchantTitle: 'Supermarket',
            orderDetailStatus: OrderDetailsStatus.delivered,
          ),
        ],
      );

      expect(order.deliveryStatus, equals(OrderDetailsStatus.delivered));
      expect(order.isDelivered, isTrue);
      expect(order.isTerminal, isTrue);
      expect(order.canDeliverToCustomer, isFalse);
      expect(order.hasPendingPickups, isFalse);
    });

    test('Cancelled order is terminal and not deliverable', () {
      final order = OrderModel(
        id: 106,
        address: 'Damascus, Dummar',
        orderDetails: [
          MerchentOrderDetailsModel(
            merchantId: 1,
            merchantTitle: 'Pharmacy',
            orderDetailStatus: OrderDetailsStatus.deliveryCanceled,
          ),
        ],
      );

      expect(order.deliveryStatus, equals(OrderDetailsStatus.deliveryCanceled));
      expect(order.isCanceled, isTrue);
      expect(order.isTerminal, isTrue);
      expect(order.canDeliverToCustomer, isFalse);
    });
  });
}

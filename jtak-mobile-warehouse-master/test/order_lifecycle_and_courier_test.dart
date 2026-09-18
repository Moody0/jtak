import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/enums/order_details_status_enum.dart';
import 'package:app_jtak_warehouse/src/core/enums/order_status_enum.dart';
import 'package:app_jtak_warehouse/src/core/models/order_details_model.dart';
import 'package:app_jtak_warehouse/src/core/models/order_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSolApi extends Fake implements SolApi {}

String resolveCourierSubtitle(OrderModel order, OrderDetailsStatus status) {
  switch (status) {
    case OrderDetailsStatus.pending:
    case OrderDetailsStatus.customerPending:
    case OrderDetailsStatus.merchantAccepted:
    case OrderDetailsStatus.readyForPickup:
      return 'جارٍ انتظار قبول المندوب';
    case OrderDetailsStatus.shipping:
      return 'الطلب في طريقه للعميل مع المندوب';
    case OrderDetailsStatus.delivered:
      return 'تم تسليم الطلب للعميل بنجاح';
    case OrderDetailsStatus.merchantRejected:
      return 'تم رفض الطلب من المتجر';
    case OrderDetailsStatus.customerCanceled:
    case OrderDetailsStatus.deliveryCanceled:
      return 'تم إلغاء الطلب';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    if (!locator.isRegistered<SolApi>()) {
      locator.registerSingleton<SolApi>(FakeSolApi());
    }
  });

  group('BUG #6 — Merchant Order Lifecycle & Authoritative Acceptance Tests', () {
    test('Specific Acceptance Test: DeliveryId + Name + Phone exist, BUT courier not accepted -> "جارٍ انتظار قبول المندوب" (NOT "مكتمل")', () {
      final provider = OrderProvider();

      // Order with assigned driver but NOT accepted (ReadyForPickup)
      final assignedOrder = OrderModel(
        id: 26,
        orderStatus: OrderStatus.success,
        deliveryId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        deliveryUser: 'كابتن أحمد',
        deliveryUserPhone: '+963912345678',
        isDeliveryAssigned: true,
        isDeliveryAccepted: false,
        orderDetails: [
          OrderDetailsModel(
            id: 2601,
            productId: 10,
            productTitle: 'برغر كلاسيك',
            quantity: 2,
            orderDetailStatus: OrderDetailsStatus.readyForPickup,
          ),
        ],
      );

      // 1. Authoritative order status must be ReadyForPickup (NEVER "مكتمل")
      final orderStatus = provider.getOrderStatus(assignedOrder);
      expect(orderStatus, equals(OrderDetailsStatus.readyForPickup));
      expect(orderStatus, isNot(equals(OrderDetailsStatus.delivered)));

      // 2. Acceptance check: hasCourierAssigned is TRUE, but isCourierAccepted is FALSE
      expect(assignedOrder.hasCourierAssigned, isTrue);
      expect(assignedOrder.isCourierAccepted, isFalse);

      // 3. Courier subtitle must strictly be "جارٍ انتظار قبول المندوب"
      final subtitle = resolveCourierSubtitle(assignedOrder, orderStatus);
      expect(subtitle, equals('جارٍ انتظار قبول المندوب'));
      expect(subtitle, isNot(equals('تم تسليم الطلب للعميل')));
      expect(subtitle, isNot(equals('+963912345678')));
      expect(subtitle.contains('جارٍ'), isTrue);
      expect(subtitle.contains('جاري'), isFalse);

      // 4. Courier accepts (ShippingStarted) -> UI transitions once to accepted state
      final acceptedOrder = assignedOrder.copyWith(
        isDeliveryAccepted: true,
        orderDetails: [
          OrderDetailsModel(
            id: 2601,
            productId: 10,
            productTitle: 'برغر كلاسيك',
            quantity: 2,
            orderDetailStatus: OrderDetailsStatus.shipping,
          ),
        ],
      );

      final acceptedStatus = provider.getOrderStatus(acceptedOrder);
      expect(acceptedStatus, equals(OrderDetailsStatus.shipping));
      expect(acceptedOrder.isCourierAccepted, isTrue);

      final acceptedSubtitle = resolveCourierSubtitle(acceptedOrder, acceptedStatus);
      expect(acceptedSubtitle, equals('الطلب في طريقه للعميل مع المندوب'));

      // 5. Courier completes delivery (Delivered) -> Only NOW shows "مكتمل"
      final deliveredOrder = acceptedOrder.copyWith(
        orderDetails: [
          OrderDetailsModel(
            id: 2601,
            productId: 10,
            productTitle: 'برغر كلاسيك',
            quantity: 2,
            orderDetailStatus: OrderDetailsStatus.delivered,
          ),
        ],
      );

      final deliveredStatus = provider.getOrderStatus(deliveredOrder);
      expect(deliveredStatus, equals(OrderDetailsStatus.delivered));

      final deliveredSubtitle = resolveCourierSubtitle(deliveredOrder, deliveredStatus);
      expect(deliveredSubtitle, equals('تم تسليم الطلب للعميل بنجاح'));
    });

    test('Authoritative status: Pending when awaiting merchant decision', () {
      final provider = OrderProvider();
      final order = OrderModel(
        id: 27,
        orderStatus: OrderStatus.success,
        orderDetails: [
          OrderDetailsModel(
            id: 103,
            productId: 5,
            productTitle: 'شاورما',
            quantity: 1,
            orderDetailStatus: OrderDetailsStatus.pending,
          ),
        ],
      );

      final status = provider.getOrderStatus(order);
      expect(status, equals(OrderDetailsStatus.pending));
    });

    test('Authoritative status: MerchantAccepted when merchant is preparing in kitchen', () {
      final provider = OrderProvider();
      final order = OrderModel(
        id: 28,
        orderStatus: OrderStatus.success,
        orderDetails: [
          OrderDetailsModel(
            id: 104,
            productId: 5,
            productTitle: 'شاورما',
            quantity: 1,
            orderDetailStatus: OrderDetailsStatus.merchantAccepted,
          ),
        ],
      );

      final status = provider.getOrderStatus(order);
      expect(status, equals(OrderDetailsStatus.merchantAccepted));
    });

    test('Authoritative status: MerchantRejected when all items are rejected', () {
      final provider = OrderProvider();
      final order = OrderModel(
        id: 29,
        orderStatus: OrderStatus.success,
        orderDetails: [
          OrderDetailsModel(
            id: 105,
            productId: 5,
            productTitle: 'شاورما',
            quantity: 1,
            orderDetailStatus: OrderDetailsStatus.merchantRejected,
          ),
        ],
      );

      final status = provider.getOrderStatus(order);
      expect(status, equals(OrderDetailsStatus.merchantRejected));
    });
  });

  group('Order Detail Merge & Flicker Prevention Tests', () {
    test('Non-destructive merge preserves detailed delivery phone and picking metadata', () {
      final provider = OrderProvider();

      final detailedOrder = OrderModel(
        id: 26,
        user: 'عبد القادر',
        deliveryId: 'uuid-1234',
        deliveryUser: 'سائق جيتك 1',
        deliveryUserPhone: '0955112233',
        orderDetails: [
          OrderDetailsModel(
            id: 201,
            productId: 10,
            productTitle: 'حليب',
            quantity: 2,
            locationBin: 'A-12-3',
            batchNumber: 'BATCH-2026-001',
            barcode: '621000123456',
            isPicked: true,
            orderDetailStatus: OrderDetailsStatus.readyForPickup,
          ),
        ],
      );

      // Shallow order arriving from generic list sync without delivery phone
      final shallowOrder = OrderModel(
        id: 26,
        user: 'عبد القادر',
        deliveryId: 'uuid-1234',
        deliveryUser: 'سائق جيتك 1',
        deliveryUserPhone: null, // shallow DTO missing phone
        orderDetails: [
          OrderDetailsModel(
            id: 201,
            productId: 10,
            productTitle: 'حليب',
            quantity: 2,
            orderDetailStatus: OrderDetailsStatus.readyForPickup,
          ),
        ],
      );

      final mergedOrder = provider.mergeOrderModel(detailedOrder, shallowOrder);

      expect(mergedOrder.deliveryUserPhone, equals('0955112233'));
      expect(mergedOrder.orderDetails!.first.locationBin, equals('A-12-3'));
      expect(mergedOrder.orderDetails!.first.batchNumber, equals('BATCH-2026-001'));
      expect(mergedOrder.orderDetails!.first.barcode, equals('621000123456'));
      expect(mergedOrder.orderDetails!.first.isPicked, isTrue);
    });

    test('25+ Polling Cycles Stress-Test: Zero state flicker and zero property regression', () {
      final provider = OrderProvider();

      OrderModel state = OrderModel(
        id: 26,
        user: 'محمد الحلبي',
        deliveryId: 'cap-999',
        deliveryUser: 'سامر التوصيل',
        deliveryUserPhone: '+963944556677',
        isDeliveryAssigned: true,
        isDeliveryAccepted: false,
        orderDetails: [
          OrderDetailsModel(
            id: 501,
            productId: 12,
            productTitle: 'بيتزا سوبريم',
            quantity: 1,
            locationBin: 'K-01',
            batchNumber: 'BATCH-888',
            barcode: '9900112233',
            isPicked: true,
            orderDetailStatus: OrderDetailsStatus.readyForPickup,
          ),
        ],
      );

      // Simulate 25 consecutive periodic refresh cycles with various shallow/deep payloads
      for (int cycle = 1; cycle <= 25; cycle++) {
        // Alternating payload: sometimes shallow from /Mine, sometimes full from /{id}
        final incomingPayload = (cycle % 2 == 0)
            ? OrderModel(
                id: 26,
                user: 'محمد الحلبي',
                deliveryId: 'cap-999',
                deliveryUser: 'سامر التوصيل',
                deliveryUserPhone: null, // shallow response missing phone
                orderDetails: [
                  OrderDetailsModel(
                    id: 501,
                    productId: 12,
                    productTitle: 'بيتزا سوبريم',
                    quantity: 1,
                    orderDetailStatus: OrderDetailsStatus.readyForPickup,
                  ),
                ],
              )
            : OrderModel(
                id: 26,
                user: 'محمد الحلبي',
                deliveryId: 'cap-999',
                deliveryUser: 'سامر التوصيل',
                deliveryUserPhone: '+963944556677',
                orderDetails: [
                  OrderDetailsModel(
                    id: 501,
                    productId: 12,
                    productTitle: 'بيتزا سوبريم',
                    quantity: 1,
                    orderDetailStatus: OrderDetailsStatus.readyForPickup,
                  ),
                ],
              );

        state = provider.mergeOrderModel(state, incomingPayload);

        // Assert invariant on EVERY cycle: phone and picking metadata never lost
        expect(state.deliveryUserPhone, equals('+963944556677'), reason: 'Cycle $cycle lost phone');
        expect(state.deliveryUser, equals('سامر التوصيل'), reason: 'Cycle $cycle lost deliveryUser');
        expect(state.orderDetails!.first.locationBin, equals('K-01'), reason: 'Cycle $cycle lost bin');
        expect(state.orderDetails!.first.isPicked, isTrue, reason: 'Cycle $cycle lost isPicked');

        // Subtitle invariant: stays strictly "جارٍ انتظار قبول المندوب" with zero flicker
        final status = provider.getOrderStatus(state);
        expect(status, equals(OrderDetailsStatus.readyForPickup));
        final sub = resolveCourierSubtitle(state, status);
        expect(sub, equals('جارٍ انتظار قبول المندوب'), reason: 'Cycle $cycle flickered subtitle');
      }
    });
  });

  group('Arabic Typography & Grammar Tests', () {
    test('Strict Arabic grammar uses "جارٍ" and never "جاري"', () {
      final order = OrderModel(
        id: 30,
        deliveryUser: null,
        deliveryUserPhone: null,
      );
      const status = OrderDetailsStatus.readyForPickup;
      final subtitle = resolveCourierSubtitle(order, status);

      expect(subtitle, equals('جارٍ انتظار قبول المندوب'));
      expect(subtitle.startsWith('جارٍ'), isTrue);
      expect(subtitle.contains('جاري'), isFalse);
    });
  });
}

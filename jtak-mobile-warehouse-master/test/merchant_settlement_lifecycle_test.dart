import 'package:app_jtak_warehouse/src/core/models/payment_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BUG #7 — Merchant Settlement Accounting Lifecycle Tests', () {
    test('PaymentModel correctly maps approved settlement request (Awaiting Merchant Receipt)', () {
      final json = {
        'id': 'f27a3200-0000-0000-0000-000000000000',
        'requestNumber': 'SET-20260917184759-F27A32',
        'status': 1, // Approved
        'requestedByUserId': 'u123',
        'requestedByName': 'محطة اللحوم',
        'amount': 1125.0,
        'currency': 'SYP',
        'method': 'نقدي بالفرع',
        'accountDetails': 'كاشير المحل',
        'reviewedByAdminId': 'a999',
        'reviewedAt': '2026-09-17T18:50:00.000Z',
        'completedAt': null,
        'createdDate': '2026-09-17T18:47:59.000Z',
      };

      final model = PaymentModel.fromSettlementRequest(json);

      expect(model.isSettlementRequest, isTrue);
      expect(model.requestId, 'f27a3200-0000-0000-0000-000000000000');
      expect(model.requestNumber, 'SET-20260917184759-F27A32');
      expect(model.amount, 1125.0);
      expect(model.status, 1);
      expect(model.isApprovedPendingReceipt, isTrue);
      expect(model.isReceived, isFalse);
      expect(model.handoverDate, isNull);
    });

    test('PaymentModel correctly maps completed settlement request (Physically Received)', () {
      final json = {
        'id': 'f27a3200-0000-0000-0000-000000000000',
        'requestNumber': 'SET-20260917184759-F27A32',
        'status': 3, // Completed
        'requestedByUserId': 'u123',
        'requestedByName': 'محطة اللحوم',
        'amount': 1125.0,
        'currency': 'SYP',
        'method': 'نقدي بالفرع',
        'accountDetails': 'كاشير المحل',
        'reviewedByAdminId': 'a999',
        'reviewedAt': '2026-09-17T18:50:00.000Z',
        'completedAt': '2026-09-17T19:00:00.000Z',
        'createdDate': '2026-09-17T18:47:59.000Z',
      };

      final model = PaymentModel.fromSettlementRequest(json);

      expect(model.isSettlementRequest, isTrue);
      expect(model.status, 3);
      expect(model.isApprovedPendingReceipt, isFalse);
      expect(model.isReceived, isTrue);
      expect(model.handoverDate, '2026-09-17T19:00:00.000Z');
      expect(model.completedAt, '2026-09-17T19:00:00.000Z');
    });

    test('Settlement Filter Tab 1: "قيد التسليم (تحتاج تأكيد)" shows approved unreceived settlements', () {
      final approvedReq = PaymentModel(
        requestId: 'req-1',
        requestNumber: 'SET-20260917184759-F27A32',
        status: 1, // Approved
        amount: 1125.0,
        handoverDate: null,
      );

      final pendingReviewReq = PaymentModel(
        requestId: 'req-2',
        requestNumber: 'SET-20260917184759-AAAAAA',
        status: 0, // Pending Review
        amount: 5000.0,
        handoverDate: null,
      );

      final completedReq = PaymentModel(
        requestId: 'req-3',
        requestNumber: 'SET-20260917184759-BBBBBB',
        status: 3, // Completed
        amount: 10000.0,
        handoverDate: '2026-09-17T19:00:00.000Z',
      );

      final rejectedReq = PaymentModel(
        requestId: 'req-4',
        requestNumber: 'SET-20260917184759-CCCCCC',
        status: 2, // Rejected
        amount: 2500.0,
        handoverDate: null,
      );

      final all = [approvedReq, pendingReviewReq, completedReq, rejectedReq];

      // Tab 1 filter logic:
      final tab1List = all.where((p) {
        if (p.isReceived) return false;
        if (p.isSettlementRequest && !p.isApprovedPendingReceipt) return false;
        return true;
      }).toList();

      expect(tab1List.length, 1);
      expect(tab1List.first.requestNumber, 'SET-20260917184759-F27A32');
    });

    test('Settlement Filter Tab 2: "تم الاستلام" shows completed and received settlements only', () {
      final approvedReq = PaymentModel(
        requestId: 'req-1',
        requestNumber: 'SET-20260917184759-F27A32',
        status: 1, // Approved
        amount: 1125.0,
        handoverDate: null,
      );

      final completedReq = PaymentModel(
        requestId: 'req-3',
        requestNumber: 'SET-20260917184759-BBBBBB',
        status: 3, // Completed
        amount: 10000.0,
        handoverDate: '2026-09-17T19:00:00.000Z',
      );

      final legacyCompleted = PaymentModel(
        id: 42,
        amount: 500.0,
        handoverDate: '2026-09-10T12:00:00.000Z',
      );

      final all = [approvedReq, completedReq, legacyCompleted];

      // Tab 2 filter logic:
      final tab2List = all.where((p) => p.isReceived).toList();

      expect(tab2List.length, 2);
      expect(tab2List.map((e) => e.displayId), containsAll(['SET-20260917184759-BBBBBB', '#42']));
    });
  });
}

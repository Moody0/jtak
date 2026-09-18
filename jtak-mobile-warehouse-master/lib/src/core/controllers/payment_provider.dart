import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/payment_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';

class PaymentProvider extends BaseProvider<PaymentModel> {
  final SolApi _api = locator<SolApi>();

  /// Clear all cached payment records on account switch or logout
  void reset() {
    dataList.clear();
    notifyListeners();
  }

  Future loadPayments() async {
    await loadInfinityData(
      loadData: (page) async {
        if (page > 0) return <PaymentModel>[];

        final items = <PaymentModel>[];

        // 1. Load modern double-entry Settlement Requests
        try {
          final requests = await _api.getRequest('/Balances/SettlementRequests');
          if (requests is List) {
            for (final r in requests) {
              if (r is Map) {
                items.add(PaymentModel.fromSettlementRequest(Map<String, dynamic>.from(r)));
              }
            }
          }
        } catch (_) {}

        // 2. Load legacy payments if any exist
        try {
          Map body = {'pageNumber': 0, "pageSize": 50, "sortField": "id", "sortOrder": "desc"};
          var res = await _api.postRequest('/Payments/Mine', body);
          if (res != null && res is Map && res['items'] is List) {
            List legacy = res['items'];
            for (final l in legacy) {
              if (l is Map) {
                items.add(PaymentModel.fromMap(Map<String, dynamic>.from(l)));
              }
            }
          }
        } catch (_) {}

        // 3. Sort newest first
        items.sort((a, b) {
          final aDate = a.createdDate ?? a.handoverDate ?? '';
          final bDate = b.createdDate ?? b.handoverDate ?? '';
          return bDate.compareTo(aDate);
        });

        return items;
      },
    );
  }

  Future<bool> confirmSettlementReceipt(String requestId) async {
    bool success = false;
    await loadBaseData(loadBody: () async {
      var res = await _api.postRequest('/Balances/SettlementRequests/$requestId/ConfirmReceipt', {});
      if (res != null) {
        success = true;
        final index = dataList.indexWhere((element) => element.requestId == requestId);
        if (index != -1) {
          final now = DateTime.now().toUtc().toIso8601String();
          dataList[index].status = 3; // Completed
          dataList[index].handoverDate = now;
          dataList[index].completedAt = now;
        }
      }
    });
    notifyListeners();
    return success;
  }

  Future<bool> recivePayment(int id) async {
    bool success = false;
    await loadBaseData(loadBody: () async {
      var res = await _api.postRequest('/Payments/RecivePayment/$id', {});
      if (res != null) {
        success = true;
        final index = dataList.indexWhere((element) => element.id == id);
        if (index != -1) {
          dataList[index].handoverDate = DateTime.now().toUtc().toIso8601String();
        }
      }
    });
    notifyListeners();
    return success;
  }
}

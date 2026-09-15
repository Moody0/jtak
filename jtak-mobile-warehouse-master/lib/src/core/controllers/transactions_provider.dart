import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/balances_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';

class TransactionsProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  BalancesModel balances = BalancesModel();
  List<Map<String, dynamic>> settlementRequests = [];

  Future loadBalances() async {
    await loadBaseData(loadBody: () async {
      var summaryLoaded = false;
      try {
        var res = await _api.getRequest('/Balances/Summary');
        if (res != null && res is Map) {
          balances = BalancesModel.fromMap(Map<String, dynamic>.from(res));
          summaryLoaded = true;
        }
      } catch (_) {}

      try {
        final requests = await _api.getRequest('/Balances/SettlementRequests');
        if (requests is List) {
          settlementRequests = requests.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (_) {}

      // Fallback to legacy endpoint
      if (summaryLoaded) return;
      try {
        var resFallback = await _api.postRequest('/Balances/Mine', {});
        if (resFallback != null && resFallback is Map) {
          balances = BalancesModel.fromMap(Map<String, dynamic>.from(resFallback));
        }
      } catch (_) {}
    });
    notifyListeners();
  }

  Future<Map<String, dynamic>?> submitSettlementRequest({
    required double amount,
    required String method,
    required String accountDetails,
    String? notes,
  }) async {
    final body = {
      'amount': amount,
      'method': method,
      'accountDetails': accountDetails,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    final res = await _api.postRequest('/Balances/RequestSettlement', body);
    if (res != null && res is Map) {
      await loadBalances();
      return Map<String, dynamic>.from(res);
    }
    return null;
  }
}

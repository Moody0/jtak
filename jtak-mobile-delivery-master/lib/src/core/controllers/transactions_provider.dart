import 'package:app_jtak_delivery/src/utils/providers/sol_api.dart';
import 'package:app_jtak_delivery/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_delivery/src/core/models/balances_model.dart';
import 'package:app_jtak_delivery/src/core/services/locator.dart';

class TransactionsProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  BalancesModel balances = BalancesModel();

  Future<void> loadBalances() async {
    await loadBaseData(loadBody: () async {
      var res = await _api.postRequest('/Balances/Mine', {});
      balances = BalancesModel.fromMap(res);
    });
  }

  Future<bool> requestSettlement() async {
    final amount = balances.availableAmount ?? balances.amount ?? 0.0;
    if (amount <= 0) return false;

    final res = await _api.postRequest('/Balances/RequestSettlement', {
      'amount': amount,
      'method': 'cash_to_admin',
      'notes': 'طلب تسوية كامل العهدة النقدية',
    });
    if (res != null) {
      await loadBalances();
      return true;
    }
    return false;
  }
}

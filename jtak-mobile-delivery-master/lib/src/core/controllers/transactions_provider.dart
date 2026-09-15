import 'package:app_jtak_delivery/src/utils/providers/sol_api.dart';
import 'package:app_jtak_delivery/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_delivery/src/core/models/balances_model.dart';
import 'package:app_jtak_delivery/src/core/services/locator.dart';

class TransactionsProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  BalancesModel balances = BalancesModel();

  Future loadBalances() async {
    await loadBaseData(loadBody: () async {
      var res = await _api.postRequest('/Balances/Mine', {});
      balances = BalancesModel.fromMap(res);
    });
  }

  Future<bool> requestSettlement() async {
    final res = await _api.postRequest('/Balances/RequestSettlement', {
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

import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/balances_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';

class TransactionsProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  BalancesModel balances = BalancesModel();

  Future loadBalances() async {
    await loadBaseData(loadBody: () async {
      var res = await _api.postRequest('/Balances/Mine', {});
      balances = BalancesModel.fromMap(res);
    });
  }
}

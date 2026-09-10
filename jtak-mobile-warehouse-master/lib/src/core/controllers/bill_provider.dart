import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/bill_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';

class BillProvider extends BaseProvider<BillModel> {
  final SolApi _api = locator<SolApi>();

  Future loadBills() async {
    await loadInfinityData(
      loadData: (page) async {
        Map body = {'pageNumber': page, "pageSize": 20, "sortField": "id", "sortOrder": "desc"};
        var res = await _api.postRequest('/Bills/Mine', body);
        List data = res['items'];
        return data.map((e) => BillModel.fromMap(e)).toList();
      },
    );
  }
}

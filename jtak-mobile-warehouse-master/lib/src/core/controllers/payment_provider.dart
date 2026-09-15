import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/payment_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';

class PaymentProvider extends BaseProvider<PaymentModel> {
  final SolApi _api = locator<SolApi>();

  Future loadPayments() async {
    await loadInfinityData(
      loadData: (page) async {
        Map body = {'pageNumber': page, "pageSize": 20, "sortField": "id", "sortOrder": "desc"};
        var res = await _api.postRequest('/Payments/Mine', body);
        List data = res['items'];
        return data.map((e) => PaymentModel.fromMap(e)).toList();
      },
    );
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

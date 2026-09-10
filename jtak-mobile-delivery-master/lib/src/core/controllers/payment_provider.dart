import 'package:app_jtak_delivery/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_delivery/src/core/models/payment_model.dart';
import 'package:app_jtak_delivery/src/core/services/locator.dart';
import 'package:app_jtak_delivery/src/utils/providers/sol_api.dart';

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

  Future recivePayment(int id) async {
    await loadBaseData(loadBody: () async {
      await _api.postRequest('/Payments/RecivePayment/$id', {});
      dataList.removeWhere((element) => element.id == id);
    });
  }
}

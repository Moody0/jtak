import '../../services/locator.dart';
import '../app/base_provider.dart';
import '../../models/catalog/product_review_model.dart';
import '../../../utils/providers/sol_api.dart';

class ProductReviewProvider extends BaseProvider<ProductReviewModel> {
  final SolApi _api = locator<SolApi>();

  Future loadData() async {
    await loadBaseData(
      loadBody: () async {
        List data = await _api.getRequest('/ProductReviews/Mine');
        dataList = data.map((e) => ProductReviewModel.fromMap(e)).toList();
      },
    );
  }

  Future save(ProductReviewModel item) async {
    await loadBaseData(
      loadBody: () async {
        await _api.postRequest('/ProductReviews', item.toMap());
      },
    );
  }

  Future delete(int itemId) async {
    await loadBaseData(
      loadBody: () async {
        await _api.deleteRequest('/ProductReviews/$itemId');
        dataList.removeWhere((element) => element.productId == itemId);
      },
    );
  }

  bool find(int productId) {
    for (var element in dataList) {
      if (element.productId == productId) {
        return true;
      }
    }
    return false;
  }
}

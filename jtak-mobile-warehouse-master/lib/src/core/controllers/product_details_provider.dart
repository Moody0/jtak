import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/product_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';

class ProductDetailsProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();

  ProductModel product;
  List<ProductModel> similarProductList = [];

  ProductDetailsProvider(this.product);

  Future loadProductDetails() async {
    return await loadBaseData(
      loadBody: () async {
        var res = await _api.getRequest('/Products/${product.productId}');
        product = ProductModel.fromMap(res);
      },
    );
  }

  bool isProductEmpty() {
    return product.productId != null && !GlobalVar.checkString(product.product) && product.finalPrice != null;
  }
}

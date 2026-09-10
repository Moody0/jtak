import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/product_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/foundation.dart';

class ProductsProvider extends BaseProvider<ProductModel> {
  final SolApi _api = locator<SolApi>();
  String? search;
  List<ProductModel> productList = [];
  int? productCategoryId;

  ValueNotifier<Map<int, double>> newPricesMap = ValueNotifier<Map<int, double>>({});

  Future loadData({int? productCategoryId}) async {
    await loadBaseData(loadBody: () async {
      List data = await _api.getRequest('/Products');
      dataList.clear();
      for (var element in data) {
        dataList.add(ProductModel.fromMap(element));
      }
      productList = dataList;
    });
  }

  Future<void> updateProductPrices() async {
    await loadBaseData(
      loadBody: () async {
        List<Map> body = [];
        newPricesMap.value.forEach((key, value) {
          body.add({'productId': key, 'merchantPrice': value});
        });
        await _api.putRequest('/Products/Prices/', body);
        updateNewPrices();
        newPricesMap.value.clear();
      },
    );
  }

  void updateNewPrices() {
    newPricesMap.value.keys.forEach((productId) {
      ProductModel product = dataList.firstWhere((element) => element.productId == productId);
      product.finalPrice = newPricesMap.value[productId];
    });
  }

  void setNewPrice(ProductModel product, double newPrice) {
    if (newPrice >= 0) {
      newPricesMap.value[product.productId!] = newPrice;
      newPricesMap.notifyListeners();
    }
  }

  void resetPrice(int productId) {
    newPricesMap.value.remove(productId);
    notifyListeners();
  }

  void setSearch(String? value) {
    search = value;
    if (!GlobalVar.checkString(search)) {
      productList = dataList;
    } else {
      List<ProductModel> list = [];
      for (var product in dataList) {
        if (product.product!.toLowerCase().contains(search!.toLowerCase())) list.add(product);
      }
      productList = list;
    }

    notifyListeners();
  }

  // void _getDummyData() {
  //   if (kDebugMode)
  //     productList = dataList = List<ProductModel>.generate(
  //       10,
  //       (index) => ProductModel(
  //         productId: index,
  //         merchantId: 18,
  //         price: 55,
  //         finalPrice: 50,
  //         product: 'product name',
  //       ),
  //     );
  // }

  @override
  void dispose() {
    newPricesMap.dispose();
    super.dispose();
  }
}

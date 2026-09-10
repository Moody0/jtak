import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/models/user/address_model.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';
import '../../services/locator.dart';
import '../../enums/viewstate.dart';
import '../app/base_provider.dart';
import '../../models/catalog/product_model.dart';
import '../../../utils/providers/sol_api.dart';

class ProductDetailsProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();

  ProductModel product;
  List<ProductModel> similarProductList = [];

  ProductDetailsProvider(this.product);

  Future loadProductDetails() async {
    try {
      setState(ViewState.busy);
      var res = await _api.getRequest('/Products/${product.id}');
      product = ProductModel.fromMap(res);
      loadsimilarProduct();
      setState(ViewState.idle);
    } catch (err) {
      setState(ViewState.idle);
      debugPrint(err.toString());
      rethrow;
    }
  }

  Future loadsimilarProduct() async {
    try {
      similarProductList.clear();
      LatLng? latLng = getLatLng();
      // var data = await _api.getRequest('/Catalog/Products/Search');
      Map body = {
        "take": 10,
        "page": 0,
        "productCategoryId": product.categoryId,
        "lng": latLng?.longitude,
        "lat": latLng?.latitude,
        "q": '',
      };
      var data = await _api.postRequest('/Products/Search', body);
      data.forEach((element) => similarProductList.add(ProductModel.fromMap(element)));
      setState(ViewState.idle);
      // similarProductList = List.generate(8, (index) => getProductDummyData());
    } catch (err) {
      debugPrint(err.toString());
      rethrow;
    }
  }

  String shareProduct() {
    String text = product.title ?? '';
    text += '${SolApi.shareProductUrl}/${product.id}';
    return text;
  }

  bool isProductEmpty() {
    return product.id != null && !GlobalVar.checkString(product.title) && product.finalPrice != null;
  }

  LatLng? getLatLng() {
    AddressModel mainAddress = locator<AppParametersProvider>().mainAddressService.mainAddress;
    return LatLng(mainAddress.lat!, mainAddress.lng!);
  }
}

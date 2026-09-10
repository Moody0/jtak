import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/models/catalog/product_model.dart';
import 'package:jtek_app/src/core/models/user/address_model.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';

import '../../services/locator.dart';
import '../../enums/viewstate.dart';
import '../app/base_provider.dart';
import '../../../utils/providers/sol_api.dart';

class ProductsProvider extends BaseProvider<ProductModel> {
  final SolApi _api = locator<SolApi>();
  AuthenticationService authenticationService = locator<AuthenticationService>();
  List<ProductModel> mostSearchedProduct = [];
  String? search;
  int? productCategoryId;

  Future loadMostSearchedProducts() async {
    resetSetting();
    LatLng? latLng = getLatLng();
    Map body = {
      "take": 3,
      "page": page,
      "productCategoryId": productCategoryId,
      "q": search ?? '',
      "lng": latLng?.longitude,
      "lat": latLng?.latitude,
    };
    List data = await _api.postRequest('/Products/Search', body);
    mostSearchedProduct = [];
    for (var element in data) {
      mostSearchedProduct.add(ProductModel.fromMap(element));
    }
    notifyListeners();
  }

  Future loadNewData({int? productCategoryId}) async {
    setState(ViewState.busy);
    if (this.productCategoryId != productCategoryId) {
      this.productCategoryId = productCategoryId;
    }
    page = 0;
    loadData();
  }

  Future loadData() async {
    try {
      LatLng? latLng = getLatLng();
      await loadInfinityData(
        loadData: (page) async {
          Map body = {
            "page": page,
            "productCategoryId": productCategoryId,
            "q": search ?? '',
            "lng": latLng?.longitude,
            "lat": latLng?.latitude,
          };
          List data = await _api.postRequest('/Products/Search', body);
          List<ProductModel> list = [];
          for (var element in data) {
            list.add(ProductModel.fromMap(element));
          }
          // list = List.generate(20, (index) => getProductDummyData());
          return list;
        },
      );
    } catch (err) {
      rethrow;
    }
  }

  LatLng? getLatLng() {
    AddressModel mainAddress = locator<AppParametersProvider>().mainAddressService.mainAddress;
    return LatLng(mainAddress.lat!, mainAddress.lng!);
  }
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jtek_app/src/config/constants/shard_preference_kay.dart';
import 'package:jtek_app/src/core/controllers/order/cart_provider.dart';
import 'package:jtek_app/src/core/models/user/address_model.dart';
import 'package:jtek_app/src/core/services/location_service.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainAddressService {
  AddressModel _mainAddress = AddressModel();

  bool isAddressEmpty() {
    return _mainAddress.lat == null || _mainAddress.lng == null || !GlobalVar.checkString(_mainAddress.fullAddress);
  }

  bool isCoordinateEmpty() {
    return _mainAddress.lat == null || _mainAddress.lng == null;
  }

  Future checkMainCorrdinate(BuildContext context) async {
    await loadLocal();
    LatLng? latLng;
    try {
      latLng = await LocationService(isMandatory: false)
          .getCurrentLocation()
          .timeout(const Duration(seconds: 3));
    } catch (err) {
      debugPrint('MainAddressService: location permission not granted or disabled ($err)');
    }
    if (latLng != null) {
      try {
        String geocodedAddress = await LocationService.reverseGeocodeCoordinates(
          latLng.latitude,
          latLng.longitude,
        ).timeout(const Duration(seconds: 2));
        AddressModel address = AddressModel(
          lat: latLng.latitude,
          lng: latLng.longitude,
          title: geocodedAddress,
          fullAddress: geocodedAddress,
        );
        await setMainAddress(address, resetCart: false);
      } catch (err) {
        debugPrint('MainAddressService: reverseGeocode error ($err)');
      }
    }
  }

  AddressModel get mainAddress {
    // if (kDebugMode) {
    //   _mainAddress.lat = 37.0667216;
    //   _mainAddress.lng = 37.3718298;
    // }
    return _mainAddress;
  }

  Future setMainAddress(AddressModel address, {bool resetCart = false}) async {
    _mainAddress = address;
    if (resetCart) {
      locator<CartProvider>().resetData();
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(mainAddressKey, _mainAddress.toJson());
  }

  Future loadLocal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(mainAddressKey)) {
      _mainAddress = AddressModel.fromJson(prefs.getString(mainAddressKey) ?? '');
    }
  }

  Future reset() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(mainAddressKey);
    _mainAddress = AddressModel();
  }
}

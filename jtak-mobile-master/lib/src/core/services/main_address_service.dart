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
  VoidCallback? onAddressChanged;

  MainAddressService({this.onAddressChanged});

  bool isAddressEmpty() {
    return _mainAddress.lat == null || _mainAddress.lng == null || !GlobalVar.checkString(_mainAddress.fullAddress);
  }

  bool isCoordinateEmpty() {
    return _mainAddress.lat == null || _mainAddress.lng == null;
  }

  bool _isLoading = false;

  Future checkMainCorrdinate(BuildContext context) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      await loadLocal();
      LatLng? latLng;
      try {
        latLng = await LocationService(isMandatory: false).getCurrentLocation();
      } catch (err) {
        debugPrint('MainAddressService: location error ($err)');
      }

      if (latLng != null) {
        // 1. Immediately reflect coordinates if empty so UI is not stuck on "حدد موقع التوصيل"
        if (isCoordinateEmpty()) {
          _mainAddress = AddressModel(
            lat: latLng.latitude,
            lng: latLng.longitude,
            title: 'موقعك الحالي',
            fullAddress: 'موقعك الحالي',
          );
          onAddressChanged?.call();
        }

        // 2. Reverse geocode to exact human-readable neighborhood/street in Arabic
        try {
          String geocodedAddress = await LocationService.reverseGeocodeCoordinates(
            latLng.latitude,
            latLng.longitude,
          );
          AddressModel address = AddressModel(
            lat: latLng.latitude,
            lng: latLng.longitude,
            title: geocodedAddress,
            fullAddress: geocodedAddress,
          );
          await setMainAddress(address, resetCart: false);
        } catch (err) {
          debugPrint('MainAddressService: reverseGeocode error ($err)');
          if (isCoordinateEmpty() || _mainAddress.title == null || _mainAddress.title!.isEmpty) {
            AddressModel fallback = AddressModel(
              lat: latLng.latitude,
              lng: latLng.longitude,
              title: 'موقعك الحالي',
              fullAddress: 'موقعك الحالي',
            );
            await setMainAddress(fallback, resetCart: false);
          }
        }
      }
    } finally {
      _isLoading = false;
    }
  }

  AddressModel get mainAddress {
    return _mainAddress;
  }

  Future setMainAddress(AddressModel address, {bool resetCart = false}) async {
    _mainAddress = address;
    if (resetCart) {
      locator<CartProvider>().resetData();
    }
    onAddressChanged?.call();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(mainAddressKey, _mainAddress.toJson());
  }

  Future loadLocal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(mainAddressKey)) {
      final jsonStr = prefs.getString(mainAddressKey) ?? '';
      if (jsonStr.isNotEmpty) {
        _mainAddress = AddressModel.fromJson(jsonStr);
        onAddressChanged?.call();
      }
    }
  }

  Future reset() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(mainAddressKey);
    _mainAddress = AddressModel();
    onAddressChanged?.call();
  }
}

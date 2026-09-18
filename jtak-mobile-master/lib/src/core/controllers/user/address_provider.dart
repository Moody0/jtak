import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/enums/address_type_enum.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';

import '../../models/user/address_model.dart';
import '../../services/location_service.dart';
import '../../services/locator.dart';
import '../app/base_provider.dart';
import '../../../utils/providers/sol_api.dart';

class AddressProvider extends BaseProvider<AddressModel> {
  final SolApi _api = locator<SolApi>();
  AddressModel address = AddressModel(id: 0);
  GoogleMapController? controller;
  LatLng cameraPosition = const LatLng(33.5138, 36.2765);
  final double mapZoomLevel = 15.0;
  int stage = 0; // 0 for choose location; 1 for enter title and fullAddress

  String? globalMessage;
  String? lastDeleteError;
  String? locationAddressName;
  bool isGeocodingLocation = false;
  Timer? _geocodeDebounce;

  Future loadData() async {
    await loadBaseData(
      loadBody: () async {
        try {
          if (locator<AuthenticationService>().isLogin()) {
            List data = await _api.getRequest('/Address/Mine');
            dataList = data.map((e) => AddressModel.fromMap(e)).toList();
          } else {
            dataList = [locator<AppParametersProvider>().mainAddressService.mainAddress];
          }
        } catch (e) {
          debugPrint('AddressProvider loadData handled exception: $e');
          dataList = [locator<AppParametersProvider>().mainAddressService.mainAddress];
        }
      },
    );
  }

  AddressModel? getActiveAddress() {
    for (var element in dataList) {
      if (element.isActive ?? false) return element;
    }
    return null;
  }

  Future saveFun() async {
    await loadBaseData(
      loadBody: () async {
        address.id = 0;
        address.userId ??= locator<AuthenticationService>().user?.id;
        address.country ??= 568;
        address.isCompany ??= false;
        address.addressType ??= AddressType.shipping;

        Map<String, dynamic> body = address.toMap();
        address.id = await _api.postRequest('/Address', body);

        await loadData();
      },
    );
  }

  Future<bool> delete(int id) async {
    final originalIndex = dataList.indexWhere((element) => element.id == id);
    if (originalIndex == -1) {
      lastDeleteError = 'العنوان غير موجود';
      return false;
    }

    final removedItem = dataList[originalIndex];
    dataList.removeAt(originalIndex);
    lastDeleteError = null;
    notifyListeners();

    try {
      await loadBaseData(
        loadBody: () async {
          await _api.deleteRequest('/Address/$id');
          await loadData();
        },
      );
      lastDeleteError = null;
      return true;
    } catch (e) {
      debugPrint('AddressProvider delete failed for id $id, rolling back: $e');
      // Rollback: restore address at exact original index
      if (originalIndex <= dataList.length) {
        dataList.insert(originalIndex, removedItem);
      } else {
        dataList.add(removedItem);
      }
      lastDeleteError = 'تعذر حذف العنوان، يرجى المحاولة لاحقاً';
      globalMessage = lastDeleteError;
      notifyListeners();
      return false;
    }
  }

  void mapAnimateToPosision(LatLng latLng) async {
    cameraPosition = latLng;
    if (controller != null) {
      controller!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: cameraPosition, zoom: mapZoomLevel)));
    }
    resolveAddressName(latLng.latitude, latLng.longitude);
  }

  void onCameraMoved(LatLng newPosition) {
    cameraPosition = newPosition;
    isGeocodingLocation = true;
    notifyListeners();
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 350), () {
      resolveAddressName(cameraPosition.latitude, cameraPosition.longitude);
    });
  }

  void onCameraIdle() {
    _geocodeDebounce?.cancel();
    resolveAddressName(cameraPosition.latitude, cameraPosition.longitude);
  }

  Future<void> resolveAddressName(double lat, double lng) async {
    isGeocodingLocation = true;
    notifyListeners();
    try {
      final name = await LocationService.reverseGeocodeCoordinates(lat, lng);
      locationAddressName = name;
      address.fullAddress = name;
    } catch (e) {
      debugPrint('resolveAddressName error: $e');
      locationAddressName = 'الموقع المحدد (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})';
    } finally {
      isGeocodingLocation = false;
      notifyListeners();
    }
  }

  void setStage(int stage) {
    if (this.stage != stage) {
      this.stage = stage;
      notifyListeners();
    }
  }

  void setLocation() {
    address.lat = cameraPosition.latitude;
    address.lng = cameraPosition.longitude;
    if (locationAddressName != null && locationAddressName!.isNotEmpty) {
      address.fullAddress = locationAddressName;
    }
    setStage(1);
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }
}

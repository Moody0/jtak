import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_jtak_delivery/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_delivery/src/core/enums/order_details_status_enum.dart';
import 'package:app_jtak_delivery/src/core/models/order_model.dart';
import 'package:app_jtak_delivery/src/core/services/location_service.dart';
import 'package:app_jtak_delivery/src/core/services/locator.dart';
import 'package:app_jtak_delivery/src/utils/providers/sol_api.dart';
import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';
import 'package:geolocator/geolocator.dart';

class OrderProvider extends BaseProvider<OrderModel> {
  final SolApi _api = locator<SolApi>();
  OrderModel? order;
  StreamSubscription<Position>? _locationSubscription;
  int? _trackingOrderId;
  bool _locationRequestInFlight = false;

  Future<void> startLocationTracking() => _beginLocationSharing();

  Future refreshData() async {
    final selectedId = order?.id;
    page = 0;
    await loadPagedData();
    if (selectedId != null) {
      order = dataList
          .cast<OrderModel?>()
          .firstWhere((item) => item?.id == selectedId, orElse: () => order);
      notifyListeners();
    }
  }

  Future loadPagedData() async {
    await loadInfinityData(
      loadData: (page) async {
        Map body = {
          'pageNumber': page,
          "pageSize": 20,
          "sortField": "id",
          "sortOrder": "desc"
        };
        var res = await _api.postRequest('/Orders/Mine', body);
        List data = res['items'];
        final orders = data.map((e) => OrderModel.fromMap(e)).toList();
        final active = orders.cast<OrderModel?>().firstWhere(
              (item) =>
                  item != null &&
                  getOrderStatus(item) == OrderDetailsStatus.shipping,
              orElse: () => null,
            );
        if (active?.id != null) {
          _beginLocationSharing(active!.id!);
        } else {
          _trackingOrderId = null;
        }
        return orders;
      },
    );
  }

  Future loadOrder(int id) async {
    return await loadBaseData(
      loadBody: () async {
        var data = await _api.getRequest('/Orders/$id');
        order = OrderModel.fromMap(data);
      },
    );
  }

  void setOrderObject(OrderModel orderObject) async {
    order = orderObject;
    if (orderIsEmpty()) {
      await loadOrder(order!.id ?? -1);
    }
  }

  Future startShipping(int orderId, int merchentId) async {
    await loadBaseData(loadBody: () async {
      await _api.postRequest('/Orders/StartShipping/$orderId/$merchentId', {});
      await _beginLocationSharing(orderId);
      await refreshData();
    });
  }

  Future deliverOrder(int orderId) async {
    await loadBaseData(loadBody: () async {
      var location = await LocationService().getCurrentLocation();
      GlobalVar.log(location.toString());
      await _api.postRequest('/Orders/DeliverOrder/$orderId', {});
      await _stopLocationSharing(orderId);
      await refreshData();
    });
  }

  Future cancelOrder(int orderId) async {
    await loadBaseData(loadBody: () async {
      var location = await LocationService().getCurrentLocation();
      GlobalVar.log(location.toString());
      await _api.postRequest('/Orders/cancel/$orderId', {});
      await _stopLocationSharing(orderId);
      await refreshData();
    });
  }

  bool orderIsEmpty() {
    return order == null ||
        !GlobalVar.checkListNotEmpty(order!.orderDetails) ||
        order!.id == null;
  }

  OrderDetailsStatus getOrderStatus(OrderModel order) {
    OrderDetailsStatus status = OrderDetailsStatus.pending;
    if (GlobalVar.checkListNotEmpty(order.orderDetails)) {
      status = order.orderDetails!.first.orderDetailStatus ??
          OrderDetailsStatus.pending;
      for (var element in order.orderDetails!) {
        if (element.orderDetailStatus!.index < status.index) {
          status = element.orderDetailStatus ?? OrderDetailsStatus.pending;
        }
      }
    }
    return status;
  }

  Future<void> _beginLocationSharing([int? orderId]) async {
    if (orderId != null) _trackingOrderId = orderId;
    if (_locationSubscription != null) {
      final current = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _publishLocation(current);
      return;
    }

    await LocationService(isMandatory: true).requireAlwaysPermission();
    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    await _publishLocation(current);

    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: const Duration(seconds: 8),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'جيتك - توصيل طلب',
          notificationText: 'تتم مشاركة موقعك مع العميل أثناء التوصيل',
          notificationChannelName: 'تتبع التوصيل',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );
    }
    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      _publishLocation,
      onError: (error) => GlobalVar.log('Location sharing error: $error'),
    );
  }

  Future<void> _publishLocation(Position position) async {
    if (_locationRequestInFlight) return;
    _locationRequestInFlight = true;
    try {
      final payload = {
        'lat': position.latitude,
        'lng': position.longitude,
      };
      await _api.putRequest('/Orders/Location', payload);

      final orderId = _trackingOrderId;
      if (orderId != null) {
        await _api.putRequest('/Orders/$orderId/Location', payload);
      }
    } catch (error) {
      GlobalVar.log('Could not publish delivery location: $error');
    } finally {
      _locationRequestInFlight = false;
    }
  }

  Future<void> _stopLocationSharing(int orderId) async {
    if (_trackingOrderId != orderId) return;
    _trackingOrderId = null;
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}

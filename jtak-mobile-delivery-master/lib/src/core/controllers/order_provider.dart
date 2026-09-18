import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:app_jtak_delivery/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_delivery/src/core/enums/order_details_status_enum.dart';
import 'package:app_jtak_delivery/src/core/models/order_model.dart';
import 'package:app_jtak_delivery/src/core/services/location_service.dart';
import 'package:app_jtak_delivery/src/core/services/locator.dart';
import 'package:app_jtak_delivery/src/utils/providers/sol_api.dart';
import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderProvider extends BaseProvider<OrderModel> {
  final SolApi _api = locator<SolApi>();
  OrderModel? order;
  StreamSubscription<Position>? _locationSubscription;
  int? _trackingOrderId;
  bool _locationRequestInFlight = false;

  bool isOnline = true;
  DateTime? shiftStartedAt;
  bool _shiftLoading = false;
  bool get shiftLoading => _shiftLoading;

  final Set<int> _actionInFlightOrderIds = {};
  bool isActionInFlight(int? orderId) =>
      orderId != null && _actionInFlightOrderIds.contains(orderId);

  final Set<int> _acknowledgedOrders = {};
  OrderModel? incomingOrderAlert;

  List<OrderModel> get activeOrders =>
      dataList.where((o) => !o.isTerminal).toList();
  List<OrderModel> get completedOrders =>
      dataList.where((o) => o.isTerminal).toList();

  OrderProvider() {
    _loadAcknowledgedOrders();
  }

  Future<void> _loadAcknowledgedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('ack_orders') ?? [];
      for (final s in list) {
        final id = int.tryParse(s);
        if (id != null) _acknowledgedOrders.add(id);
      }
    } catch (_) {}
  }

  Future<void> _persistAcknowledgedOrder(int id) async {
    _acknowledgedOrders.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = _acknowledgedOrders.toList();
      if (recent.length > 100) {
        recent.removeRange(0, recent.length - 100);
      }
      await prefs.setStringList(
          'ack_orders', recent.map((e) => e.toString()).toList());
    } catch (_) {}
  }

  Future<void> startLocationTracking() => _beginLocationSharing();

  Future<void> fetchShiftStatus() async {
    try {
      final res = await _api.getRequest('/Orders/Shift/Status');
      if (res is Map) {
        isOnline = res['isOnline'] ?? true;
        if (res['shiftStartedAt'] != null) {
          shiftStartedAt = DateTime.tryParse(res['shiftStartedAt'].toString());
        }
        notifyListeners();
      }
    } catch (e) {
      GlobalVar.log('fetchShiftStatus error: $e');
    }
  }

  Future<void> setShiftStatus(bool online) async {
    _shiftLoading = true;
    notifyListeners();
    try {
      await _api.postRequest('/Orders/Shift/Status', {'isOnline': online});
      isOnline = online;
      if (online) {
        shiftStartedAt = DateTime.now();
        await startLocationTracking();
        await refreshData();
      } else {
        shiftStartedAt = null;
        await pauseLocationSharing();
      }
    } catch (e) {
      GlobalVar.log('setShiftStatus error: $e');
    } finally {
      _shiftLoading = false;
      notifyListeners();
    }
  }

  void dismissIncomingOrderAlert() {
    if (incomingOrderAlert?.id != null) {
      _persistAcknowledgedOrder(incomingOrderAlert!.id!);
    }
    incomingOrderAlert = null;
    notifyListeners();
  }

  Future<void> pauseLocationSharing() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _trackingOrderId = null;
  }

  List<OrderModel> availableOrders = [];
  bool _isFetchingAvailable = false;
  bool get isFetchingAvailable => _isFetchingAvailable;

  Future<void> fetchAvailableOrders() async {
    if (_isFetchingAvailable) return;
    _isFetchingAvailable = true;
    try {
      final body = {
        'pageNumber': 0,
        'pageSize': 50,
        'sortField': 'id',
        'sortOrder': 'desc'
      };
      final res = await _api.postRequest('/Orders/Available', body);
      if (res is Map && res['items'] is List) {
        final List data = res['items'];
        final fetchedOrders = data.map((e) => OrderModel.fromMap(e)).toList();
        final myOrderIds = dataList.map((e) => e.id).toSet();
        // A refresh can overlap with a completed claim. Filter locally so a
        // stale response never shows a claimed order as available again.
        availableOrders = fetchedOrders
            .where((o) =>
                o.id != null &&
                !_acknowledgedOrders.contains(o.id) &&
                !myOrderIds.contains(o.id))
            .toList();

        // Alert rider ONLY for new available orders in the pool that are not acknowledged and not already claimed
        if (isOnline && availableOrders.isNotEmpty) {
          for (final o in availableOrders) {
            if (o.id != null) {
              if (incomingOrderAlert == null ||
                  incomingOrderAlert!.id != o.id) {
                incomingOrderAlert = o;
                HapticFeedback.heavyImpact();
                break;
              }
            }
          }
        }
      } else {
        availableOrders = [];
      }
    } catch (e) {
      GlobalVar.log('fetchAvailableOrders error: $e');
    } finally {
      _isFetchingAvailable = false;
      notifyListeners();
    }
  }

  Future<bool> claimOrder(int orderId) async {
    if (isActionInFlight(orderId)) return false;
    _actionInFlightOrderIds.add(orderId);
    notifyListeners();
    try {
      final response = await _api.postRequest('/Orders/Claim/$orderId', {});
      if (response == false || response == 'false') {
        throw Exception('تعذر استلام الطلب. ربما استلمه مندوب آخر.');
      }
      await _persistAcknowledgedOrder(orderId);
      availableOrders.removeWhere((o) => o.id == orderId);
      await refreshData();
      HapticFeedback.mediumImpact();
      return true;
    } catch (e) {
      GlobalVar.log('claimOrder error: $e');
      rethrow;
    } finally {
      _actionInFlightOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  bool _isSilentSyncing = false;

  /// Smoothly syncs active and available orders in the background.
  /// Does NOT clear dataList, and only calls notifyListeners() if data actually changed.
  Future<void> silentSync() async {
    if (_isSilentSyncing || isBusy) return;
    _isSilentSyncing = true;
    try {
      await _silentSyncMine();
    } catch (e) {
      GlobalVar.log('silentSync error: $e');
    } finally {
      _isSilentSyncing = false;
    }
  }

  Future<void> _silentSyncMine() async {
    final body = {
      'pageNumber': 0,
      'pageSize': 20,
      'sortField': 'id',
      'sortOrder': 'desc',
    };
    final res = await _api.postRequest('/Orders/Mine', body);
    if (res is Map && res['items'] is List) {
      final List data = res['items'];
      final List<OrderModel> newOrders =
          data.map((e) => OrderModel.fromMap(e)).toList();

      // The silent endpoint returns only the newest page. Merge it into the
      // already loaded list so older history does not disappear every 10
      // seconds while the active dashboard is being refreshed.
      final refreshedIds = newOrders
          .where((updated) => updated.id != null)
          .map((updated) => updated.id!)
          .toSet();
      final mergedOrders = <OrderModel>[...newOrders];
      mergedOrders.addAll(
        dataList.where(
          (existing) =>
              existing.id == null || !refreshedIds.contains(existing.id),
        ),
      );
      mergedOrders.sort(
        (a, b) => (b.id ?? -1).compareTo(a.id ?? -1),
      );

      bool changed = false;
      if (dataList.length != mergedOrders.length) {
        changed = true;
      } else {
        for (int i = 0; i < mergedOrders.length; i++) {
          if (dataList[i] != mergedOrders[i]) {
            changed = true;
            break;
          }
        }
      }

      if (changed) {
        dataList = mergedOrders;
        for (final o in mergedOrders) {
          if (o.id != null) {
            _acknowledgedOrders.add(o.id!);
          }
        }
        if (order != null) {
          final updatedCurrent = newOrders.cast<OrderModel?>().firstWhere(
                (o) => o?.id == order!.id,
                orElse: () => null,
              );
          if (updatedCurrent != null && updatedCurrent != order) {
            order = updatedCurrent;
          }
        }
        notifyListeners();
      }

      final active = (dataList.cast<OrderModel?>()).firstWhere(
        (item) =>
            item != null && item.deliveryStatus == OrderDetailsStatus.shipping,
        orElse: () => null,
      );
      if (active?.id != null && isOnline) {
        _beginLocationSharing(active!.id!);
      } else {
        _trackingOrderId = null;
      }
    }
  }

  /// Silently checks if the current single order has any status changes without blinking the UI
  Future<void> silentSyncOrder(int id) async {
    try {
      var data = await _api.getRequest('/Orders/$id');
      if (data != null && data is Map) {
        final updated = OrderModel.fromMap(Map<String, dynamic>.from(data));
        if (order == null || order != updated) {
          order = updated;
          final idx = dataList.indexWhere((o) => o.id == id);
          if (idx != -1) {
            dataList[idx] = updated;
          }
          notifyListeners();
        }
      }
    } catch (e) {
      GlobalVar.log('silentSyncOrder error: $e');
    }
  }

  Future<void> _reloadSingleOrder(int id) async {
    try {
      var data = await _api.getRequest('/Orders/$id');
      if (data != null && data is Map) {
        final updated = OrderModel.fromMap(Map<String, dynamic>.from(data));
        if (order?.id == id) {
          order = updated;
        }
        final idx = dataList.indexWhere((o) => o.id == id);
        if (idx != -1) {
          dataList[idx] = updated;
        }
        notifyListeners();
      }
    } catch (e) {
      GlobalVar.log('_reloadSingleOrder error: $e');
    }
  }

  bool _isRefreshingData = false;

  Future<void> refreshData() async {
    if (_isRefreshingData) return;
    _isRefreshingData = true;

    final selectedId = order?.id;
    try {
      page = 0;
      isMoreAvailable = true;

      // The homepage owns both the active and history tabs, so load every page
      // during an explicit refresh. Otherwise history silently stopped at the
      // first 20 orders even though the API supports pagination.
      do {
        final pageBeforeLoad = page;
        await loadPagedData();
        if (page == pageBeforeLoad) break;
      } while (isMoreAvailable && page < 100);

      if (selectedId != null) {
        order = dataList.cast<OrderModel?>().firstWhere(
              (item) => item?.id == selectedId,
              orElse: () => order,
            );
        if (order?.id != null) {
          await _reloadSingleOrder(order!.id!);
        }
        notifyListeners();
      }
    } finally {
      _isRefreshingData = false;
    }
  }

  Future loadPagedData() async {
    var lastPageCount = 0;
    await loadInfinityData(
      loadData: (page) async {
        Map body = {
          'pageNumber': page,
          "pageSize": 20,
          "sortField": "id",
          "sortOrder": "desc"
        };
        var res = await _api.postRequest('/Orders/Mine', body);
        if (res is! Map || res['items'] is! List) {
          throw Exception('تعذر تحميل الطلبات الحالية والسجل');
        }
        List data = res['items'];
        lastPageCount = data.length;
        final orders = data.map((e) => OrderModel.fromMap(e)).toList();

        // Mark all active orders belonging to this driver as acknowledged so they never trigger incoming popups
        for (final o in orders) {
          if (o.id != null) {
            _acknowledgedOrders.add(o.id!);
          }
        }

        final active = orders.cast<OrderModel?>().firstWhere(
              (item) =>
                  item != null &&
                  item.deliveryStatus == OrderDetailsStatus.shipping,
              orElse: () => null,
            );
        if (active?.id != null && isOnline) {
          _beginLocationSharing(active!.id!);
        } else {
          _trackingOrderId = null;
        }
        return orders;
      },
    );

    // The API uses a fixed page size. Avoid one unnecessary empty request for
    // the normal final partial page while still handling an exact multiple.
    if (lastPageCount < 20) isMoreAvailable = false;
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

  Future<void> startShipping(int orderId, int merchentId) async {
    if (isActionInFlight(orderId)) return;
    _actionInFlightOrderIds.add(orderId);
    notifyListeners();
    try {
      await _api.postRequest('/Orders/StartShipping/$orderId/$merchentId', {});
      await _beginLocationSharing(orderId);
      await _reloadSingleOrder(orderId);
      await _silentSyncMine();
    } catch (e) {
      GlobalVar.log('startShipping error: $e');
      rethrow;
    } finally {
      _actionInFlightOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  Future<bool> deliverOrder(int orderId,
      {String? otp, String? notes, String? photoUrl}) async {
    if (isActionInFlight(orderId)) return false;
    _actionInFlightOrderIds.add(orderId);
    notifyListeners();
    try {
      final res = await _api.postRequest('/Orders/DeliverOrder/$orderId', {
        'orderId': orderId,
        'otp': otp,
        'notes': notes,
        'photoUrl': photoUrl,
      });
      if (res == false || res == 'false') {
        throw Exception(
            'تعذر تأكيد تسليم الطلب. يرجى التأكد من استلام كافة أصناف المتاجر وصحة رمز التحقق.');
      }
      await _stopLocationSharing(orderId);
      await _reloadSingleOrder(orderId);
      await _silentSyncMine();
      return true;
    } catch (e) {
      GlobalVar.log('deliverOrder error: $e');
      // Idempotent recovery check: If the primary delivery committed despite a secondary exception
      try {
        final checkOrder = await _api.getRequest('/Orders/$orderId');
        if (checkOrder != null && checkOrder is Map) {
          final status = checkOrder['status'] ?? checkOrder['orderStatus'];
          final isDelivered = status == 5 || status == 'Delivered' || checkOrder['isDelivered'] == true;
          if (isDelivered) {
            await _stopLocationSharing(orderId);
            await _reloadSingleOrder(orderId);
            await _silentSyncMine();
            return true;
          }
        }
      } catch (_) {}
      rethrow;
    } finally {
      _actionInFlightOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  Future<String?> uploadPoDPhoto(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final uri = Uri.parse('${SolApi.baseURL}/api/v1/services/SaveUploaded');
      final request = http.MultipartRequest('POST', uri);
      final headers = _api.getHeaders();
      request.headers.addAll(headers);
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name.isNotEmpty
            ? file.name
            : 'pod_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        if (decoded is String) return decoded;
        if (decoded is Map && decoded['id'] != null)
          return decoded['id'].toString();
        return response.body.replaceAll('"', '').trim();
      } else {
        GlobalVar.log(
            'PoD photo upload failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      GlobalVar.log('Error uploading PoD photo: $e');
      return null;
    }
  }

  Future<void> cancelOrder(int orderId) async {
    if (isActionInFlight(orderId)) return;
    _actionInFlightOrderIds.add(orderId);
    notifyListeners();
    try {
      await _api.postRequest('/Orders/Cancel/$orderId', {});
      await _stopLocationSharing(orderId);
      await _reloadSingleOrder(orderId);
      await _silentSyncMine();
    } catch (e) {
      GlobalVar.log('cancelOrder error: $e');
      rethrow;
    } finally {
      _actionInFlightOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  bool orderIsEmpty() {
    return order == null ||
        !GlobalVar.checkListNotEmpty(order!.orderDetails) ||
        order!.id == null;
  }

  OrderDetailsStatus getOrderStatus(OrderModel order) => order.deliveryStatus;

  Future<void> _beginLocationSharing([int? orderId]) async {
    if (orderId != null) _trackingOrderId = orderId;
    if (_locationSubscription != null) {
      try {
        Position? current;
        try {
          current = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (_) {
          current = await Geolocator.getLastKnownPosition();
        }
        if (current != null) {
          await _publishLocation(current);
        }
      } catch (_) {}
      return;
    }

    await LocationService(isMandatory: true).requireAlwaysPermission();
    try {
      Position? current;
      try {
        current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        current = await Geolocator.getLastKnownPosition();
      }
      if (current != null) {
        await _publishLocation(current);
      }
    } catch (_) {}

    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 6),
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
        distanceFilter: 10,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
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
        'heading': position.heading,
        'speed': position.speed,
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

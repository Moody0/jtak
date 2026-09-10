import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:jtek_app/src/core/enums/order_details_status_enum.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/providers/sol_api.dart';
import '../../enums/viewstate.dart';
import '../../models/order/order_model.dart';
import '../../services/locator.dart';
import '../app/base_provider.dart';

/// ---------------------------------------------------------------------------
/// JTAK Dynamic Order Provider (Backend API + Instant Real-Time Order Sync)
/// ---------------------------------------------------------------------------

class OrderProvider extends BaseProvider<OrderModel> {
  static String _getUserOrdersKey() {
    final user = locator<AuthenticationService>().user;
    final phone = user?.phoneNumber ?? user?.id ?? 'guest';
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return 'jtek_user_orders_${cleanPhone.isNotEmpty ? cleanPhone : "guest"}';
  }

  static OrderProvider? instance;
  final SolApi _api = locator<SolApi>();
  OrderModel? order;
  final List<OrderModel> _localPlacedOrders = [];

  OrderProvider() {
    instance = this;
    _loadLocalPlacedOrders();
  }

  void resetData() {
    dataList.clear();
    _localPlacedOrders.clear();
    order = null;
    notifyListeners();
  }

  /// Load local placed orders from persistent storage for current user
  Future<void> _loadLocalPlacedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_getUserOrdersKey());
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List list = jsonDecode(jsonStr);
        _localPlacedOrders.clear();
        for (var item in list) {
          _localPlacedOrders.add(OrderModel.fromMap(item));
        }
      }
    } catch (e) {
      debugPrint('Error loading local placed orders: $e');
    }
  }

  /// Save local placed orders to persistent storage for current user
  Future<void> _saveLocalPlacedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _localPlacedOrders.map((e) => e.toMap()).toList();
      await prefs.setString(_getUserOrdersKey(), jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving local placed orders: $e');
    }
  }

  /// Static helper to save newly placed order from Cart checkout
  static Future<void> saveNewOrderGlobally(OrderModel newOrder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getUserOrdersKey();
      final String? jsonStr = prefs.getString(key);
      List list = [];
      if (jsonStr != null && jsonStr.isNotEmpty) {
        list = jsonDecode(jsonStr);
      }
      list.removeWhere((item) => item['id'] == newOrder.id);
      list.insert(0, newOrder.toMap());
      await prefs.setString(key, jsonEncode(list));

      if (instance != null) {
        instance!.addNewPlacedOrder(newOrder);
      }
    } catch (e) {
      debugPrint('Error saving new order globally: $e');
    }
  }

  /// Adds a newly placed order immediately so it shows up in "الطلبات الحالية" in real time
  void addNewPlacedOrder(OrderModel newOrder) {
    _localPlacedOrders.removeWhere((o) => o.id == newOrder.id);
    _localPlacedOrders.insert(0, newOrder);
    _saveLocalPlacedOrders();

    dataList.removeWhere((o) => o.id == newOrder.id);
    dataList.insert(0, newOrder);
    notifyListeners();
  }

  /// Fetches paginated orders dynamically from the backend and merges live local orders
  Future<void> loadPagedData() async {
    await _loadLocalPlacedOrders();

    final isLogin = locator<AuthenticationService>().isLogin();
    if (isLogin) {
      await loadInfinityData(
        loadData: (page) async {
          List<OrderModel> remoteOrders = [];
          try {
            Map body = {
              'pageNumber': page,
              'sortField': 'id',
              'sortOrder': 'desc',
            };
            var res = await _api.postRequest('/Orders/Mine', body);
            List data = res['items'] ?? res['data'] ?? (res is List ? res : []);
            remoteOrders = data.map((e) => OrderModel.fromMap(e)).toList();
          } catch (e) {
            debugPrint('Orders/Mine API note (using local sync): $e');
          }

          if (page == 0) {
            // The API is authoritative. Local storage is only an offline cache.
            final List<OrderModel> merged = List<OrderModel>.from(remoteOrders);
            for (var cached in _localPlacedOrders) {
              if (!merged.any((remote) => remote.id == cached.id))
                merged.add(cached);
            }
            _localPlacedOrders
              ..clear()
              ..addAll(merged);
            _saveLocalPlacedOrders();
            return merged;
          }

          return remoteOrders;
        },
      );
    } else {
      // If offline/guest has placed local orders, display them
      dataList = List<OrderModel>.from(_localPlacedOrders);
      setState(ViewState.idle);
    }
  }

  /// Fetches the complete details of a single order with optional silent live sync
  Future<void> loadOrder(int id, {bool silent = false}) async {
    if (!silent) {
      setState(ViewState.busy);
    }
    try {
      if (locator<AuthenticationService>().isLogin()) {
        try {
          var data = await _api.getRequest('/Orders/$id');
          if (data != null && data is Map) {
            order = OrderModel.fromMap(Map<String, dynamic>.from(data));
            _cacheServerOrder(order!);
            notifyListeners();
            return;
          }
        } catch (e) {
          debugPrint('Backend sync note for order #$id: $e');
        }
      }

      final localMatch = _localPlacedOrders.firstWhere(
        (o) => o.id == id,
        orElse: () => order ?? OrderModel(),
      );
      if (localMatch.id != null) {
        order = localMatch;
      }
    } finally {
      if (!silent) {
        setState(ViewState.idle);
      } else {
        notifyListeners();
      }
    }
  }

  /// Submits an order review to the backend
  Future<void> rateOrder(int orderId, double rate) async {
    return await loadBaseData(
      loadBody: () async {
        var body = {
          "rate": rate.toInt(),
        };
        try {
          await _api.postRequest('/ProductReviews/$orderId', body);
        } catch (e) {
          debugPrint('rateOrder error: $e');
        }
      },
    );
  }

  void setOrderObject(OrderModel orderObject) async {
    order = orderObject;
    if (orderIsEmpty() && order?.id != null) {
      await loadOrder(order!.id!);
    }
    notifyListeners();
  }

  bool orderIsEmpty() {
    return order == null ||
        !GlobalVar.checkListNotEmpty(order!.orderDetails) ||
        order!.id == null;
  }

  /// Accepts merchant-proposed changes on an order
  Future<void> acceptChange() async {
    if (order?.id == null) return;
    return await loadBaseData(
      loadBody: () async {
        await _api.postRequest('/Orders/AcceptChange/${order!.id}', {});
        await loadOrder(order!.id!, silent: true);
      },
    );
  }

  /// Cancels an order on the backend and locally
  Future<void> cancelOrder() async {
    if (order?.id == null) return;
    return await loadBaseData(
      loadBody: () async {
        await _api.postRequest('/Orders/Cancel/${order!.id}', {});
        await loadOrder(order!.id!, silent: true);
      },
    );
  }

  OrderDetailsStatus getOrderStatus(OrderModel order) {
    OrderDetailsStatus status = OrderDetailsStatus.pending;
    if (GlobalVar.checkListNotEmpty(order.orderDetails)) {
      status = order.orderDetails!.first.orderDetailStatus ??
          OrderDetailsStatus.pending;
      for (var element in order.orderDetails!) {
        if ((element.orderDetailStatus?.index ?? 0) < status.index) {
          status = element.orderDetailStatus ?? OrderDetailsStatus.pending;
        }
      }
    }
    return status;
  }

  void setOrderDetailsStatus(OrderModel item, OrderDetailsStatus status) {
    OrderModel orderList = dataList
        .firstWhere((element) => element.id == item.id, orElse: () => item);
    if (GlobalVar.checkListNotEmpty(order?.orderDetails)) {
      for (var i = 0; i < order!.orderDetails!.length; i++) {
        order?.orderDetails![i].orderDetailStatus = status;
        if (orderList.orderDetails != null &&
            i < orderList.orderDetails!.length) {
          orderList.orderDetails![i].orderDetailStatus = status;
        }
      }
    }

    // Update local placed orders copy
    for (var lo in _localPlacedOrders) {
      if (lo.id == item.id && lo.orderDetails != null) {
        for (var d in lo.orderDetails!) {
          d.orderDetailStatus = status;
        }
      }
    }
    _saveLocalPlacedOrders();
    notifyListeners();
  }

  void _cacheServerOrder(OrderModel updated) {
    final localIndex =
        _localPlacedOrders.indexWhere((item) => item.id == updated.id);
    if (localIndex >= 0)
      _localPlacedOrders[localIndex] = updated;
    else
      _localPlacedOrders.insert(0, updated);

    final listIndex = dataList.indexWhere((item) => item.id == updated.id);
    if (listIndex >= 0) dataList[listIndex] = updated;
    _saveLocalPlacedOrders();
  }
}

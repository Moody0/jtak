import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/app/merchant_state_provider.dart';
import 'package:app_jtak_warehouse/src/core/enums/order_details_status_enum.dart';
import 'package:app_jtak_warehouse/src/core/enums/payment_method_enum.dart';
import 'package:app_jtak_warehouse/src/core/models/order_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderProvider extends BaseProvider<OrderModel> {
  final SolApi _api = locator<SolApi>();
  OrderModel? order;

  int _activeTabIndex = 0;
  String _searchQuery = '';
  int _activeQuickFilter = 0; // 0 = All, 1 = Today, 2 = Cash, 3 = Online
  bool _isSilentRefreshing = false;
  DateTime? _lastSyncTime;
  final Map<int, DateTime> _prepDeadlines = {};
  final Map<int, Set<int>> _pickedItemIds = {}; // orderId -> Set of picked detailIds
  int _lastKnownPendingCount = 0;

  int get activeTabIndex => _activeTabIndex;
  String get searchQuery => _searchQuery;
  int get activeQuickFilter => _activeQuickFilter;

  // Compatibility getters for legacy references
  int get selectedPaymentFilter => _activeQuickFilter == 2 ? 1 : (_activeQuickFilter == 3 ? 2 : 0);
  bool get filterTodayOnly => _activeQuickFilter == 1;
  bool get isSilentRefreshing => _isSilentRefreshing;
  DateTime? get lastSyncTime => _lastSyncTime;

  OrderProvider() {
    _loadStoredDeadlines();
    _loadStoredPickedItems();
  }

  Future<void> _loadStoredDeadlines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('merchant_prep_deadline_'));
      for (var key in keys) {
        final orderId = int.tryParse(key.replaceFirst('merchant_prep_deadline_', ''));
        final val = prefs.getString(key);
        if (orderId != null && val != null) {
          final deadline = DateTime.tryParse(val);
          if (deadline != null) {
            _prepDeadlines[orderId] = deadline;
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadStoredPickedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('merchant_picked_items_'));
      for (var key in keys) {
        final orderId = int.tryParse(key.replaceFirst('merchant_picked_items_', ''));
        final list = prefs.getStringList(key);
        if (orderId != null && list != null) {
          final detailIds = list.map((e) => int.tryParse(e)).whereType<int>().toSet();
          if (detailIds.isNotEmpty) {
            _pickedItemIds[orderId] = detailIds;
          }
        }
      }
      _applyPickedStatesToOrders(dataList);
      if (order != null) {
        _applyPickedStatesToOrders([order!]);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePickedItems(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'merchant_picked_items_$orderId';
      final pickedSet = _pickedItemIds[orderId];
      if (pickedSet == null || pickedSet.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setStringList(
          key,
          pickedSet.map((id) => id.toString()).toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _clearStoredOrderData(int orderId) async {
    _prepDeadlines.remove(orderId);
    _pickedItemIds.remove(orderId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('merchant_prep_deadline_$orderId');
      await prefs.remove('merchant_picked_items_$orderId');
    } catch (_) {}
  }

  void _applyPickedStatesToOrders(List<OrderModel> orders) {
    for (var ord in orders) {
      if (ord.id == null || ord.orderDetails == null) continue;
      final pickedSet = _pickedItemIds[ord.id];
      for (var d in ord.orderDetails!) {
        if (d.id != null) {
          if (pickedSet != null && pickedSet.contains(d.id)) {
            d.isPicked = true;
          }
        }
      }
    }
  }

  void _cleanupOldOrdersStorage() {
    for (var ord in pastOrders) {
      if (ord.id != null && (_pickedItemIds.containsKey(ord.id) || _prepDeadlines.containsKey(ord.id))) {
        _clearStoredOrderData(ord.id!);
      }
    }
  }

  bool isItemPicked(int orderId, int detailId) =>
      _pickedItemIds[orderId]?.contains(detailId) ?? false;

  DateTime? getPrepDeadline(int orderId) => _prepDeadlines[orderId];

  void setActiveTab(int index) {
    if (_activeTabIndex != index) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    final trimmed = query.trim();
    if (_searchQuery != trimmed) {
      _searchQuery = trimmed;
      notifyListeners();
    }
  }

  void setQuickFilter(int filter) {
    if (_activeQuickFilter != filter) {
      _activeQuickFilter = filter;
      notifyListeners();
    }
  }

  void setPaymentFilter(int filter) {
    if (filter == 1) {
      setQuickFilter(_activeQuickFilter == 2 ? 0 : 2);
    } else if (filter == 2) {
      setQuickFilter(_activeQuickFilter == 3 ? 0 : 3);
    } else {
      setQuickFilter(0);
    }
  }

  void toggleTodayOnly() {
    setQuickFilter(_activeQuickFilter == 1 ? 0 : 1);
  }

  void clearAllFilters() {
    _searchQuery = '';
    _activeQuickFilter = 0;
    notifyListeners();
  }

  // --- Kanban Status Slices (Raw) ---
  List<OrderModel> get newOrders => dataList.where((item) => getOrderStatus(item) == OrderDetailsStatus.pending).toList();

  List<OrderModel> get preparingOrders => dataList.where((item) => getOrderStatus(item) == OrderDetailsStatus.merchantAccepted).toList();

  List<OrderModel> get readyOrders => dataList.where((item) {
        final s = getOrderStatus(item);
        return s == OrderDetailsStatus.readyForPickup || s == OrderDetailsStatus.shipping;
      }).toList();

  List<OrderModel> get pastOrders => dataList.where((item) {
        final s = getOrderStatus(item);
        return s == OrderDetailsStatus.delivered ||
            s == OrderDetailsStatus.merchantRejected ||
            s == OrderDetailsStatus.customerCanceled ||
            s == OrderDetailsStatus.deliveryCanceled;
      }).toList();

  // --- Real-time Filtered Slices for Tab Counters & Views ---
  List<OrderModel> get filteredNewOrders => filterList(newOrders);

  List<OrderModel> get filteredPreparingOrders => filterList(preparingOrders);

  List<OrderModel> get filteredReadyOrders => filterList(readyOrders);

  List<OrderModel> get filteredPastOrders => filterList(pastOrders);

  List<OrderModel> get filteredAllOrders => filterList(dataList);

  // --- Quick Filter Badge Counters ---
  int get allOrdersCount => dataList.length;

  int get todayOrdersCount {
    final now = DateTime.now();
    return dataList.where((o) => _isOrderToday(o, now)).length;
  }

  int get cashOrdersCount => dataList.where((o) => o.paymentMethod == PaymentMethod.payOnDelivery || o.paymentMethod == null).length;

  int get electronicOrdersCount => dataList.where((o) => o.paymentMethod == PaymentMethod.creditCardPayment).length;

  static bool _isOrderToday(OrderModel o, DateTime now) {
    final raw = o.createdDate ?? o.purchaseDate;
    if (raw == null || raw.toString().trim().isEmpty) return false;
    final d = DateTime.tryParse(raw.toString().trim());
    if (d == null) return false;
    final local = d.toLocal();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  List<OrderModel> filterList(List<OrderModel> source) {
    var result = source;

    // Filter by payment method
    if (selectedPaymentFilter == 1) {
      result = result.where((o) => o.paymentMethod == PaymentMethod.payOnDelivery || o.paymentMethod == null).toList();
    } else if (selectedPaymentFilter == 2) {
      result = result.where((o) => o.paymentMethod == PaymentMethod.creditCardPayment).toList();
    }

    // Filter by Today only
    if (filterTodayOnly) {
      final now = DateTime.now();
      result = result.where((o) => _isOrderToday(o, now)).toList();
    }

    if (_searchQuery.isEmpty) return result;
    final q = _searchQuery.toLowerCase().trim();
    return result.where((o) {
      final idMatch = o.id.toString().contains(q) || '#${o.id}'.contains(q);
      final userMatch = (o.user ?? '').toLowerCase().contains(q);
      final phoneMatch = (o.phonenumber ?? '').contains(q);
      final addressMatch = (o.address ?? '').toLowerCase().contains(q);
      final notesMatch = (o.notes ?? '').toLowerCase().contains(q) || (o.description ?? '').toLowerCase().contains(q);
      final itemMatch = o.orderDetails?.any((d) => (d.productTitle ?? '').toLowerCase().contains(q)) ?? false;
      return idMatch || userMatch || phoneMatch || addressMatch || notesMatch || itemMatch;
    }).toList();
  }

  List<OrderModel> get currentTabFilteredOrders {
    switch (_activeTabIndex) {
      case 0:
        return filteredNewOrders;
      case 1:
        return filteredPreparingOrders;
      case 2:
        return filteredReadyOrders;
      case 3:
        return filteredPastOrders;
      default:
        return filteredAllOrders;
    }
  }

  Future refreshData({bool isUserInitiated = false}) async {
    final selectedId = order?.id;
    if (isUserInitiated && dataList.isNotEmpty) {
      await silentRefresh();
      return;
    }
    page = 0;
    await loadPagedData();
    _lastSyncTime = DateTime.now();
    if (selectedId != null) {
      order = dataList.cast<OrderModel?>().firstWhere(
        (item) => item?.id == selectedId,
        orElse: () => order,
      );
      notifyListeners();
    }
  }

  /// Silent background sync that never wipes dataList and causes zero UI flicker
  Future<void> silentRefresh() async {
    if (_isSilentRefreshing) return;
    _isSilentRefreshing = true;
    notifyListeners();

    try {
      Map body = {
        'pageNumber': 0,
        "pageSize": 50,
        "sortField": "id",
        "sortOrder": "desc",
      };
      var res = await _api.postRequest('/Orders/Mine', body);
      if (res != null && res['items'] is List) {
        List itemsJson = res['items'];
        final newItems = itemsJson.map((e) => OrderModel.fromMap(e)).toList();

        // Check for new incoming pending orders
        final previousPendingIds = newOrders.map((o) => o.id).toSet();
        final newlyArrivedOrders = newItems
            .where((item) => getOrderStatus(item) == OrderDetailsStatus.pending)
            .where((item) => !previousPendingIds.contains(item.id))
            .toList();

        _applyPickedStatesToOrders(newItems);
        dataList = newItems;
        _lastSyncTime = DateTime.now();
        _syncPendingCount();
        _cleanupOldOrdersStorage();

        if (order != null) {
          final currentSelectedId = order!.id;
          final updatedOrder = newItems.cast<OrderModel?>().firstWhere(
            (item) => item?.id == currentSelectedId,
            orElse: () => null,
          );
          if (updatedOrder != null) {
            order = updatedOrder;
          }
        }

        if (newlyArrivedOrders.isNotEmpty) {
          _triggerNewOrderChimeIfNeeded();
        }
      }
    } catch (e) {
      debugPrint('Silent refresh error: $e');
    } finally {
      _isSilentRefreshing = false;
      notifyListeners();
    }
  }

  Future loadPagedData() async {
    await loadInfinityData(
      loadData: (page) async {
        Map body = {
          'pageNumber': page,
          "pageSize": 50,
          "sortField": "id",
          "sortOrder": "desc",
        };
        var res = await _api.postRequest('/Orders/Mine', body);
        List data = res['items'];
        final list = data.map((e) => OrderModel.fromMap(e)).toList();
        _applyPickedStatesToOrders(list);
        return list;
      },
    );
    _lastSyncTime = DateTime.now();
    _syncPendingCount();
    _cleanupOldOrdersStorage();
    _triggerNewOrderChimeIfNeeded();
  }

  void _syncPendingCount() {
    try {
      final pendingList = newOrders;
      final count = pendingList.length;
      if (locator.isRegistered<MerchantStateProvider>()) {
        locator<MerchantStateProvider>().updatePendingOrdersCount(count);
      }
    } catch (_) {}
  }

  void _triggerNewOrderChimeIfNeeded() {
    try {
      final currentPending = newOrders.length;
      if (currentPending > 0 && currentPending > _lastKnownPendingCount) {
        if (locator.isRegistered<MerchantStateProvider>()) {
          final merchantState = locator<MerchantStateProvider>();
          if (merchantState.isSoundAlertEnabled) {
            SystemSound.play(SystemSoundType.alert);
            HapticFeedback.heavyImpact();
          }
        }
      }
      _lastKnownPendingCount = currentPending;
    } catch (_) {}
  }

  Future loadOrder(int id) async {
    return await loadBaseData(
      loadBody: () async {
        var data = await _api.getRequest('/Orders/$id');
        order = OrderModel.fromMap(data);
        if (order != null) {
          _applyPickedStatesToOrders([order!]);
        }
        await loadPickingList(id);
      },
    );
  }

  void setOrderObject(OrderModel orderObject) async {
    order = orderObject;
    if (order != null) {
      _applyPickedStatesToOrders([order!]);
    }
    if (orderIsEmpty()) {
      await loadOrder(order!.id ?? -1);
    } else if (order!.id != null) {
      await loadPickingList(order!.id!);
    }
  }

  Future<void> loadPickingList(int orderId) async {
    try {
      var res = await _api.getRequest('/Orders/$orderId/PickingList');
      if (res is List && order != null && order!.orderDetails != null) {
        for (var item in res) {
          final detailId = item['orderDetailId'];
          for (var d in order!.orderDetails!) {
            if (d.id == detailId) {
              d.locationBin = item['locationBin'];
              d.batchNumber = item['batchNumber'];
              d.barcode = item['barcode'];
              final backendPicked = item['isPicked'] == true;
              if (backendPicked) {
                d.isPicked = true;
                _pickedItemIds.putIfAbsent(orderId, () => {}).add(detailId);
                _savePickedItems(orderId);
              } else {
                d.isPicked = _pickedItemIds[orderId]?.contains(detailId) ?? d.isPicked;
              }
            }
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> pickItemBarcode(int orderId, int detailId, String barcode) async {
    var body = {
      'orderId': orderId,
      'orderDetailId': detailId,
      'scannedBarcode': barcode.trim(),
    };
    var res = await _api.postRequest('/Orders/$orderId/PickItem', body);
    if (res != null && res['success'] == true) {
      _setDetailPicked(orderId, detailId, true);
    }
    return res is Map<String, dynamic> ? res : {'success': false, 'message': 'Verification failed.'};
  }

  void _setDetailPicked(int orderId, int detailId, bool isPicked) {
    if (isPicked) {
      _pickedItemIds.putIfAbsent(orderId, () => {}).add(detailId);
    } else {
      _pickedItemIds[orderId]?.remove(detailId);
      if (_pickedItemIds[orderId]?.isEmpty ?? false) {
        _pickedItemIds.remove(orderId);
      }
    }
    _savePickedItems(orderId);

    for (var ord in dataList) {
      if (ord.id == orderId && ord.orderDetails != null) {
        for (var d in ord.orderDetails!) {
          if (d.id == detailId) {
            d.isPicked = isPicked;
          }
        }
      }
    }
    if (order?.id == orderId && order?.orderDetails != null) {
      for (var d in order!.orderDetails!) {
        if (d.id == detailId) {
          d.isPicked = isPicked;
        }
      }
    }
    notifyListeners();
  }

  void toggleItemChecklist(int orderId, int detailId) {
    bool isCurrentlyPicked = _pickedItemIds[orderId]?.contains(detailId) ?? false;
    if (!isCurrentlyPicked) {
      for (var ord in dataList) {
        if (ord.id == orderId && ord.orderDetails != null) {
          for (var d in ord.orderDetails!) {
            if (d.id == detailId && d.isPicked) {
              isCurrentlyPicked = true;
              break;
            }
          }
        }
      }
      if (!isCurrentlyPicked && order?.id == orderId && order?.orderDetails != null) {
        for (var d in order!.orderDetails!) {
          if (d.id == detailId && d.isPicked) {
            isCurrentlyPicked = true;
            break;
          }
        }
      }
    }

    final newPicked = !isCurrentlyPicked;
    _setDetailPicked(orderId, detailId, newPicked);
  }

  Future<bool> completePicking(OrderModel targetOrder) async {
    bool success = false;
    await loadBaseData(
      loadBody: () async {
        bool res = await _api.postRequest('/Orders/${targetOrder.id}/CompletePicking', {});
        if (res) {
          setOrderDetailsStatus(targetOrder, OrderDetailsStatus.readyForPickup);
          success = true;
        }
      },
    );
    return success;
  }

  OrderDetailsStatus getOrderStatus(OrderModel targetOrder) {
    OrderDetailsStatus status = OrderDetailsStatus.pending;
    if (GlobalVar.checkListNotEmpty(targetOrder.orderDetails)) {
      final items = targetOrder.orderDetails!;

      // 1. If all items were rejected by the merchant
      if (items.every((e) => e.orderDetailStatus == OrderDetailsStatus.merchantRejected)) {
        return OrderDetailsStatus.merchantRejected;
      }

      // 2. If all items are in terminal canceled/rejected states
      final allTerminal = items.every((e) =>
          e.orderDetailStatus == OrderDetailsStatus.merchantRejected ||
          e.orderDetailStatus == OrderDetailsStatus.customerCanceled ||
          e.orderDetailStatus == OrderDetailsStatus.deliveryCanceled);
      if (allTerminal) {
        if (items.any((e) => e.orderDetailStatus == OrderDetailsStatus.merchantRejected)) {
          return OrderDetailsStatus.merchantRejected;
        }
        if (items.any((e) => e.orderDetailStatus == OrderDetailsStatus.deliveryCanceled)) {
          return OrderDetailsStatus.deliveryCanceled;
        }
        return OrderDetailsStatus.customerCanceled;
      }

      // Active (non-terminal) items for fulfillment evaluation
      final activeItems = items.where((e) =>
          e.orderDetailStatus != OrderDetailsStatus.merchantRejected &&
          e.orderDetailStatus != OrderDetailsStatus.customerCanceled &&
          e.orderDetailStatus != OrderDetailsStatus.deliveryCanceled).toList();

      if (activeItems.isNotEmpty && activeItems.every((e) => e.orderDetailStatus == OrderDetailsStatus.delivered)) {
        return OrderDetailsStatus.delivered;
      }

      // 3. Active fulfillment stages
      if (activeItems.any((e) => e.orderDetailStatus == OrderDetailsStatus.shipping)) {
        return OrderDetailsStatus.shipping;
      }
      if (activeItems.any((e) => e.orderDetailStatus == OrderDetailsStatus.readyForPickup)) {
        return OrderDetailsStatus.readyForPickup;
      }
      if (activeItems.any((e) => e.orderDetailStatus == OrderDetailsStatus.merchantAccepted)) {
        return OrderDetailsStatus.merchantAccepted;
      }
      if (activeItems.any((e) => e.orderDetailStatus == OrderDetailsStatus.customerPending)) {
        return OrderDetailsStatus.customerPending;
      }
      return OrderDetailsStatus.pending;
    }
    return status;
  }

  Future<bool> acceptOrder(OrderModel targetOrder, {int prepMinutes = 25}) async {
    bool success = false;
    await loadBaseData(
      loadBody: () async {
        var res = await _api.postRequest('/Orders/Accept/${targetOrder.id}', {});
        if (res == true || res != null) {
          setOrderDetailsStatus(targetOrder, OrderDetailsStatus.merchantAccepted);
          final deadline = DateTime.now().add(Duration(minutes: prepMinutes));
          _prepDeadlines[targetOrder.id ?? 0] = deadline;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('merchant_prep_deadline_${targetOrder.id}', deadline.toIso8601String());
          } catch (_) {}
          success = true;
        }
      },
    );
    _syncPendingCount();
    notifyListeners();
    return success;
  }

  Future<bool> rejectOrder(OrderModel targetOrder, {String? reason}) async {
    bool success = false;
    await loadBaseData(
      loadBody: () async {
        var res = await _api.postRequest('/Orders/Reject/${targetOrder.id}', {'reason': reason ?? 'Store busy'});
        if (res == true || res != null) {
          setOrderDetailsStatus(targetOrder, OrderDetailsStatus.merchantRejected);
          if (targetOrder.id != null) {
            _clearStoredOrderData(targetOrder.id!);
          }
          success = true;
        }
      },
    );
    _syncPendingCount();
    notifyListeners();
    return success;
  }

  Future<bool> markOrderReady(OrderModel targetOrder) async {
    bool success = false;
    await loadBaseData(
      loadBody: () async {
        var res = await _api.postRequest('/Orders/Ready/${targetOrder.id}', {});
        if (res == true || res != null) {
          setOrderDetailsStatus(targetOrder, OrderDetailsStatus.readyForPickup);
          if (targetOrder.id != null) {
            _clearStoredOrderData(targetOrder.id!);
          }
          success = true;
        }
      },
    );
    notifyListeners();
    return success;
  }

  bool orderIsEmpty() {
    return order == null || !GlobalVar.checkListNotEmpty(order!.orderDetails) || order!.id == null;
  }

  void setOrderDetailsStatus(OrderModel targetOrder, OrderDetailsStatus status) {
    targetOrder = dataList.firstWhere((element) => element.id == targetOrder.id, orElse: () => targetOrder);
    if (GlobalVar.checkListNotEmpty(targetOrder.orderDetails)) {
      for (var i = 0; i < targetOrder.orderDetails!.length; i++) {
        targetOrder.orderDetails![i].orderDetailStatus = status;
      }
    }
  }
}
